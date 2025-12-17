import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/logger.dart';
import '../main.dart' show isFirebaseAvailable;
import '../services/auth_service.dart';

/// Auth state enum
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Provider managing authentication state
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  
  AuthState _state = AuthState.initial;
  User? _user;
  String? _error;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _init();
  }

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  /// Initialize auth state listener
  void _init() {
    Log.d('AuthProvider initializing...');
    
    // If Firebase isn't available, mark as unauthenticated
    if (!isFirebaseAvailable) {
      Log.w('Firebase not available, auth disabled');
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    // Wait for Firebase to load persisted session, then listen to changes
    _initAsync();
  }

  /// Async initialization - waits for Firebase to be ready
  Future<void> _initAsync() async {
    try {
      // Wait for Firebase Auth to determine the initial auth state
      // This properly loads the persisted session from IndexedDB/secure storage
      final initialUser = await _authService.waitForAuthReady();
      
      _user = initialUser;
      _state = initialUser != null ? AuthState.authenticated : AuthState.unauthenticated;
      
      if (initialUser != null) {
        Log.i('Session restored for: ${initialUser.email}');
      } else {
        Log.i('No persisted session found');
      }
      notifyListeners();

      // Now listen for future auth state changes (sign in, sign out)
      _authSubscription = _authService.authStateChanges.listen(
        (user) {
          // Skip if same state (initial state already handled)
          if (user?.uid == _user?.uid) return;
          
          _user = user;
          _state = user != null ? AuthState.authenticated : AuthState.unauthenticated;
          _error = null;
          Log.i('Auth state changed: ${_state.name}');
          notifyListeners();
        },
        onError: (error) {
          Log.e('Auth stream error', error);
          _state = AuthState.error;
          _error = 'Authentication error occurred';
          notifyListeners();
        },
      );
    } catch (e) {
      Log.e('Auth init error', e);
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _runAuthOperation(() async {
      await _authService.signInWithEmail(email: email, password: password);
    });
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return _runAuthOperation(() async {
      await _authService.signUpWithEmail(email: email, password: password);
    });
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    return _runAuthOperation(() async {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        throw AuthException('Google sign in was cancelled');
      }
    });
  }

  /// Sign out
  Future<bool> signOut() async {
    return _runAuthOperation(() async {
      await _authService.signOut();
    });
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    return _runAuthOperation(() async {
      await _authService.sendPasswordResetEmail(email);
    });
  }

  /// Run an auth operation with loading state management
  Future<bool> _runAuthOperation(Future<void> Function() operation) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      await operation();
      
      // After a successful auth operation, sync state with Firebase's current user.
      // This handles race conditions where the authStateChanges listener might not
      // have fired yet, or might have been skipped due to UID matching.
      final currentUser = _authService.currentUser;
      if (currentUser != null && _state != AuthState.authenticated) {
        _user = currentUser;
        _state = AuthState.authenticated;
        Log.i('Auth operation successful, user: ${currentUser.email}');
        notifyListeners();
      } else if (currentUser == null && _state != AuthState.unauthenticated) {
        // Sign out completed
        _user = null;
        _state = AuthState.unauthenticated;
        notifyListeners();
      }
      
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      Log.e('Auth operation failed', e);
      _error = 'An unexpected error occurred';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    if (_state == AuthState.error) {
      _state = _user != null ? AuthState.authenticated : AuthState.unauthenticated;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

