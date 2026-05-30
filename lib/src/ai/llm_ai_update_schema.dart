/// Gemini-side JSON Schema instance for [LlmAiUpdateResponse]
/// (Pass 4.3, PRD §Q4).
///
/// Lives in its own file rather than next to [LlmAiUpdateResponse]
/// because the Schema constants below couple to the Firebase AI
/// Logic SDK (`firebase_ai`). The Dart-side response model in
/// `llm_ai_update_response.dart` deliberately has no SDK dependency
/// so it can be unit-tested without booting Firebase; this file is
/// the SDK-facing translation that ships with the actual Gemini
/// call.
///
/// The shape mirrors `LlmAiUpdateResponse.fromJson` exactly:
/// the response parser is the load-bearing validator, and the
/// schema is belt-and-braces. If the two ever diverge, the parser
/// rejects the divergent payload and the adapter retries (PRD §Q8).
library;

import 'package:firebase_ai/firebase_ai.dart';

import '../models/social_models.dart' show InteractionType;
import 'llm_ai_update_response.dart';

/// JSON Schema passed to Gemini via `GenerationConfig.responseSchema`.
///
/// Constructed once at startup and reused per call. The Schema is
/// immutable from the SDK's perspective; sharing the constant is
/// safe.
final Schema kLlmAiUpdateResponseSchema = Schema.object(
  description:
      'Structured AI Update result for ConnectMe. Every field below '
      'maps directly onto LlmAiUpdateResponse.fromJson; mismatches '
      'will be rejected client-side and retried per PRD §Q8.',
  properties: {
    'interactionType': Schema.enumString(
      enumValues: InteractionType.values.map((t) => t.name).toList(),
      description:
          'Closest fit from the interaction-type enum. Default to '
          '"interaction" when in doubt.',
    ),
    'interactionTitle': Schema.string(
      description:
          'Short title in Title Case, ≤60 chars, present tense '
          '("Personal context captured", "Birthday plans logged").',
    ),
    'interactionNote': Schema.string(
      description:
          'One-or-two-sentence paraphrase of the user\'s input. Do '
          'not echo verbatim; do not embellish.',
    ),
    'memoryUpdate': Schema.object(
      description:
          'Delta to apply to the contact\'s MemoryDocument. '
          'topicsToAdd / preferencesToAdd / upcomingToAdd are '
          'merge deltas, not full replacements.',
      properties: {
        'summary': Schema.string(
          description:
              'Full-replacement summary, or null when the input does '
              'not materially change the contact\'s narrative '
              '(normal interactions return null here).',
          nullable: true,
        ),
        'newHistoryBullet': Schema.string(
          description:
              'Exactly one history bullet, prefixed '
              '"- {YYYY-MM-DD} — {body}" using the date from the '
              'prompt context. Em dash U+2014 required.',
        ),
        'topicsToAdd': Schema.array(
          items: Schema.string(),
          description:
              'New conversation-hook topics. Lowercase, ≤3 words '
              'each. Skip topics already in memory.',
        ),
        'preferencesToAdd': Schema.array(
          items: Schema.string(),
          description:
              'New stable, factual preferences. Skip ephemeral mood '
              'items.',
        ),
        'upcomingToAdd': Schema.array(
          items: Schema.object(
            properties: {
              'label': Schema.string(),
              'kind': Schema.enumString(
                enumValues:
                    LlmUpcomingKind.values.map((k) => k.name).toList(),
              ),
              'dateIso': Schema.string(
                description:
                    'ISO-8601 day (YYYY-MM-DD) when a date can be '
                    'inferred. Required when relativeWhen is absent.',
                nullable: true,
              ),
              'relativeWhen': Schema.string(
                description:
                    'Human relative phrase ("next month") when no '
                    'specific date can be pinned. Required when '
                    'dateIso is absent.',
                nullable: true,
              ),
            },
            optionalProperties: const ['dateIso', 'relativeWhen'],
          ),
        ),
      },
      optionalProperties: const ['summary'],
    ),
    'bondScoreDelta': Schema.integer(
      description:
          'Bond-score change in 0..5 per the PRD §Q6 rubric: 0 '
          'trivial, 1-2 normal, 3-4 meaningful, 5 only for major '
          'life moments. Clamped client-side; defaults toward '
          'smaller numbers.',
    ),
    'nextStep': Schema.string(
      description:
          'One concrete, gentle next-interaction suggestion ≤80 '
          'chars. Phrased as something the user could do, not '
          'something they should feel guilty about not doing. Null '
          'when there is no useful next step.',
      nullable: true,
    ),
  },
  optionalProperties: const ['nextStep'],
);
