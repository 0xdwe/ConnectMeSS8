import 'package:connect_me/src/features/tabs/settings_tab.dart';
import 'package:connect_me/src/features/modals/about_modal.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

void main() {
  testWidgets('AboutModal slides up when row is tapped and displays key info', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: SettingsTab()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap on the 'About Connect Me' settings row
    await tester.tap(find.text('About Connect Me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify modal elements are displayed
    expect(find.byType(AboutModal), findsOneWidget);
    expect(find.text('Connect Me'), findsWidgets);
    expect(find.text('Version 3.0.0 (Build 42)'), findsOneWidget);
    expect(find.text("WHAT'S NEW IN V3"), findsOneWidget);

    // Verify a sample feature highlight is listed
    expect(find.text('AI Memory Updates'), findsOneWidget);
    expect(
      find.text('Generates deep Markdown memories summarizing contact histories, preferences, and key topics.'),
      findsOneWidget,
    );

    // Verify buttons are present
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Send Feedback'), findsOneWidget);

    // Tap Done to close bottom sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Verify modal is closed
    expect(find.byType(AboutModal), findsNothing);
  });
}
