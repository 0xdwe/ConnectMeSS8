import 'package:connect_me/src/ai/llm_ai_update_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('llm_ai_update_prompt', () {
    test('exposes a non-empty versioned system prompt', () {
      expect(kLlmAiUpdatePromptVersion, 1);
      expect(kLlmAiUpdatePromptV1, isNotEmpty);
    });

    test('encodes anti-shame voice rule against numeric day counts', () {
      // The prompt must explicitly forbid "you haven't talked to X in
      // N days" copy — that's the Pass 3 anti-shame guardrail
      // recorded in CONTEXT.md and AGENTS.md.
      final lowered = kLlmAiUpdatePromptV1.toLowerCase();
      expect(lowered, contains('numeric day counts'));
      expect(lowered, contains('shame'));
    });

    test('forbids inventing details when input does not support them',
        () {
      final lowered = kLlmAiUpdatePromptV1.toLowerCase();
      expect(lowered, contains('never invent'));
    });

    test('encodes the bondScoreDelta calibration rubric', () {
      // PRD §Q6: 0 trivial, 1-2 normal, 3-4 meaningful, 5 major.
      // Every band should be visible to the model.
      expect(kLlmAiUpdatePromptV1, contains('bondScoreDelta'));
      expect(kLlmAiUpdatePromptV1, contains('0 for trivial'));
      expect(kLlmAiUpdatePromptV1, contains('1-2 for normal'));
      expect(kLlmAiUpdatePromptV1, contains('3-4 for meaningful'));
      expect(kLlmAiUpdatePromptV1, contains('5 only for major moments'));
    });

    test('specifies the empty-input fallback contract', () {
      // PRD §Q6: empty input + no images → bondScoreDelta=0, no
      // invented content, generic bullet.
      final lowered = kLlmAiUpdatePromptV1.toLowerCase();
      expect(lowered, contains('input is empty'));
      expect(lowered, contains('do not invent'));
    });

    test('describes the history bullet format', () {
      // PRD §Q4 schema: "- YYYY-MM-DD — <body>".
      expect(kLlmAiUpdatePromptV1, contains('YYYY-MM-DD'));
      expect(kLlmAiUpdatePromptV1, contains('newHistoryBullet'));
    });

    test('describes the upcomingToAdd kind enum', () {
      // PRD §Q7 / schema: milestone | trip | appointment |
      // celebration | other. Each has to be in the prompt for the
      // model to pick from.
      for (final kind in const [
        'milestone',
        'trip',
        'appointment',
        'celebration',
        'other',
      ]) {
        expect(
          kLlmAiUpdatePromptV1,
          contains(kind),
          reason: 'prompt should reference upcoming kind: $kind',
        );
      }
    });

    test('tells the model it can see image attachments', () {
      final lowered = kLlmAiUpdatePromptV1.toLowerCase();
      expect(lowered, contains('image'));
      expect(lowered, contains('you can see them'));
    });
  });
}
