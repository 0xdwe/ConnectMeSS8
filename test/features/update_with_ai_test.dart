import 'package:connect_me/src/app/connect_me_app.dart';
import 'package:connect_me/src/features/ai_update_screen.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAndSignIn(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));
  await tester.pumpAndSettle();
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
}

void main() {
  group('AI Update Screen State Machine', () {
    testWidgets('starts in inputting state with form visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const ProviderScope(
            child: AiUpdateScreen(contactId: 'mike'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai-input-field')), findsOneWidget);
      expect(find.byKey(const Key('run-ai-button')), findsOneWidget);
      expect(find.text('Update Connection'), findsOneWidget);
    });

    testWidgets('transitions to previewing state after AI generates result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const ProviderScope(
            child: AiUpdateScreen(contactId: 'mike'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai-input-field')),
        'Had coffee with Mike today',
      );
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pump(); // Start async operation
      await tester.pump(const Duration(milliseconds: 100)); // Allow AI service to complete
      await tester.pumpAndSettle();

      // Should show preview UI
      expect(find.text('Here\'s what I found'), findsOneWidget);
      expect(find.byKey(const Key('preview-card-0')), findsOneWidget);
      expect(find.byKey(const Key('save-button')), findsOneWidget);
      expect(find.byKey(const Key('cancel-button')), findsOneWidget);
    });

    testWidgets('preview shows editable title and note fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const ProviderScope(
            child: AiUpdateScreen(contactId: 'mike'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai-input-field')),
        'Had coffee with Mike',
      );
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pumpAndSettle();

      // Should have editable fields
      expect(find.byKey(const Key('preview-title-0')), findsOneWidget);
      expect(find.byKey(const Key('preview-note-0')), findsOneWidget);
      
      // Should show AI tag
      expect(find.text('AI suggested'), findsOneWidget);
    });

    testWidgets('user can edit preview fields before saving', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const ProviderScope(
            child: AiUpdateScreen(contactId: 'mike'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai-input-field')),
        'Had coffee with Mike',
      );
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pumpAndSettle();

      // Edit the title
      await tester.enterText(
        find.byKey(const Key('preview-title-0')),
        'Edited coffee meeting',
      );
      await tester.pumpAndSettle();

      expect(find.text('Edited coffee meeting'), findsOneWidget);
    });

    testWidgets('cancel button returns to inputting state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const ProviderScope(
            child: AiUpdateScreen(contactId: 'mike'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai-input-field')),
        'Had coffee with Mike',
      );
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.byKey(const Key('cancel-button')));
      await tester.pumpAndSettle();

      // Should return to input form
      expect(find.byKey(const Key('ai-input-field')), findsOneWidget);
      expect(find.text('Here\'s what I found'), findsNothing);
    });

    testWidgets('save button commits changes and shows snackbar', (tester) async {
      await _pumpAndSignIn(tester);

      await tester.tap(find.text('People').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Mike Chen'),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('people-tab')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Mike Chen'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('update-with-ai-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai-input-field')),
        'Had coffee with Mike',
      );
      await tester.tap(find.byKey(const Key('run-ai-button')));
      await tester.pumpAndSettle();

      // Save the preview
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      // Should show snackbar with undo
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  testWidgets(
    'tapping Update with AI on a contact dashboard opens the Update with AI screen',
    (tester) async {
      await _pumpAndSignIn(tester);

      await tester.tap(find.text('People').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Mike Chen'),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('people-tab')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Mike Chen'));
      await tester.pumpAndSettle();

      final updateButton = find.byKey(const Key('update-with-ai-button'));
      await tester.tap(updateButton);
      await tester.pumpAndSettle();

      expect(find.text('Update with AI'), findsOneWidget);
      expect(find.text('Update Mike Chen'), findsOneWidget);
    },
  );

  testWidgets(
    'image attachments render as previews, non-image attachments render as chips',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const ProviderScope(
            child: AiUpdateScreen(
              contactId: 'mike',
              initialAttachments: [
                AttachmentRef(name: 'photo.jpg', path: '/tmp/missing.jpg'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('attachment-preview-photo.jpg')), findsOneWidget);
      expect(find.widgetWithText(Chip, 'photo.jpg'), findsNothing);
    },
  );
}
