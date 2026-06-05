import 'package:connect_me/src/features/edit_profile_screen.dart';
import 'package:connect_me/src/state/user_profile/user_profile_service.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUserProfileService implements UserProfileService {
  _FakeUserProfileService(this.profile);
  final AccountProfile profile;
  String? savedName;
  var uploadCalls = 0;
  var removeCalls = 0;
  bool fail = false;
  bool failRemove = false;

  @override
  AccountProfile? currentProfile() => profile;

  @override
  Future<void> updateDisplayName(String displayName) async {
    if (fail) throw Exception('boom');
    savedName = displayName;
  }

  @override
  Future<void> uploadAvatarAndUpdatePhotoUrl(imageFile) async {
    uploadCalls++;
  }

  @override
  Future<void> removeAvatar() async {
    removeCalls++;
    if (failRemove) throw Exception('remove failed');
  }
}

void main() {
  testWidgets('email is read-only and display name is required', (
    tester,
  ) async {
    final service = _FakeUserProfileService(
      const AccountProfile(
        uid: 'u1',
        email: 'real@example.com',
        name: 'Real User',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileServiceProvider.overrideWithValue(service),
          accountProfileProvider.overrideWithValue(service.profile),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const EditProfileScreen(),
        ),
      ),
    );

    expect(find.text('real@example.com'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('profile-email-field')))
          .readOnly,
      isTrue,
    );

    await tester.enterText(find.byKey(const Key('profile-name-field')), '   ');
    await tester.tap(find.byKey(const Key('profile-save-button')));
    await tester.pump();

    expect(find.text('Enter your name'), findsOneWidget);
    expect(service.savedName, isNull);
  });

  testWidgets('avatar remove failure does not update display name', (
    tester,
  ) async {
    final service = _FakeUserProfileService(
      const AccountProfile(
        uid: 'u1',
        email: 'real@example.com',
        name: 'Real User',
      ),
    )..failRemove = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileServiceProvider.overrideWithValue(service),
          accountProfileProvider.overrideWithValue(service.profile),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const EditProfileScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Changed Name',
    );
    await tester.tap(find.text('Remove Photo'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-save-button')));
    await tester.pump();

    expect(service.removeCalls, 1);
    expect(service.savedName, isNull);
    expect(find.text('Couldn’t update profile. Try again.'), findsOneWidget);
  });

  testWidgets('save trims and updates display name', (tester) async {
    final service = _FakeUserProfileService(
      const AccountProfile(
        uid: 'u1',
        email: 'real@example.com',
        name: 'Real User',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileServiceProvider.overrideWithValue(service),
          accountProfileProvider.overrideWithValue(service.profile),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const EditProfileScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      '  Changed Name  ',
    );
    await tester.tap(find.byKey(const Key('profile-save-button')));
    await tester.pump();

    expect(service.savedName, 'Changed Name');
    expect(service.uploadCalls, 0);
  });
}
