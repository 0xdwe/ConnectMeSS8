import 'package:connect_me/src/features/shell_screen.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('ShellScreen three-tab navigation', () {
    testWidgets('bottom nav shows exactly 3 items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
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
      
      // Settings should NOT be in bottom nav
      expect(find.text('Setting'), findsNothing);
    });

    testWidgets('tab labels are Home, People, Plan (not Planner)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
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
    });

    testWidgets('tapping nav items switches between 3 tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
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

      // Tap Home again
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-tab')), findsOneWidget);
    });

    testWidgets('avatar button navigates to settings', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ShellScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Settings Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
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
