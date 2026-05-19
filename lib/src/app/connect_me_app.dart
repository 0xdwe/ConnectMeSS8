import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai_update_screen.dart';
import '../features/auth_screen.dart';
import '../features/contact_profile_screen.dart';
import '../features/profile_screen.dart';
import '../features/recommendations_screen.dart';
import '../features/settings_screen.dart';
import '../features/shell_screen.dart';
import '../state/app_state.dart';
import '../state/memory/memory_providers.dart';
import '../theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/app', builder: (context, state) => const ShellScreen()),
      GoRoute(path: '/me', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/contact/:id', builder: (context, state) => ContactProfileScreen(contactId: state.pathParameters['id']!)),
      GoRoute(path: '/ai-update/:id', builder: (context, state) => AiUpdateScreen(contactId: state.pathParameters['id']!)),
      GoRoute(path: '/recommendations', builder: (context, state) => const RecommendationsScreen()),
    ],
  );
});

class ConnectMeApp extends ConsumerWidget {
  const ConnectMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    // Drive the seed migration on first observe. The provider is a
    // FutureProvider<void>; we watch it so the initial frame waits on
    // the seed pass before any screen reads memoryProvider. Tests
    // override memoryStoreProvider with a pre-populated store, which
    // makes the seeding a no-op.
    final seeding = ref.watch(memorySeedingProvider);
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
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        return seeding.when(
          data: (_) => child ?? const SizedBox.shrink(),
          loading: () => const _MemorySeedingSplash(),
          // On error we proceed to the app; the lazy-creation path in
          // memoryProvider covers any still-unbacked connection.
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
    // Static placeholder rather than a spinner. The seed pass resolves
    // in microseconds (in-memory) or tens of milliseconds (file), so
    // the user never visibly sees this frame. A `CircularProgressIndicator`
    // here would also break `pumpAndSettle` in widget tests, since its
    // animation never stops.
    return const Scaffold(body: SizedBox.shrink());
  }
}
