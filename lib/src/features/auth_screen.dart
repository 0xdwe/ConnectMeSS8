import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_widgets.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: GradientScaffold(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: AppTheme.moss, borderRadius: BorderRadius.circular(34)),
                  child: const Icon(Icons.hub_outlined, color: Colors.white, size: 54),
                ),
                const SizedBox(height: 28),
                const Text('Remember people\nlike it matters.', style: TextStyle(fontSize: 42, height: 1.02, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Text(
                  'Track personal context, shared moments, next steps, and AI-sorted updates in one gentle CRM.',
                  style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  key: const Key('sign-in-button'),
                  onPressed: () {
                    ref.read(appControllerProvider.notifier).signIn();
                    context.go('/app');
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Enter mock workspace'),
                ),
                const SizedBox(height: 12),
                const Text('No backend. No real auth. Session demo only.'),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
