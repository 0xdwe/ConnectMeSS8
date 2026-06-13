import 'package:connect_me/src/features/tabs/settings_tab.dart';
import 'package:connect_me/src/features/modals/about_modal.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/chain_logo.dart';
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
    expect(find.byType(LinkedChainLogo), findsOneWidget);
    expect(find.byIcon(Icons.diversity_3), findsNothing);
    expect(find.byKey(const Key('about-feature-scroll')), findsOneWidget);
    expect(find.byKey(const Key('about-done-button')), findsOneWidget);

    // Verify a sample feature highlight is listed
    expect(find.text('AI Memory Updates'), findsOneWidget);
    expect(
      find.text(
        'Generates deep Markdown memories summarizing contact histories, preferences, and key topics.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tracks relationship health (0–100) with Bond Rings and automatic cadence-based Bond Drift.',
      ),
      findsOneWidget,
    );

    // The About sheet has one clear dismissal action.
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Send Feedback'), findsNothing);
    expect(tester.takeException(), isNull);
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

  testWidgets('Done stays visible while feature highlights scroll', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);
    await _openAboutSheet(tester);

    await tester.drag(
      find.byKey(const Key('about-feature-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-done-button')), findsOneWidget);
    expect(find.text('Auth-Backed Profiles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
