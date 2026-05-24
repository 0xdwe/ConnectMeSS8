import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/firebase_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';

enum _AuthMode { login, signup }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthMode _mode = _AuthMode.login;
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
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
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
      final cred =
          await ref.read(firebaseAuthProvider).createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
      try {
        await cred.user?.updateDisplayName(name);
      } catch (_) {/* ignore */}
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
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.read(appControllerProvider.notifier).signUp(name: name, email: email);
    if (mounted) context.go('/app');
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

  void _switchMode(_AuthMode next) {
    if (_mode == next) return;
    setState(() {
      _mode = next;
      _loginEmailError = null;
      _loginPasswordError = null;
      _signupNameError = null;
      _signupEmailError = null;
      _signupPasswordError = null;
      _signupConfirmError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA0C4FF), // Soft blue
              Color(0xFFC4A0FF), // Soft purple
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.space5),
            child: Column(
              children: [
                // Spacer to push white card to center vertically
                Spacer(),
                
                // White rounded rectangle as base
                Container(
                  constraints: BoxConstraints(
                    maxWidth: 500, // Max width for better readability on larger screens
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl * 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.space5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App logo (smaller)
                        Container(
                          padding: EdgeInsets.all(AppSpacing.space3),
                          decoration: BoxDecoration(
                            color: Color(0xFFA0C4FF).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.hub_outlined,
                            color: Color(0xFF6B4EFF),
                            size: 48,
                          ),
                        ),
                        
                        SizedBox(height: AppSpacing.space4),
                        
                        // Mode selector (Login/Signup)
                        _ModeSelector(
                          mode: _mode,
                          onChanged: _switchMode,
                        ),
                        
                        SizedBox(height: AppSpacing.space5),
                        
                        // Content based on mode
                        if (_mode == _AuthMode.login)
                          _LoginForm(
                            emailController: _loginEmail,
                            passwordController: _loginPassword,
                            emailError: _loginEmailError,
                            passwordError: _loginPasswordError,
                            busy: _busy,
                            onSubmit: _submitLogin,
                            onSwitch: () => _switchMode(_AuthMode.signup),
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
                            onSwitch: () => _switchMode(_AuthMode.login),
                          ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: AppSpacing.space5),
                
                // Powered by text outside the white box
                Text(
                  'Powered by Firebase Auth.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                
                Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});
  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      padding: EdgeInsets.all(AppSpacing.space1),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              key: const Key('auth-mode-login'),
              label: 'Log in',
              selected: mode == _AuthMode.login,
              onTap: () => onChanged(_AuthMode.login),
            ),
          ),
          Expanded(
            child: _ModeChip(
              key: const Key('auth-mode-signup'),
              label: 'Sign up',
              selected: mode == _AuthMode.signup,
              onTap: () => onChanged(_AuthMode.signup),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: AppSpacing.space3),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: selected ? AppTokens.elevation1(dark) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.body(
            color: selected ? Color(0xFF6B4EFF) : Colors.grey.shade600,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
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
  });
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? emailError;
  final String? passwordError;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome back text
        Text(
          'Welcome back.',
          style: AppTypography.display(
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: AppSpacing.space2),
        
        // Subtitle text
        Text(
          'Log in to keep your connections close.',
          style: AppTypography.body(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: AppSpacing.space5),
        
        // Email field
        TextField(
          key: const Key('login-email-field'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
            errorText: emailError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        
        SizedBox(height: AppSpacing.space4),
        
        // Password field
        TextField(
          key: const Key('login-password-field'),
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: passwordError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        
        SizedBox(height: AppSpacing.space5),
        
        // Login button
        FilledButton.icon(
          key: const Key('sign-in-button'),
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: Color(0xFF6B4EFF),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_forward),
          label: Text(busy ? 'Signing in…' : 'Log in'),
        ),
        
        SizedBox(height: AppSpacing.space3),
        
        // Sign up option
        TextButton(
          onPressed: busy ? null : onSwitch,
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFF6B4EFF),
          ),
          child: const Text("Don't have an account? Sign up"),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Join Connect Me.',
          style: AppTypography.display(
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: AppSpacing.space2),
        
        Text(
          'Create an account to start tracking what matters.',
          style: AppTypography.body(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: AppSpacing.space5),
        
        TextField(
          key: const Key('signup-name-field'),
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Full name',
            errorText: nameError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        
        SizedBox(height: AppSpacing.space4),
        
        TextField(
          key: const Key('signup-email-field'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
            errorText: emailError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        
        SizedBox(height: AppSpacing.space4),
        
        TextField(
          key: const Key('signup-password-field'),
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: passwordError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        
        SizedBox(height: AppSpacing.space4),
        
        TextField(
          key: const Key('signup-confirm-field'),
          controller: confirmController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirm password',
            errorText: confirmError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        
        SizedBox(height: AppSpacing.space5),
        
        FilledButton.icon(
          key: const Key('sign-up-button'),
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: Color(0xFF6B4EFF),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(busy ? 'Creating account…' : 'Create account'),
        ),
        
        SizedBox(height: AppSpacing.space3),
        
        TextButton(
          onPressed: busy ? null : onSwitch,
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFF6B4EFF),
          ),
          child: const Text('Already have an account? Log in'),
        ),
      ],
    );
  }
}