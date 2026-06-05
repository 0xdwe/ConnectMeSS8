import 'package:connect_me/src/features/auth_screen.dart';
import 'package:connect_me/src/state/firebase_providers.dart';
import 'package:connect_me/src/state/user_profile/user_profile_service.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

class _SignupProfileService implements UserProfileService {
  _SignupProfileService({this.fail = false});

  final bool fail;
  final savedNames = <String>[];

  @override
  AccountProfile? currentProfile() => null;

  @override
  Future<void> updateDisplayName(String displayName) async {
    if (fail) throw Exception('display name failed');
    savedNames.add(displayName);
  }

  @override
  Future<void> uploadAvatarAndUpdatePhotoUrl(imageFile) async {}

  @override
  Future<void> removeAvatar() async {}
}

void main() {
  Future<MockFirebaseAuth> pumpSignup(
    WidgetTester tester, {
    UserProfileService? profileService,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final auth = MockFirebaseAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          if (profileService != null)
            userProfileServiceProvider.overrideWithValue(profileService),
          ...headlessStoreOverrides(),
        ],
        child: MaterialApp.router(
          theme: AppTheme.data(false),
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const AuthScreen()),
              GoRoute(path: '/app', builder: (_, _) => const Text('App')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('signup requires name', (tester) async {
    final auth = await pumpSignup(tester);

    await tester.enterText(
      find.byKey(const Key('signup-email-field')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password-field')),
      'password1',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirm-field')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('sign-up-button')));
    await tester.pump();

    expect(find.text('Full name is required'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('successful signup persists displayName', (tester) async {
    final profileService = _SignupProfileService();
    final auth = await pumpSignup(tester, profileService: profileService);

    await tester.enterText(
      find.byKey(const Key('signup-name-field')),
      '  New Person  ',
    );
    await tester.enterText(
      find.byKey(const Key('signup-email-field')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password-field')),
      'password1',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirm-field')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('sign-up-button')));
    await tester.pump();

    expect(auth.currentUser, isNotNull);
    expect(profileService.savedNames, ['New Person']);
  });

  testWidgets('signup does not navigate when displayName persistence fails', (
    tester,
  ) async {
    final profileService = _SignupProfileService(fail: true);
    await pumpSignup(tester, profileService: profileService);

    await tester.enterText(
      find.byKey(const Key('signup-name-field')),
      'New Person',
    );
    await tester.enterText(
      find.byKey(const Key('signup-email-field')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password-field')),
      'password1',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirm-field')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('sign-up-button')));
    await tester.pump();

    expect(find.text('App'), findsNothing);
    expect(find.text('Something went sideways — try again.'), findsOneWidget);
  });
}
