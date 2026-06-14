import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/features/auth_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

Future<void> pumpConnectMe(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...signedOutDemoOverrides(),
        routerProvider.overrideWith((ref) => GoRouter(
          initialLocation: '/auth',
          routes: [
            GoRoute(
              path: '/auth',
              builder: (context, state) => const AuthScreen(initialMode: AuthMode.login),
            ),
            GoRoute(
              path: '/app',
              builder: (context, state) => const Scaffold(
                body: SizedBox(key: Key('home-tab')),
              ),
            ),
          ],
        )),
      ],
      child: const ConnectMeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('valid login enters the main app', (tester) async {
    await pumpConnectMe(tester);

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-tab')), findsOneWidget);
  });

  testWidgets('login validation blocks empty submit', (tester) async {
    await pumpConnectMe(tester);

    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-tab')), findsNothing);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('login validation rejects malformed email and short password', (
    tester,
  ) async {
    await pumpConnectMe(tester);

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      '123',
    );
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-tab')), findsNothing);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('valid signup updates profile and enters the main app', (
    tester,
  ) async {
    await pumpConnectMe(tester);

    await tester.tap(find.byKey(const Key('auth-mode-signup')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('signup-name-field')),
      'Jamie Chen',
    );
    await tester.enterText(
      find.byKey(const Key('signup-email-field')),
      'jamie@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirm-field')),
      'password123',
    );
    await tester.ensureVisible(find.byKey(const Key('sign-up-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-up-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-tab')), findsOneWidget);
    // Username is no longer surfaced on shell chrome (#016 dropped the
    // wordmark+username header in favor of a three-tab IA); home-tab
    // visibility proves successful signup-to-shell entry.
  });

  testWidgets('signup blocks empty submit with field-level errors', (
    tester,
  ) async {
    await pumpConnectMe(tester);

    await tester.tap(find.byKey(const Key('auth-mode-signup')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('sign-up-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-up-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-tab')), findsNothing);
    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Confirm your password'), findsOneWidget);
  });

  testWidgets('signup rejects mismatched passwords', (tester) async {
    await pumpConnectMe(tester);

    await tester.tap(find.byKey(const Key('auth-mode-signup')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('signup-name-field')),
      'Jamie Chen',
    );
    await tester.enterText(
      find.byKey(const Key('signup-email-field')),
      'jamie@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirm-field')),
      'different456',
    );
    await tester.ensureVisible(find.byKey(const Key('sign-up-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-up-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-tab')), findsNothing);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('mode toggle switches between login and signup forms', (
    tester,
  ) async {
    await pumpConnectMe(tester);

    expect(find.byKey(const Key('login-email-field')), findsOneWidget);
    expect(find.byKey(const Key('signup-name-field')), findsNothing);

    await tester.tap(find.byKey(const Key('auth-mode-signup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signup-name-field')), findsOneWidget);
    expect(find.byKey(const Key('login-email-field')), findsNothing);
    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-mode-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email-field')), findsOneWidget);
    expect(find.byKey(const Key('signup-name-field')), findsNothing);
    expect(find.text('Log in'), findsWidgets);
  });
}
