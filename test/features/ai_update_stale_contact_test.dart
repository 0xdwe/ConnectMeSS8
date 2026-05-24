import 'package:connect_me/src/features/ai_update_screen.dart';
import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

void main() {
  testWidgets(
    'ai update screen handles deleted contact gracefully',
    (tester) async {
      final container = ProviderContainer(overrides: [
        ...signedInDemoOverrides(),
        memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
      ]);
      addTearDown(container.dispose);

      // Delete the seeded contact 'mike' before opening the screen.
      container.read(appControllerProvider.notifier).deleteConnection('mike');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.data(false),
            home: const AiUpdateScreen(contactId: 'mike'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The screen must render without throwing, and show the friendly
      // not-found scaffold instead of crashing on a missing contact.
      expect(tester.takeException(), isNull);
      expect(find.text('Contact Not Found'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
    },
  );
}
