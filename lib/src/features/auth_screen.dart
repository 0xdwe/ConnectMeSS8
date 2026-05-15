import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme/app_tokens.dart';
import '../widgets/crm_widgets.dart';

enum _AuthMode { login, signup }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthMode _mode = _AuthMode.login;

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

  void _submitLogin() {
    final emailError = _validateEmail(_loginEmail.text.trim());
    final passwordError = _validatePassword(_loginPassword.text);
    setState(() {
      _loginEmailError = emailError;
      _loginPasswordError = passwordError;
    });
    if (emailError != null || passwordError != null) return;
    ref.read(appControllerProvider.notifier).signIn();
    context.go('/app');
  }

  void _submitSignup() {
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
    ref.read(appControllerProvider.notifier).signUp(name: name, email: email);
    context.go('/app');
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
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: tokens.primary,
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: Icon(
                    Icons.hub_outlined,
                    color: tokens.primaryOn,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _mode == _AuthMode.login ? 'Welcome back.' : 'Join Connect Me.',
                  style: const TextStyle(
                    fontSize: 36,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _mode == _AuthMode.login
                      ? 'Log in to keep your connections close.'
                      : 'Create an account to start tracking what matters.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                _ModeSelector(mode: _mode, onChanged: _switchMode),
                const SizedBox(height: 24),
                if (_mode == _AuthMode.login)
                  _LoginForm(
                    emailController: _loginEmail,
                    passwordController: _loginPassword,
                    emailError: _loginEmailError,
                    passwordError: _loginPasswordError,
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
                    onSubmit: _submitSignup,
                    onSwitch: () => _switchMode(_AuthMode.login),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Prototype demo. No real backend or saved accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: tokens.inkMuted),
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
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(4),
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
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: selected ? tokens.primary : tokens.inkMuted,
          ),
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
    required this.onSubmit,
    required this.onSwitch,
  });
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? emailError;
  final String? passwordError;
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
        const SizedBox(height: 16),
        TextField(
          key: const Key('login-password-field'),
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: passwordError,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('sign-in-button'),
          onPressed: onSubmit,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Log in'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onSwitch,
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        TextField(
          key: const Key('signup-password-field'),
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: passwordError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('signup-confirm-field'),
          controller: confirmController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirm password',
            errorText: confirmError,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('sign-up-button'),
          onPressed: onSubmit,
          icon: const Icon(Icons.check),
          label: const Text('Create account'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onSwitch,
          child: const Text('Already have an account? Log in'),
        ),
      ],
    );
  }
}
