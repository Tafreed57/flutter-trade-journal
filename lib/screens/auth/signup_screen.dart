import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';

/// Premium signup screen with animations
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          const _AnimatedBackground(),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface.withOpacity(0.5),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left panel - Branding
        Expanded(flex: 5, child: _buildBrandingPanel()),

        // Right panel - Form
        Expanded(
          flex: 4,
          child: Container(
            color: AppColors.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          _buildHeader(),
          const SizedBox(height: 40),
          _buildForm(),
        ],
      ),
    );
  }

  Widget _buildBrandingPanel() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            _buildLogo(size: 100),
            const SizedBox(height: 40),

            // Tagline
            Text(
              'Start Your\nTrading Journey',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Join thousands of traders who use\nour platform to improve their skills.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Benefits
            ..._buildBenefitsList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBenefitsList() {
    final benefits = [
      ('✓', 'Free forever for personal use'),
      ('✓', 'Unlimited trade entries'),
      ('✓', 'Advanced analytics'),
      ('✓', 'Paper trading simulator'),
    ];

    return benefits
        .map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.profit.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      b.$1,
                      style: TextStyle(
                        color: AppColors.profit,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  b.$2,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            _buildLogo(size: 72),
            const SizedBox(height: 24),
            Text(
              'Create Account',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your trading journey today',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo({required double size}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(size * 0.25),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          Icons.show_chart_rounded,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title (desktop only)
                  if (Responsive.isDesktop(context)) ...[
                    Text(
                      'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in your details to get started',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Email field
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'your@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Min. 6 characters',
                    icon: Icons.lock_outlined,
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm password field
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    icon: Icons.lock_outlined,
                    obscureText: _obscureConfirmPassword,
                    validator: _validateConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Password strength indicator
                  _buildPasswordStrength(),
                  const SizedBox(height: 24),

                  // Error message
                  if (auth.error != null) _buildErrorMessage(auth.error!),

                  // Sign up button
                  _buildPrimaryButton(
                    label: 'Create Account',
                    isLoading: auth.isLoading,
                    onPressed: _handleSignUp,
                  ),
                  const SizedBox(height: 24),

                  // Terms
                  Text(
                    'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Sign in link
                  _buildSignInLink(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;

    if (password.length >= 6) strength++;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    final colors = [
      AppColors.loss,
      AppColors.warning,
      AppColors.warning,
      AppColors.profit,
      AppColors.profit,
    ];

    final labels = ['Weak', 'Fair', 'Good', 'Strong', 'Very Strong'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: index < strength
                      ? colors[strength - 1]
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (password.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Password strength: ${strength > 0 ? labels[strength - 1] : "Too short"}',
            style: TextStyle(
              color: strength > 0
                  ? colors[strength - 1]
                  : AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.loss.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.loss.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.loss, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: AppColors.loss, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: AppColors.loss),
            onPressed: () => context.read<AuthProvider>().clearError(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Sign In',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<AuthProvider>().signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    // If signup was successful, pop back to auth gate which will show main app
    if (success && mounted) {
      // Pop all the way back to the auth gate - it will automatically show MainShell
      // because the auth state is now authenticated
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

/// Animated gradient background
class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GradientPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GradientPainter extends CustomPainter {
  final double animationValue;

  _GradientPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    paint.color = AppColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final center1 = Offset(
      size.width * (0.7 + 0.1 * math.sin(animationValue * 2 * math.pi)),
      size.height * (0.3 + 0.1 * math.cos(animationValue * 2 * math.pi)),
    );

    final center2 = Offset(
      size.width * (0.3 + 0.1 * math.cos(animationValue * 2 * math.pi)),
      size.height * (0.7 + 0.1 * math.sin(animationValue * 2 * math.pi)),
    );

    paint.shader = RadialGradient(
      colors: [
        AppColors.accent.withOpacity(0.12),
        AppColors.accent.withOpacity(0),
      ],
    ).createShader(Rect.fromCircle(center: center1, radius: size.width * 0.4));
    canvas.drawCircle(center1, size.width * 0.4, paint);

    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF00A5FF).withOpacity(0.08),
        const Color(0xFF00A5FF).withOpacity(0),
      ],
    ).createShader(Rect.fromCircle(center: center2, radius: size.width * 0.35));
    canvas.drawCircle(center2, size.width * 0.35, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
