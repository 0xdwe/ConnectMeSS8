import 'package:connect_me/src/ai/llm_ai_update_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('llm_ai_update_prompt', () {
    test('exposes a non-empty versioned system prompt', () {
      expect(kLlmAiUpdatePromptVersion, 2);
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

    test('forbids inventing details when input does not support them', () {
      final lowered = kLlmAiUpdatePromptV1.toLowerCase();
      expect(lowered, contains('never invent'));
    });

    test('encodes the interactionDepth 0..100 rubric (PRD §Q6 addendum)', () {
      // PRD §Q6 addendum (2026-06-01) / #085: the LLM judges depth on
      // a 0..100 scale with five anchors. Code applies the
      // diminishing-returns curve client-side; the model does NOT
      // know the contact's current Bond Score and must not estimate
      // a delta itself. Each anchor should be visible in the prompt
      // so a future regression in the rubric paragraph fails this
      // test rather than only surfacing in dogfooding.
      expect(kLlmAiUpdatePromptV1, contains('interactionDepth'));
      expect(kLlmAiUpdatePromptV1, contains('0'));
      expect(kLlmAiUpdatePromptV1, contains('25'));
      expect(kLlmAiUpdatePromptV1, contains('50'));
      expect(kLlmAiUpdatePromptV1, contains('75'));
      expect(kLlmAiUpdatePromptV1, contains('100'));
      // Spot-check the qualitative anchors. Substring matches keep
      // the test resilient to minor wording tweaks while still
      // catching anchor drift.
      final lowered = kLlmAiUpdatePromptV1.toLowerCase();
      expect(lowered, contains('trivial'));
      expect(lowered, contains('real conversation'));
      expect(lowered, contains('significant'));
      expect(lowered, contains('deep'));
    });

    test('does NOT mention the legacy bondScoreDelta field', () {
      // The 0..5 rubric was discarded in the 2026-06-01 grilling.
      // A prompt that still mentions bondScoreDelta would confuse
      // the model since the schema field is now interactionDepth.
      expect(kLlmAiUpdatePromptV1, isNot(contains('bondScoreDelta')));
    });

    test('specifies the empty-input fallback contract', () {
      // PRD §Q6 addendum: empty input + no images → interactionDepth=0,
      // no invented content, generic bullet.
      final lowered = kLlmAiUpdatePromptV1.toLowerCase();
      expect(lowered, contains('input is empty'));
      expect(lowered, contains('do not invent'));
    });

    test('describes the history bullet format', () {
      // PRD §Q4 schema: "- YYYY-MM-DD — <body>".
      expect(kLlmAiUpdatePromptV1, contains('YYYY-MM-DD'));
      expect(kLlmAiUpdatePromptV1, contains('newHistoryBullet'));
    });

    test('describes Topic Suggestions generation rules', () {
      final prompt = kLlmAiUpdatePromptV1;
      expect(prompt, contains('topicSuggestions'));
      for (final kind in const ['ask', 'share', 'plan', 'remember']) {
        expect(prompt, contains(kind));
      }
      expect(prompt, contains('at most'));
      expect(prompt, contains('three'));
      expect(prompt, contains('lastMentionedAt'));
      expect(prompt, contains('expiresAt'));
      expect(prompt.toLowerCase(), contains('non-shaming'));
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
