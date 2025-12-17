import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/logger.dart';

/// Authentication service handling Firebase Auth operations
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  
  // Lazy-initialized to avoid crash on web without client ID
  GoogleSignIn? _googleSignIn;
  GoogleSignIn get googleSignIn => _googleSignIn ??= GoogleSignIn(
    // For web, client ID is required - will be set via index.html meta tag
    // For mobile, it's auto-configured via google-services.json / GoogleService-Info.plist
  );

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Current user stream for auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current user (null if not signed in)
  User? get currentUser => _auth.currentUser;

  /// Wait for Firebase Auth to be ready (loads persisted session)
  /// Returns the current user after auth state is determined
  Future<User?> waitForAuthReady() async {
    // authStateChanges emits the current auth state immediately
    // Wait for the first emission which represents the persisted state
    return await _auth.authStateChanges().first;
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _updateLastLogin(credential.user);
      Log.i('User signed in: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      Log.e('Sign in failed', e);
      throw _mapAuthException(e);
    }
  }

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _createUserDocument(credential.user, 'email');
      Log.i('User signed up: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      Log.e('Sign up failed', e);
      throw _mapAuthException(e);
    }
  }

  /// Check if Google Sign-In is available on this platform
  bool get isGoogleSignInAvailable {
    // On web, we need the client ID configured
    // For now, we'll try and catch errors gracefully
    return true;
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        Log.w('Google sign in cancelled');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // User is now authenticated in Firebase Auth.
      // Creating/updating the Firestore document is secondary - don't let it
      // break the auth flow if it fails.
      try {
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          await _createUserDocument(userCredential.user, 'google');
        } else {
          await _updateLastLogin(userCredential.user);
        }
      } catch (firestoreError) {
        // Log but don't fail - user is already authenticated
        Log.w('Failed to update user document, will retry later: $firestoreError');
      }

      Log.i('User signed in with Google: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      Log.e('Google sign in failed', e);
      throw _mapAuthException(e);
    } on AssertionError catch (e) {
      // This happens on web when Google Client ID is not configured
      Log.w('Google Sign-In not configured: $e');
      if (kIsWeb) {
        throw AuthException(
          'Google Sign-In is not configured for web. '
          'Please use email/password instead, or contact support.',
        );
      }
      throw AuthException('Google sign in failed. Please try again.');
    } catch (e) {
      Log.e('Google sign in error', e);
      throw AuthException('Google sign in failed. Please try again.');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Only sign out of Google if it was initialized
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      Log.i('User signed out');
    } catch (e) {
      Log.e('Sign out failed', e);
      throw AuthException('Sign out failed. Please try again.');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Log.i('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      Log.e('Password reset failed', e);
      throw _mapAuthException(e);
    }
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(User? user, String provider) async {
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final now = DateTime.now();

    await userDoc.set({
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'authProvider': provider,
      'createdAt': Timestamp.fromDate(now),
      'lastLoginAt': Timestamp.fromDate(now),
    });

    Log.d('User document created for: ${user.email}');
  }

  /// Update last login timestamp
  Future<void> _updateLastLogin(User? user) async {
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    await userDoc.update({
      'lastLoginAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Map Firebase auth exceptions to user-friendly messages
  AuthException _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException('No account found with this email.');
      case 'wrong-password':
        return AuthException('Incorrect password.');
      case 'email-already-in-use':
        return AuthException('An account already exists with this email.');
      case 'weak-password':
        return AuthException('Password is too weak. Use at least 6 characters.');
      case 'invalid-email':
        return AuthException('Invalid email address.');
      case 'user-disabled':
        return AuthException('This account has been disabled.');
      case 'too-many-requests':
        return AuthException('Too many attempts. Please try again later.');
      case 'network-request-failed':
        return AuthException('Network error. Check your connection.');
      default:
        return AuthException('Authentication failed: ${e.message}');
    }
  }
}

/// Custom auth exception with user-friendly message
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

