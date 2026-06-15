/// Structured response model for [LlmMemoryRebuilder] (#124).
///
/// All fields are optional so the model can decide which sections need
/// updating. When a field is null, the caller retains the existing
/// value from the current memory document.
library;

import 'package:firebase_ai/firebase_ai.dart' show Schema;

import 'llm_ai_update_response.dart'
    show LlmTopicSuggestionGroup, LlmUpcomingEntry;

/// Parsed response from the Gemini memory rebuild call.
class LlmMemoryRebuildResponse {
  const LlmMemoryRebuildResponse({
    this.summary,
    this.history,
    this.preferences,
    this.topics,
    this.topicSuggestions,
    this.upcoming,
    this.nextStep,
  });

  final String? summary;
  final String? history;
  final String? preferences;
  final List<String>? topics;
  final List<LlmTopicSuggestionGroup>? topicSuggestions;
  final List<LlmUpcomingEntry>? upcoming;
  final String? nextStep;

  factory LlmMemoryRebuildResponse.fromJson(Map<String, dynamic> json) {
    return LlmMemoryRebuildResponse(
      summary: json['summary'] as String?,
      history: json['history'] as String?,
      preferences: json['preferences'] as String?,
      topics: json['topics'] is List
          ? (json['topics'] as List).whereType<String>().toList()
          : null,
      topicSuggestions: json['topicSuggestions'] is List
          ? (json['topicSuggestions'] as List)
              .whereType<Map<String, dynamic>>()
              .map<LlmTopicSuggestionGroup>(
                (e) => LlmTopicSuggestionGroup.fromJson(e),
              )
              .toList()
          : null,
      upcoming: json['upcoming'] is List
          ? (json['upcoming'] as List)
              .whereType<Map<String, dynamic>>()
              .map<LlmUpcomingEntry>((e) => LlmUpcomingEntry.fromJson(e))
              .toList()
          : null,
      nextStep: json['nextStep'] as String?,
    );
  }
}

/// Schema for structured output of the memory rebuild Gemini call.
final Schema kLlmMemoryRebuildResponseSchema = Schema.object(
  description: 'Structured memory rebuild schema.',
  properties: {
    'summary': Schema.string(
      description: 'Updated 2-3 sentence summary of the relationship.',
    ),
    'history': Schema.string(
      description: 'Updated chronological narrative paragraph.',
    ),
    'preferences': Schema.string(
      description: 'Updated preferences text.',
    ),
    'topics': Schema.array(
      items: Schema.string(),
      description: 'Up to 8 lowercase topic keywords (≤3 words each).',
    ),
    'topicSuggestions': Schema.array(
      description: 'Conversation suggestions per topic.',
      items: Schema.object(
        properties: {
          'topic': Schema.string(description: 'Associated topic.'),
          'lastMentionedAt': Schema.string(
            description: 'ISO-8601 date when last mentioned.',
          ),
          'mentionCount': Schema.integer(
            description: 'Times this topic has been mentioned.',
          ),
          'expiresAt': Schema.string(
            description: 'Optional ISO-8601 expiry date.',
          ),
          'suggestions': Schema.array(
            items: Schema.object(
              properties: {
                'kind': Schema.enumString(
                  enumValues: const ['ask', 'share', 'plan', 'remember'],
                ),
                'text': Schema.string(
                  description: 'Conversation starter. No day counts.',
                ),
                'context': Schema.string(
                  description: 'Reason from memory for this suggestion.',
                ),
                'latestNews': Schema.string(
                  description: 'Optional current news about this topic.',
                ),
              },
            ),
          ),
        },
      ),
    ),
    'upcoming': Schema.array(
      items: Schema.object(
        properties: {
          'label': Schema.string(description: 'Description of upcoming event.'),
          'kind': Schema.enumString(
            enumValues: const [
              'milestone',
              'trip',
              'appointment',
              'celebration',
              'other',
            ],
          ),
          'dateIso': Schema.string(
            description: 'ISO-8601 date (YYYY-MM-DD) when known.',
          ),
          'relativeWhen': Schema.string(
            description: 'Relative phrase when exact date unknown.',
          ),
        },
      ),
    ),
    'nextStep': Schema.string(
      description: 'Single actionable next-step suggestion.',
    ),
  },
);
