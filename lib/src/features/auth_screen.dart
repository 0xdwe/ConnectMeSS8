import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

import '../state/app_state.dart';
import '../state/firebase_providers.dart';
import '../state/user_profile/user_profile_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/chain_logo.dart';

enum AuthMode { landing, login, signup }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.landing});

  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _mode;
  bool _busy = false;

  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  String? _loginEmailError;
  String? _loginPasswordError;

  final _signupName = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPassword = TextEditingController();
  final _signupConfirm = TextEditingController();
  String? _signupNameError;
  String? _signupEmailError;
  String? _signupPasswordError;
  String? _signupConfirmError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPassword.dispose();
    _signupName.dispose();
    _signupEmail.dispose();
    _signupPassword.dispose();
    _signupConfirm.dispose();
    super.dispose();
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submitLogin() async {
    final emailError = _validateEmail(_loginEmail.text.trim());
    final passwordError = _validatePassword(_loginPassword.text);
    setState(() {
      _loginEmailError = emailError;
      _loginPasswordError = passwordError;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(
            email: _loginEmail.text.trim(),
            password: _loginPassword.text,
          );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.code) {
          case 'user-not-found':
          case 'invalid-email':
          case 'invalid-credential':
            _loginEmailError = _firebaseAuthMessage(e);
            break;
          case 'wrong-password':
            _loginPasswordError = _firebaseAuthMessage(e);
            break;
          default:
            _loginEmailError = _firebaseAuthMessage(e);
        }
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.read(appControllerProvider.notifier).signIn();
    if (mounted) context.go('/app');
  }

  Future<void> _submitSignup() async {
    final name = _signupName.text.trim();
    final email = _signupEmail.text.trim();
    final password = _signupPassword.text;
    final confirm = _signupConfirm.text;
    final nameError = name.isEmpty ? 'Full name is required' : null;
    final emailError = _validateEmail(email);
    final passwordError = _validatePassword(password);
    String? confirmError;
    if (confirm.isEmpty) {
      confirmError = 'Confirm your password';
    } else if (passwordError == null && confirm != password) {
      confirmError = 'Passwords do not match';
    }
    setState(() {
      _signupNameError = nameError;
      _signupEmailError = emailError;
      _signupPasswordError = passwordError;
      _signupConfirmError = confirmError;
    });
    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmError != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(firebaseAuthProvider)
          .createUserWithEmailAndPassword(email: email, password: password);
      await ref.read(userProfileServiceProvider).updateDisplayName(name);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.code) {
          case 'email-already-in-use':
          case 'invalid-email':
            _signupEmailError = _firebaseAuthMessage(e);
            break;
          case 'weak-password':
            _signupPasswordError = _firebaseAuthMessage(e);
            break;
          default:
            _signupEmailError = _firebaseAuthMessage(e);
        }
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _signupEmailError = 'Something went sideways — try again.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (mounted) context.go('/app');
    ref.read(appControllerProvider.notifier).signUp(name: name, email: email);
  }

  String _firebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return "We don't see an account with that email yet.";
      case 'wrong-password':
      case 'invalid-credential':
        return "That password doesn't match — give it another try.";
      case 'invalid-email':
        return 'That email address looks off — check the spelling.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Try a stronger password — at least 6 characters helps.';
      case 'network-request-failed':
        return 'Network hiccup — try again in a moment.';
      case 'too-many-requests':
        return 'A lot of attempts in a short window — take a breath and retry.';
      default:
        return e.message ?? 'Something went sideways — try again.';
    }
  }

  Future<void> _switchMode(AuthMode next) async {
    if (_mode == next) return;

    void clearErrors() {
      _loginEmailError = null;
      _loginPasswordError = null;
      _signupNameError = null;
      _signupEmailError = null;
      _signupPasswordError = null;
      _signupConfirmError = null;
    }

    setState(() {
      _mode = next;
      clearErrors();
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      final service = ref.read(googleSignInServiceProvider);
      final credential = await service.signIn();
      if (credential != null) {
        ref.read(appControllerProvider.notifier).signIn();
        if (mounted) context.go('/app');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loginEmailError = _firebaseAuthMessage(e);
      });
    } catch (e, stack) {
      debugPrint('Google Sign-In failed: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _loginEmailError = 'Google sign-in went sideways: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.light();

    return Theme(
      data: AppTheme.data(false),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            return Stack(
              children: [
                // 1. Mode-specific background
                if (_mode == AuthMode.landing) ...[
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE6DBFB), Color(0xFFFAF7FC)],
                            begin: Alignment.topLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 24,
                    right: 0,
                    bottom: -24,
                    left: 0,
                    child: IgnorePointer(
                      child: Image(
                        key: Key('welcome-screen-background'),
                        image: AssetImage('assets/images/welcome_back.jpg'),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ] else ...[
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(color: Colors.white),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Image(
                        key: Key('login-page-background'),
                        image: AssetImage('assets/images/login_page.jpg'),
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ],

                // 2. Main content layer
                if (_mode == AuthMode.landing)
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, landingConstraints) {
                        return SingleChildScrollView(
                          key: const Key('landing-scroll-view'),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: landingConstraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: _buildLanding(context, tokens),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else ...[
                  // Curved card inputs (Scrollable to prevent keyboard overflows)
                  SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          w <= 360 ? AppSpacing.space4 : AppSpacing.space5,
                          _mode == AuthMode.login
                              ? math.max(h * 0.255, 176.0)
                              : h * 0.28,
                          w <= 360 ? AppSpacing.space4 : AppSpacing.space5,
                          AppSpacing.space5,
                        ),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Form content
                                if (_mode == AuthMode.login)
                                  _LoginForm(
                                    emailController: _loginEmail,
                                    passwordController: _loginPassword,
                                    emailError: _loginEmailError,
                                    passwordError: _loginPasswordError,
                                    busy: _busy,
                                    onSubmit: _submitLogin,
                                    onSwitch: () =>
                                        _switchMode(AuthMode.signup),
                                    onGoogleSignIn: _signInWithGoogle,
                                    tokens: tokens,
                                  )
                                else
                                  _SignupForm(
                                    nameController: _signupName,
                                    emailController: _signupEmail,
                                    passwordController: _signupPassword,
                                    confirmController: _signupConfirm,
                                    nameError: _signupNameError,
                                    emailError: _signupEmailError,
                                    passwordError: _signupPasswordError,
                                    confirmError: _signupConfirmError,
                                    busy: _busy,
                                    onSubmit: _submitSignup,
                                    onSwitch: () => _switchMode(AuthMode.login),
                                    onGoogleSignIn: _signInWithGoogle,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Back Button to Landing Screen (placed on top for hit-testing)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: SafeArea(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: tokens.ink),
                          onPressed: () => _switchMode(AuthMode.landing),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanding(BuildContext context, AppTokens tokens) {
    final height = MediaQuery.sizeOf(context).height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: height * 0.08),
        // App logo & title
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinkedChainLogo(size: 60, color: tokens.primary),
              const SizedBox(height: 8),
              Text(
                'Connect Me',
                style: AppTypography.bodyLg(
                  color: tokens.ink,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 19),
              ),
            ],
          ),
        ),
        SizedBox(height: height * 0.06),
        // Welcome headline and subtext
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome to\nConnect Me',
                textAlign: TextAlign.center,
                style: AppTypography.glyph(
                  36,
                  color: tokens.ink,
                  weight: FontWeight.w700,
                ).copyWith(height: 1.15),
              ),
              const SizedBox(height: 12),
              Text(
                'Nurture the relationships\nthat matter most.',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  color: tokens.inkMuted,
                ).copyWith(height: 1.3, fontSize: 14.5),
              ),
            ],
          ),
        ),
        SizedBox(height: height * 0.065),
        // Actions
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sign Up
                _GradientButton(
                  height: 58,
                  gradient: tokens.aiGradient,
                  onPressed: () => _switchMode(AuthMode.signup),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Sign Up',
                          style: AppTypography.bodyLg(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.arrow_forward, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Log In
                SizedBox(
                  height: 58,
                  child: OutlinedButton(
                    onPressed: () => _switchMode(AuthMode.login),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: tokens.primary,
                      side: BorderSide(
                        color: tokens.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Log In',
                            style: AppTypography.bodyLg(
                              color: tokens.primary,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: tokens.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.gradient,
    required this.onPressed,
    required this.child,
    this.buttonKey,
    this.height = 56,
  });

  final LinearGradient gradient;
  final VoidCallback? onPressed;
  final Widget child;
  final Key? buttonKey;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

InputDecorationTheme _authInputDecoration(
  BuildContext context, {
  AppTokens? tokensOverride,
  Color? fillColor,
  double borderRadius = 30,
  double? minHeight,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 15,
  ),
}) {
  final tokens = tokensOverride ?? context.tokens;
  final radius = BorderRadius.circular(borderRadius);
  return InputDecorationTheme(
    filled: true,
    fillColor: fillColor ?? const Color(0xFFF3F2FF).withValues(alpha: 0.6),
    labelStyle: AppTypography.body(color: tokens.inkMuted),
    hintStyle: AppTypography.body(color: tokens.inkSubtle),
    errorStyle: AppTypography.caption(color: tokens.danger),
    contentPadding: contentPadding,
    constraints: minHeight == null
        ? null
        : BoxConstraints(minHeight: minHeight),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: tokens.primary, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: tokens.danger, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: tokens.danger, width: 1.4),
    ),
  );
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.emailController,
    required this.passwordController,
    required this.emailError,
    required this.passwordError,
    required this.busy,
    required this.onSubmit,
    required this.onSwitch,
    required this.onGoogleSignIn,
    required this.tokens,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? emailError;
  final String? passwordError;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onSwitch;
  final VoidCallback onGoogleSignIn;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinkedChainLogo(size: 47, color: tokens.primary),
              const SizedBox(height: 6),
              Text(
                'Connect Me',
                style: AppTypography.bodyLg(
                  color: tokens.ink,
                ).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Text(
          'Welcome back.',
          style: AppTypography.display(
            color: tokens.ink,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 32),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Log in to keep your connections close.',
          style: AppTypography.body(color: tokens.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 34),

        // Email field
        TextField(
          key: const Key('login-email-field'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: AppTypography.body(color: tokens.ink),
          decoration:
              InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 18, right: 10),
                  child: Icon(
                    Icons.email_outlined,
                    color: tokens.inkMuted,
                    size: 18,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 0,
                ),
                labelText: 'Email',
                errorText: emailError,
              ).applyDefaults(
                _authInputDecoration(
                  context,
                  tokensOverride: tokens,
                  fillColor: const Color(0xFFF3F2FF),
                  borderRadius: 18,
                  minHeight: 56,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
        ),
        const SizedBox(height: 16),

        // Password field
        TextField(
          key: const Key('login-password-field'),
          controller: passwordController,
          obscureText: true,
          style: AppTypography.body(color: tokens.ink),
          decoration:
              InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 18, right: 10),
                  child: Icon(
                    Icons.lock_outline,
                    color: tokens.inkMuted,
                    size: 18,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 0,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Icon(
                    Icons.visibility_outlined,
                    color: tokens.inkSubtle,
                    size: 18,
                  ),
                ),
                labelText: 'Password',
                errorText: passwordError,
              ).applyDefaults(
                _authInputDecoration(
                  context,
                  tokensOverride: tokens,
                  fillColor: const Color(0xFFF3F2FF),
                  borderRadius: 18,
                  minHeight: 56,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
        ),
        const SizedBox(height: 24),

        // Login button
        _GradientButton(
          buttonKey: const Key('sign-in-button'),
          gradient: tokens.aiGradient,
          onPressed: busy ? null : onSubmit,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else ...[
                const Icon(Icons.arrow_forward, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Log in',
                  style: AppTypography.bodyLg().copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.space3),
              child: Text(
                'or',
                style: AppTypography.caption(color: Colors.grey.shade500),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 20),

        // Google button
        SizedBox(
          height: 56,
          child: OutlinedButton(
            key: const Key('google-sign-in-button'),
            onPressed: busy ? null : onGoogleSignIn,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: tokens.ink,
              side: BorderSide(color: tokens.border, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  )
                else ...[
                  const _GoogleIcon(),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Continue with Google',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: AppTypography.body().copyWith(
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Switch to Signup
        TextButton(
          key: const Key('auth-mode-signup'),
          onPressed: busy ? null : onSwitch,
          style: TextButton.styleFrom(foregroundColor: tokens.primary),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(
                    color: tokens.inkMuted,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const TextSpan(
                  text: "Sign up",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _SignupForm extends StatelessWidget {
  const _SignupForm({
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.nameError,
    required this.emailError,
    required this.passwordError,
    required this.confirmError,
    required this.busy,
    required this.onSubmit,
    required this.onSwitch,
    required this.onGoogleSignIn,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String? nameError;
  final String? emailError;
  final String? passwordError;
  final String? confirmError;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onSwitch;
  final VoidCallback onGoogleSignIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Join Connect Me.',
          style: AppTypography.display(
            color: tokens.ink,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Create an account to keep connections close.',
          style: AppTypography.body(color: tokens.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Name
        TextField(
          key: const Key('signup-name-field'),
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 10),
              child: Icon(
                Icons.person_outline,
                color: tokens.inkMuted,
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 0,
            ),
            labelText: 'Full name',
            errorText: nameError,
          ).applyDefaults(_authInputDecoration(context)),
        ),
        const SizedBox(height: 16),

        // Email
        TextField(
          key: const Key('signup-email-field'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 10),
              child: Icon(
                Icons.email_outlined,
                color: tokens.inkMuted,
                size: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 0,
            ),
            labelText: 'Email',
            errorText: emailError,
          ).applyDefaults(_authInputDecoration(context)),
        ),
        const SizedBox(height: 16),

        // Password
        TextField(
          key: const Key('signup-password-field'),
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 10),
              child: Icon(Icons.lock_outline, color: tokens.inkMuted, size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 0,
            ),
            labelText: 'Password',
            errorText: passwordError,
          ).applyDefaults(_authInputDecoration(context)),
        ),
        const SizedBox(height: 16),

        // Confirm Password
        TextField(
          key: const Key('signup-confirm-field'),
          controller: confirmController,
          obscureText: true,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 10),
              child: Icon(Icons.lock_outline, color: tokens.inkMuted, size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 0,
            ),
            labelText: 'Confirm password',
            errorText: confirmError,
          ).applyDefaults(_authInputDecoration(context)),
        ),
        const SizedBox(height: 24),

        // Signup Button
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('sign-up-button'),
            onPressed: busy ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: tokens.primary,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  const Icon(Icons.check, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Create account',
                    style: AppTypography.bodyLg().copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.space3),
              child: Text(
                'or',
                style: AppTypography.caption(color: Colors.grey.shade500),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 20),

        // Google sign in
        SizedBox(
          height: 52,
          child: OutlinedButton(
            key: const Key('google-sign-in-button'),
            onPressed: busy ? null : onGoogleSignIn,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: tokens.ink,
              side: BorderSide(color: Colors.grey.shade300, width: 1.2),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  )
                else ...[
                  const _GoogleIcon(),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: AppTypography.body().copyWith(
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Switch to Login
        TextButton(
          key: const Key('auth-mode-login'),
          onPressed: busy ? null : onSwitch,
          style: TextButton.styleFrom(foregroundColor: tokens.primary),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(
                    color: tokens.inkMuted,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const TextSpan(
                  text: 'Log in',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  static const String _svgString = '''
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xml:space="preserve" overflow="hidden" viewBox="0 0 268.152 273.883"><defs><linearGradient id="google-a"><stop offset="0" stop-color="#0fbc5c"/><stop offset="1" stop-color="#0cba65"/></linearGradient><linearGradient id="google-g"><stop offset=".231" stop-color="#0fbc5f"/><stop offset=".312" stop-color="#0fbc5f"/><stop offset=".366" stop-color="#0fbc5e"/><stop offset=".458" stop-color="#0fbc5d"/><stop offset=".54" stop-color="#12bc58"/><stop offset=".699" stop-color="#28bf3c"/><stop offset=".771" stop-color="#38c02b"/><stop offset=".861" stop-color="#52c218"/><stop offset=".915" stop-color="#67c30f"/><stop offset="1" stop-color="#86c504"/></linearGradient><linearGradient id="google-h"><stop offset=".142" stop-color="#1abd4d"/><stop offset=".248" stop-color="#6ec30d"/><stop offset=".312" stop-color="#8ac502"/><stop offset=".366" stop-color="#a2c600"/><stop offset=".446" stop-color="#c8c903"/><stop offset=".54" stop-color="#ebcb03"/><stop offset=".616" stop-color="#f7cd07"/><stop offset=".699" stop-color="#fdcd04"/><stop offset=".771" stop-color="#fdce05"/><stop offset=".861" stop-color="#ffce0a"/></linearGradient><linearGradient id="google-f"><stop offset=".316" stop-color="#ff4c3c"/><stop offset=".604" stop-color="#ff692c"/><stop offset=".727" stop-color="#ff7825"/><stop offset=".885" stop-color="#ff8d1b"/><stop offset="1" stop-color="#ff9f13"/></linearGradient><linearGradient id="google-b"><stop offset=".231" stop-color="#ff4541"/><stop offset=".312" stop-color="#ff4540"/><stop offset=".458" stop-color="#ff4640"/><stop offset=".54" stop-color="#ff473f"/><stop offset=".699" stop-color="#ff5138"/><stop offset=".771" stop-color="#ff5b33"/><stop offset=".861" stop-color="#ff6c29"/><stop offset="1" stop-color="#ff8c18"/></linearGradient><linearGradient id="google-d"><stop offset=".408" stop-color="#fb4e5a"/><stop offset="1" stop-color="#ff4540"/></linearGradient><linearGradient id="google-c"><stop offset=".132" stop-color="#0cba65"/><stop offset=".21" stop-color="#0bb86d"/><stop offset=".297" stop-color="#09b479"/><stop offset=".396" stop-color="#08ad93"/><stop offset=".477" stop-color="#0aa6a9"/><stop offset=".568" stop-color="#0d9cc6"/><stop offset=".667" stop-color="#1893dd"/><stop offset=".769" stop-color="#258bf1"/><stop offset=".859" stop-color="#3086ff"/></linearGradient><linearGradient id="google-e"><stop offset=".366" stop-color="#ff4e3a"/><stop offset=".458" stop-color="#ff8a1b"/><stop offset=".54" stop-color="#ffa312"/><stop offset=".616" stop-color="#ffb60c"/><stop offset=".771" stop-color="#ffcd0a"/><stop offset=".861" stop-color="#fecf0a"/><stop offset=".915" stop-color="#fecf08"/><stop offset="1" stop-color="#fdcd01"/></linearGradient><linearGradient xlink:href="#google-a" id="google-s" x1="219.7" x2="254.467" y1="329.535" y2="329.535" gradientUnits="userSpaceOnUse"/><radialGradient xlink:href="#google-b" id="google-m" cx="109.627" cy="135.862" r="71.46" fx="109.627" fy="135.862" gradientTransform="matrix(-1.93688 1.043 1.45573 2.55542 290.525 -400.634)" gradientUnits="userSpaceOnUse"/><radialGradient xlink:href="#google-c" id="google-n" cx="45.259" cy="279.274" r="71.46" fx="45.259" fy="279.274" gradientTransform="matrix(-3.5126 -4.45809 -1.69255 1.26062 870.8 191.554)" gradientUnits="userSpaceOnUse"/><radialGradient xlink:href="#google-d" id="google-l" cx="304.017" cy="118.009" r="47.854" fx="304.017" fy="118.009" gradientTransform="matrix(2.06435 0 0 2.59204 -297.679 -151.747)" gradientUnits="userSpaceOnUse"/><radialGradient xlink:href="#google-e" id="google-o" cx="181.001" cy="177.201" r="71.46" fx="181.001" fy="177.201" gradientTransform="matrix(-.24858 2.08314 2.96249 .33417 -255.146 -331.164)" gradientUnits="userSpaceOnUse"/><radialGradient xlink:href="#google-f" id="google-p" cx="207.673" cy="108.097" r="41.102" fx="207.673" fy="108.097" gradientTransform="matrix(-1.2492 1.34326 -3.89684 -3.4257 880.501 194.905)" gradientUnits="userSpaceOnUse"/><radialGradient xlink:href="#google-g" id="google-r" cx="109.627" cy="135.862" r="71.46" fx="109.627" fy="135.862" gradientTransform="matrix(-1.93688 -1.043 1.45573 -2.55542 290.525 838.683)" gradientUnits="userSpaceOnUse"/><radialGradient xlink:href="#google-h" id="google-j" cx="154.87" cy="145.969" r="71.46" fx="154.87" fy="145.969" gradientTransform="matrix(-.0814 -1.93722 2.92674 -.11625 -215.135 632.86)" gradientUnits="userSpaceOnUse"/><clipPath id="google-i" clipPathUnits="userSpaceOnUse"><path d="M371.378 193.24H237.083v53.438h77.167c-1.241 7.563-4.026 15.003-8.105 21.786-4.674 7.773-10.451 13.69-16.373 18.196-17.74 13.498-38.42 16.258-52.783 16.258-36.283 0-67.283-23.286-79.285-54.928-.484-1.149-.805-2.335-1.197-3.507a81.115 81.115 0 0 1-4.101-25.448c0-9.226 1.569-18.057 4.43-26.398 11.285-32.897 42.985-57.467 80.179-57.467 7.481 0 14.685.884 21.517 2.648a77.668 77.668 0 0 1 33.425 18.25l40.834-39.712c-24.839-22.616-57.219-36.32-95.844-36.32-30.878 0-59.386 9.553-82.748 25.7-18.945 13.093-34.483 30.625-44.97 50.985-9.753 18.879-15.094 39.8-15.094 62.294 0 22.495 5.35 43.633 15.103 62.337v.126c10.302 19.857 25.368 36.954 43.678 49.988 15.997 11.386 44.68 26.551 84.031 26.551 22.63 0 42.687-4.051 60.375-11.644 12.76-5.478 24.065-12.622 34.301-21.804 13.525-12.132 24.117-27.139 31.347-44.404 7.23-17.265 11.097-36.79 11.097-57.957 0-9.858-.998-19.87-2.689-28.968Z"/></clipPath></defs><g clip-path="url(#google-i)" transform="matrix(.95792 0 0 .98525 -90.174 -78.856)"><path fill="url(#google-j)" d="M92.076 219.958c.148 22.14 6.501 44.983 16.117 63.424v.127c6.949 13.392 16.445 23.97 27.26 34.452l65.327-23.67c-12.36-6.235-14.246-10.055-23.105-17.026-9.054-9.066-15.802-19.473-20.004-31.677h-.17l.17-.127c-2.765-8.058-3.037-16.613-3.14-25.503Z"/><path fill="url(#google-l)" d="M237.083 79.025c-6.456 22.526-3.988 44.421 0 57.161 7.457.006 14.64.888 21.45 2.647a77.662 77.662 0 0 1 33.424 18.25l41.88-40.726c-24.81-22.59-54.667-37.297-96.754-37.332Z"/><path fill="url(#google-m)" d="M236.943 78.847c-31.67 0-60.91 9.798-84.871 26.359a145.533 145.533 0 0 0-24.332 21.15c-1.904 17.744 14.257 39.551 46.262 39.37 15.528-17.936 38.495-29.542 64.056-29.542l.07.002-1.044-57.335c-.048 0-.093-.004-.14-.004Z"/><path fill="url(#google-n)" d="m341.475 226.379-28.268 19.285c-1.24 7.562-4.028 15.002-8.107 21.786-4.674 7.772-10.45 13.69-16.373 18.196-17.702 13.47-38.328 16.244-52.687 16.255-14.842 25.102-17.444 37.675 1.043 57.934 22.877-.016 43.157-4.117 61.046-11.796 12.931-5.551 24.388-12.792 34.761-22.097 13.706-12.295 24.442-27.503 31.769-45 7.327-17.497 11.245-37.282 11.245-58.734Z"/><path fill="#3086ff" d="M234.996 191.21v57.498h136.006c1.196-7.874 5.152-18.064 5.152-26.5 0-9.858-.996-21.899-2.687-30.998Z"/><path fill="url(#google-o)" d="M128.39 124.327c-8.394 9.119-15.564 19.326-21.249 30.364-9.753 18.879-15.094 41.83-15.094 64.324 0 .317.026.627.029.944 4.32 8.224 59.666 6.649 62.456 0-.004-.31-.039-.613-.039-.924 0-9.226 1.57-16.026 4.43-24.367 3.53-10.289 9.056-19.763 16.123-27.926 1.602-2.031 5.875-6.397 7.121-9.016.475-.997-.862-1.557-.937-1.908-.083-.393-1.876-.077-2.277-.37-1.275-.929-3.8-1.414-5.334-1.845-3.277-.921-8.708-2.953-11.725-5.06-9.536-6.658-24.417-14.612-33.505-24.216Z"/><path fill="url(#google-p)" d="M162.099 155.857c22.112 13.301 28.471-6.714 43.173-12.977l-25.574-52.664a144.74 144.74 0 0 0-26.543 14.504c-12.316 8.512-23.192 18.9-32.176 30.72Z"/><path fill="url(#google-r)" d="M171.099 290.222c-29.683 10.641-34.33 11.023-37.062 29.29a144.806 144.806 0 0 0 16.792 13.984c15.996 11.386 46.766 26.551 86.118 26.551.046 0 .09-.004.137-.004v-59.157l-.094.002c-14.736 0-26.512-3.843-38.585-10.527-2.977-1.648-8.378 2.777-11.123.799-3.786-2.729-12.9 2.35-16.183-.938Z"/><path fill="url(#google-s)" d="M219.7 299.023v59.996c5.506.64 11.236 1.028 17.247 1.028 6.026 0 11.855-.307 17.52-.872v-59.748a105.119 105.119 0 0 1-17.477 1.461c-5.932 0-11.7-.686-17.29-1.865Z" opacity=".5"/></g></svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svgString, width: 20.0, height: 20.0);
  }
}
