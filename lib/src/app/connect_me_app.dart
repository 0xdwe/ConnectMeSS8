import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai_update_screen.dart';
import '../features/auth_screen.dart';
import '../features/contact_profile_screen.dart';
import '../features/profile_screen.dart';
import '../features/recommendations_screen.dart';
import '../features/shell_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/app', builder: (context, state) => const ShellScreen()),
      GoRoute(path: '/me', builder: (context, state) => const ProfileScreen()),
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
    );
  }
}
