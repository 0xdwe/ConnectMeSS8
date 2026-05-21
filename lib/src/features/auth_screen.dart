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
        // Map Firebase error codes to inline field errors so the user
        // sees the same UX shape as the local validators.
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
      // Best-effort displayName — the AppController user record is
      // populated from the form name regardless, so a failure here is
      // not fatal.
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
    // Translate Firebase codes into the app's voice (warm, never
    // shaming, never technical).
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
      body: GradientScaffold(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.space5),
            child: ListView(
              children: [
                SizedBox(height: AppSpacing.space5),
                Container(
                  padding: EdgeInsets.all(AppSpacing.space5),
                  decoration: BoxDecoration(
                    color: tokens.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Icon(
                    Icons.hub_outlined,
                    color: tokens.primaryOn,
                    size: 54,
                  ),
                ),
                SizedBox(height: AppSpacing.space5),
                Text(
                  _mode == _AuthMode.login ? 'Welcome back.' : 'Join Connect Me.',
                  style: AppTypography.display(),
                ),
                SizedBox(height: AppSpacing.space2),
                Text(
                  _mode == _AuthMode.login
                      ? 'Log in to keep your connections close.'
                      : 'Create an account to start tracking what matters.',
                  style: AppTypography.body(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppSpacing.space5),
                _ModeSelector(mode: _mode, onChanged: _switchMode),
                SizedBox(height: AppSpacing.space5),
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
                SizedBox(height: AppSpacing.space4),
                Text(
                  'Powered by Firebase Auth.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(color: tokens.inkMuted),
                ),
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
        color: tokens.surfaceSunken,
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
          color: selected ? tokens.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: selected ? AppTokens.elevation1(dark) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.body(
            color: selected ? tokens.primary : tokens.inkMuted,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('login-email-field'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
            errorText: emailError,
          ),
        ),
        SizedBox(height: AppSpacing.space4),
        TextField(
          key: const Key('login-password-field'),
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: passwordError,
          ),
        ),
        SizedBox(height: AppSpacing.space5),
        FilledButton.icon(
          key: const Key('sign-in-button'),
          onPressed: busy ? null : onSubmit,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward),
          label: Text(busy ? 'Signing in…' : 'Log in'),
        ),
        SizedBox(height: AppSpacing.space3),
        TextButton(
          onPressed: busy ? null : onSwitch,
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
        TextField(
          key: const Key('signup-name-field'),
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Full name',
            errorText: nameError,
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
          ),
        ),
        SizedBox(height: AppSpacing.space5),
        FilledButton.icon(
          key: const Key('sign-up-button'),
          onPressed: busy ? null : onSubmit,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(busy ? 'Creating account…' : 'Create account'),
        ),
        SizedBox(height: AppSpacing.space3),
        TextButton(
          onPressed: busy ? null : onSwitch,
          child: const Text('Already have an account? Log in'),
        ),
      ],
    );
  }
}
