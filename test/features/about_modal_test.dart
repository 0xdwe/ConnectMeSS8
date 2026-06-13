import 'package:connect_me/src/features/tabs/settings_tab.dart';
import 'package:connect_me/src/features/modals/about_modal.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

/// Pumps a [SettingsTab] wrapped in the providers needed for headless tests.
Future<void> _pumpSettings(WidgetTester tester) async {
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
  await tester.pumpAndSettle();
}

/// Opens the About bottom sheet and waits for the animation to finish.
Future<void> _openAboutSheet(WidgetTester tester) async {
  await tester.tap(find.text('About Connect Me'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AboutModal displays key info when opened', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);
    await _openAboutSheet(tester);

    // Verify modal is present
    expect(find.byType(AboutModal), findsOneWidget);

    // 'Connect Me' appears in both the settings row and the modal title
    expect(find.text('Connect Me'), findsWidgets);
    expect(find.text('Version 3.0.0 (Build 42)'), findsOneWidget);
    expect(find.text("WHAT'S NEW IN V3"), findsOneWidget);

    // Verify a sample feature highlight is listed
    expect(find.text('AI Memory Updates'), findsOneWidget);
    expect(
      find.text(
        'Generates deep Markdown memories summarizing contact histories, preferences, and key topics.',
      ),
      findsOneWidget,
    );

    // Verify buttons are present
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Send Feedback'), findsOneWidget);
  });

  testWidgets('Done button dismisses the AboutModal', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);
    await _openAboutSheet(tester);
    expect(find.byType(AboutModal), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutModal), findsNothing);
  });

  testWidgets('Send Feedback shows a SnackBar', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);
    await _openAboutSheet(tester);

    await tester.tap(find.text('Send Feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Feedback features coming soon!'), findsOneWidget);
  });
}
