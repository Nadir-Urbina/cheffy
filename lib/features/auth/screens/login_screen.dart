import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;

  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isLoginMode = true; // true = login, false = register

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = _isLoginMode
        ? await widget.authService.signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          )
        : await widget.authService.createAccountWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
            _nameController.text.trim(),
          );

    setState(() => _isLoading = false);

    if (!result.success && mounted) {
      _showError(result.errorMessage ?? 'An error occurred');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final result = await widget.authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (!result.success && mounted) {
      _showError(result.errorMessage ?? 'Failed to sign in with Google');
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    final result = await widget.authService.signInWithApple();
    setState(() => _isLoading = false);

    if (!result.success && mounted) {
      _showError(result.errorMessage ?? 'Failed to sign in with Apple');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppColors.freshGradientDecoration,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo Section
                  _buildLogo(),
                  const SizedBox(height: 32),
                  // Welcome Text
                  _buildWelcomeText(),
                  const SizedBox(height: 32),
                  // Social Sign In Buttons
                  _buildSocialButtons(),
                  const SizedBox(height: 24),
                  // Name Field (only for registration)
                  if (!_isLoginMode) ...[
                    _buildNameField(),
                    const SizedBox(height: 12),
                  ],
                  // Email & Password Fields
                  _buildEmailField(),
                  const SizedBox(height: 12),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  // Trust message
                  _buildTrustMessage(),
                  const SizedBox(height: 24),
                  // Toggle Login/Register
                  _buildToggleAuthMode(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/cheffy brand image.png',
      width: 220,
      fit: BoxFit.contain,
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome to Cheffy',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cook with confidence, starting with\nwhat you have.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        // Apple Sign In
        _SocialButton(
          onPressed: _isLoading ? null : _handleAppleSignIn,
          icon: const Icon(Icons.apple, color: Colors.white, size: 24),
          label: 'Continue with Apple',
          backgroundColor: AppColors.buttonApple,
          textColor: Colors.white,
        ),
        const SizedBox(height: 12),
        // Google Sign In
        _SocialButton(
          onPressed: _isLoading ? null : _handleGoogleSignIn,
          icon: Image.network(
            'https://www.google.com/favicon.ico',
            width: 20,
            height: 20,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.g_mobiledata,
              color: Colors.red,
              size: 24,
            ),
          ),
          label: 'Continue with Google',
          backgroundColor: AppColors.buttonGoogle,
          textColor: AppColors.textPrimary,
          borderColor: AppColors.border,
        ),
        const SizedBox(height: 12),
        // Email Sign In
        _SocialButton(
          onPressed: _isLoading ? null : _handleEmailAuth,
          icon: const Icon(Icons.mail_outline, color: Colors.white, size: 22),
          label: _isLoginMode ? 'Continue with Email' : 'Create Account',
          backgroundColor: AppColors.buttonEmail,
          textColor: Colors.white,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        hintText: 'Full name',
      ),
      validator: (value) {
        if (!_isLoginMode && (value == null || value.trim().isEmpty)) {
          return 'Please enter your name';
        }
        if (!_isLoginMode && value!.trim().length < 2) {
          return 'Name must be at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        hintText: 'Your email',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleEmailAuth(),
      decoration: InputDecoration(
        hintText: 'Password',
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.lock_open : Icons.lock_outline,
            color: AppColors.iconPrimary,
            size: 22,
          ),
          onPressed: () {
            setState(() => _isPasswordVisible = !_isPasswordVisible);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (!_isLoginMode && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildTrustMessage() {
    return Text(
      'No spam. No judgment. Cancel anytime.',
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildToggleAuthMode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLoginMode ? 'New here? ' : 'Already have an account? ',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() => _isLoginMode = !_isLoginMode);
          },
          child: Text(
            _isLoginMode ? 'Create one' : 'Sign in',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable social sign-in button
class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final bool isLoading;

  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: borderColor != null
                ? BorderSide(color: borderColor!)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
