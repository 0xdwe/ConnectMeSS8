import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UI/UX Improvements Widgets', () {
    testWidgets('ScoreGauge renders correctly with text and customs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 180,
                child: ScoreGauge(score: 55),
              ),
            ),
          ),
        ),
      );

      // Verify ScoreGauge is present
      expect(find.byType(ScoreGauge), findsOneWidget);
      // Verify text inside ScoreGauge
      expect(find.text('55'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.text('Keep nurturing your relationships!'), findsOneWidget);
      expect(find.text('Small steps lead to stronger connections.'), findsOneWidget);
    });

    testWidgets('DailyNudgeCard renders with title, prompt and buttons', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: Center(
              child: DailyNudgeCard(
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify DailyNudgeCard is present
      expect(find.byType(DailyNudgeCard), findsOneWidget);
      // Verify texts
      expect(find.text('Daily Nudge'), findsOneWidget);
      expect(find.text('A quick check-in can strengthen your connection.'), findsOneWidget);
      expect(find.text('Send a message'), findsOneWidget);

      // Tap the send button and verify callback
      await tester.tap(find.text('Send a message'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
