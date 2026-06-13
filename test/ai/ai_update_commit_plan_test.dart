import 'package:connect_me/src/ai/ai_update_commit_plan.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Connection connection({int bondScore = 60, String nextStep = 'Call soon'}) {
    return Connection(
      id: 'contact-1',
      name: 'Sarah',
      email: 'sarah@example.com',
      category: 'Friends',
      avatar: '👋',
      bondScore: bondScore,
      nextStep: nextStep,
      lastContact: DateTime(2026),
      notes: 'notes',
      knownSince: DateTime(2020),
      preferredChannels: const ['Text'],
    );
  }

  CrmInteraction interaction({String id = 'interaction-1'}) {
    return CrmInteraction(
      id: id,
      contactId: 'contact-1',
      type: InteractionType.interaction,
      title: 'Coffee',
      note: 'Caught up',
      date: DateTime(2026, 6, 1),
      source: InteractionSource.aiSuggested,
    );
  }

  group('buildAiUpdateCommitPlan', () {
    test(
      'projects the accepted AI Update onto one interaction and an updated connection',
      () {
        final now = DateTime(2026, 6, 2, 12);
        final acceptedInteraction = interaction();
        final result = AiUpdateResult(
          summary: 'AI summary',
          contactId: 'contact-1',
          interactions: [acceptedInteraction],
          nextStep: 'Send photos',
          bondScoreDelta: 15,
        );

        final plan = buildAiUpdateCommitPlan(
          result: result,
          connection: connection(),
          now: now,
        );

        expect(plan.interaction, same(acceptedInteraction));
        expect(plan.summary, 'AI summary');
        expect(plan.updatedConnection.id, 'contact-1');
        expect(plan.updatedConnection.bondScore, 75);
        expect(plan.updatedConnection.nextStep, 'Send photos');
        expect(plan.updatedConnection.lastContact, now);
      },
    );

    test(
      'keeps the existing next step when the AI Update has no replacement',
      () {
        final plan = buildAiUpdateCommitPlan(
          result: AiUpdateResult(
            summary: 'AI summary',
            contactId: 'contact-1',
            interactions: [interaction()],
            bondScoreDelta: 5,
          ),
          connection: connection(nextStep: 'Existing step'),
          now: DateTime(2026, 6, 2),
        );

        expect(plan.updatedConnection.nextStep, 'Existing step');
      },
    );

    test('clamps Bond Score movement to the stored 0..100 range', () {
      final highPlan = buildAiUpdateCommitPlan(
        result: AiUpdateResult(
          summary: 'high',
          contactId: 'contact-1',
          interactions: [interaction(id: 'high')],
          bondScoreDelta: 20,
        ),
        connection: connection(bondScore: 95),
        now: DateTime(2026, 6, 2),
      );
      final lowPlan = buildAiUpdateCommitPlan(
        result: AiUpdateResult(
          summary: 'low',
          contactId: 'contact-1',
          interactions: [interaction(id: 'low')],
          bondScoreDelta: -20,
        ),
        connection: connection(bondScore: 5),
        now: DateTime(2026, 6, 2),
      );

      expect(highPlan.updatedConnection.bondScore, 100);
      expect(lowPlan.updatedConnection.bondScore, 0);
    });

    test(
      'rejects accepted AI Updates that do not contain exactly one interaction',
      () {
        final zeroInteractionResult = AiUpdateResult(
          summary: 'AI summary',
          contactId: 'contact-1',
          interactions: const [],
        );
        final multiInteractionResult = AiUpdateResult(
          summary: 'AI summary',
          contactId: 'contact-1',
          interactions: [
            interaction(id: '1'),
            interaction(id: '2'),
          ],
        );

        expect(
          () => buildAiUpdateCommitPlan(
            result: zeroInteractionResult,
            connection: connection(),
            now: DateTime(2026, 6, 2),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'applyAiUpdateResult expects exactly one interaction, got 0',
            ),
          ),
        );
        expect(
          () => buildAiUpdateCommitPlan(
            result: multiInteractionResult,
            connection: connection(),
            now: DateTime(2026, 6, 2),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'applyAiUpdateResult expects exactly one interaction, got 2',
            ),
          ),
        );
      },
    );
  });
}
