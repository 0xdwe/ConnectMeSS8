import 'package:connect_me/src/features/shell_screen.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test_overrides.dart';

void main() {
  group('ShellScreen bottom navigation', () {
    testWidgets('bottom nav shows Home, People, Plan, and You', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...signedInDemoOverrides(),
            memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.data(false),
            home: const ShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find all nav items by looking for the nav labels
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);

      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('tab labels use Plan and You', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...signedInDemoOverrides(),
            memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.data(false),
            home: const ShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Planner'), findsNothing);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('tapping nav items switches between tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...signedInDemoOverrides(),
            memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.data(false),
            home: const ShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start on Home
      expect(find.byKey(const Key('home-tab')), findsOneWidget);

      // Tap People
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('people-tab')), findsOneWidget);

      // Tap Plan
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-tab')), findsOneWidget);

      // Tap You
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('you-tab')), findsOneWidget);

      // Tap Home again
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-tab')), findsOneWidget);
    });

    testWidgets('avatar button navigates to settings', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const ShellScreen()),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Settings Screen'))),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...signedInDemoOverrides(),
            memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.data(false),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the avatar button (CircleAvatar in AppBar)
      final avatarButton = find.ancestor(
        of: find.byType(CircleAvatar),
        matching: find.byType(IconButton),
      );
      expect(avatarButton, findsOneWidget);

      await tester.tap(avatarButton);
      await tester.pumpAndSettle();

      // Should navigate to settings
      expect(find.text('Settings Screen'), findsOneWidget);
    });
  });
}
