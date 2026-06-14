import 'package:connect_me/src/features/shell_screen.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/state/user_profile/user_profile_service.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/account_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test_overrides.dart';

List<dynamic> _shellOverrides({String? photoUrl}) {
  return [
    ...signedInDemoOverrides(),
    accountProfileProvider.overrideWithValue(
      AccountProfile(
        uid: 'demo-uid',
        email: 'demo@example.com',
        name: 'Demo',
        photoUrl: photoUrl,
      ),
    ),
    memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
  ];
}

void main() {
  group('ShellScreen bottom navigation', () {
    testWidgets('bottom nav shows Home, People, Plan, and You', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [..._shellOverrides()],
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
          overrides: [..._shellOverrides()],
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
          overrides: [..._shellOverrides()],
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

    testWidgets('avatar button selects the You tab', (tester) async {
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
          overrides: [..._shellOverrides()],
          child: MaterialApp.router(
            theme: AppTheme.data(false),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-tab')), findsOneWidget);
      expect(find.byTooltip('Open profile'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('you-tab')), findsOneWidget);
      final shellContext = tester.element(find.byType(ShellScreen));
      expect(
        ProviderScope.containerOf(
          shellContext,
        ).read(appControllerProvider).selectedTab,
        3,
      );
      expect(find.text('Settings Screen'), findsNothing);
    });

    testWidgets('header avatar uses the uploaded account photo', (
      tester,
    ) async {
      const photoUrl = 'https://example.com/uploaded-avatar.jpg';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [..._shellOverrides(photoUrl: photoUrl)],
          child: MaterialApp(
            theme: AppTheme.data(false),
            home: const ShellScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AccountAvatar), findsOneWidget);
      final avatar = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.byType(AccountAvatar),
          matching: find.byType(CircleAvatar),
        ),
      );
      expect(avatar.backgroundImage, isA<NetworkImage>());
      expect((avatar.backgroundImage! as NetworkImage).url, photoUrl);
      // Widget tests block real HTTP image loads. The assertion above verifies
      // that the uploaded Auth photo URL is wired into the header avatar.
      expect(tester.takeException(), isNotNull);
    });
  });
}
