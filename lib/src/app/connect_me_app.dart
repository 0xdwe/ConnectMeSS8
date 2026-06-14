import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai_update_screen.dart';
import '../features/auth_screen.dart';
import '../features/contact_profile_screen.dart';
import '../features/edit_profile_screen.dart';
import '../features/profile_screen.dart';
import '../features/recommendations_screen.dart';
import '../features/settings_screen.dart';
import '../features/shell_screen.dart';
import '../state/app_state.dart';
import '../state/memory/memory_providers.dart';
import '../state/memory/memory_topic_backfill_runner.dart';
import '../theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/app', builder: (context, state) => const ShellScreen()),
      GoRoute(path: '/me', builder: (context, state) => const ProfileScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/contact/:id',
        builder: (context, state) => ContactProfileScreen(
          contactId: state.pathParameters['id']!,
          initialSelectedTopic: state.uri.queryParameters['topic'],
          recommendationReason:
              state.uri.queryParameters['reason'],
          recommendationInsight:
              state.uri.queryParameters['insight'],
          recommendationAction:
              state.uri.queryParameters['action'],
        ),
      ),
      GoRoute(
        path: '/ai-update/:id',
        builder: (context, state) =>
            AiUpdateScreen(contactId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/recommendations',
        builder: (context, state) => const RecommendationsScreen(),
      ),
    ],
  );
});

class ConnectMeApp extends ConsumerStatefulWidget {
  const ConnectMeApp({super.key});

  @override
  ConsumerState<ConnectMeApp> createState() => _ConnectMeAppState();
}

class _ConnectMeAppState extends ConsumerState<ConnectMeApp> {
  bool _seededOnce = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final seeding = ref.watch(memorySeedingProvider);

    // Start the memory topic backfill in the background silently.
    ref.watch(memoryTopicBackfillProvider);

    ref.listen<AsyncValue<void>>(memorySeedingProvider, (previous, next) {
      if (!mounted) return;
      if ((next.hasValue || next.hasError) && !_seededOnce) {
        setState(() => _seededOnce = true);
      }
    });

    return MaterialApp.router(
      title: 'Connect Me',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data(false),
      darkTheme: AppTheme.data(true),
      themeMode: switch (appState.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: ref.read(routerProvider),
      builder: (context, child) {
        if (_seededOnce) {
          return child ?? const SizedBox.shrink();
        }
        return seeding.when(
          data: (_) => child ?? const SizedBox.shrink(),
          loading: () => const _MemorySeedingSplash(),
          error: (_, _) => child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _MemorySeedingSplash extends StatelessWidget {
  const _MemorySeedingSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
