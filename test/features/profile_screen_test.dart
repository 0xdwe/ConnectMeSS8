import 'package:connect_me/src/features/profile_screen.dart';
import 'package:connect_me/src/state/user_profile/user_profile_service.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/account_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

class _FakeUserProfileService implements UserProfileService {
  _FakeUserProfileService(this.profile);
  final AccountProfile? profile;

  @override
  AccountProfile? currentProfile() => profile;

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  Future<void> uploadAvatarAndUpdatePhotoUrl(imageFile) async {}

  @override
  Future<void> removeAvatar() async {}
}

void main() {
  testWidgets('Profile screen renders Firebase Auth-backed profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedInDemoOverrides(),
          userProfileServiceProvider.overrideWithValue(
            _FakeUserProfileService(
              const AccountProfile(
                uid: 'uid-1',
                email: 'real@example.com',
                name: 'Real User',
                photoUrl:
                    'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const ProfileScreen(),
        ),
      ),
    );

    expect(find.text('Real User'), findsOneWidget);
    expect(find.text('real@example.com'), findsOneWidget);
    expect(find.text('Demo'), findsNothing);
    final avatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byType(AccountAvatar),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(avatar.backgroundImage, isA<NetworkImage>());
    expect(
      (avatar.backgroundImage! as NetworkImage).url,
      'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
    );
    // Widget tests block real HTTP image loads; this test asserts the
    // NetworkImage is wired to the Auth photo URL, then clears the expected
    // blocked-load exception.
    expect(tester.takeException(), isNotNull);
  });
}
