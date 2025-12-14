import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show isFirebaseAvailable;
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';
import 'login_screen.dart';

/// Auth gate that routes users based on authentication state
/// 
/// - Firebase not available → Skip auth, go to main app
/// - Unauthenticated → Login screen
/// - Authenticated → Main app
/// - Loading → Splash screen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // If Firebase isn't configured, skip auth entirely
    if (!isFirebaseAvailable) {
      return const MainShell();
    }
    
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.state) {
          case AuthState.initial:
          case AuthState.loading:
            return _buildSplashScreen();
          
          case AuthState.authenticated:
            return const MainShell();
          
          case AuthState.unauthenticated:
          case AuthState.error:
            return const LoginScreen();
        }
      },
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.show_chart_rounded,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

