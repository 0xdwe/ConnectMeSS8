import 'package:connect_me/src/features/tabs/you_tab.dart';
import 'package:connect_me/src/state/user_profile/user_profile_service.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/account_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

void main() {
  testWidgets('You tab renders the authenticated account profile', (
    tester,
  ) async {
    const profile = AccountProfile(
      uid: 'uid-1',
      email: 'real@example.com',
      name: 'Real User',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedInDemoOverrides(),
          accountProfileProvider.overrideWithValue(profile),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: YouTab()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Real User'), findsOneWidget);
    expect(find.text('real@example.com'), findsOneWidget);
    expect(find.text('Alex Martinez'), findsNothing);
    expect(find.byType(AccountAvatar), findsOneWidget);
  });
}
