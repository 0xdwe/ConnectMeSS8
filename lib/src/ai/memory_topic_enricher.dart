import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/social_models.dart';
import '../state/memory/memory_document.dart';
import 'llm_ai_update_response.dart';

/// Thrown when memory enrichment fails.
class MemoryTopicEnricherFailure implements Exception {
  const MemoryTopicEnricherFailure(this.message);
  final String message;
  @override
  String toString() => 'MemoryTopicEnricherFailure: $message';
}

/// Interface for memory-only AI topic enrichment seam.
abstract interface class MemoryTopicEnricher {
  /// Enriches the given memory document using connection context and recent interactions.
  /// Returns an updated [MemoryDocument] candidate without mutating any database state.
  Future<MemoryDocument> enrich({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> recentInteractions,
  });
}

/// Default model for enrichment.
const String kMemoryTopicEnricherDefaultModel = 'gemini-2.5-flash';
const Duration kMemoryTopicEnricherTimeout = Duration(seconds: 20);

/// System prompt version.
const int kMemoryTopicEnricherPromptVersion = 4;

const String kMemoryTopicEnricherPromptV3 = '''
You are an AI relationship assistant. Your task is to analyze a contact's memory document and recent interaction history, then extract up to 8 conversation topics and prepare exactly 1 or 2 high-quality, gentle, topic-scoped conversation suggestions for every extracted topic. Do not leave the suggestions list empty for any topic.

Strict Guardrails:
1. Topics: Extracted topics must be properly capitalized (e.g., "SpaceX IPO", "AI Models", "Family Updates"), <= 3 words, and ranked by current relevance/importance. Do NOT include generic topics (like 'family', 'friends', 'work', 'college', 'high school') if there are more specific and useful topics available in the contact's context.
2. Phrasing and Anti-shame Guardrail: Suggestions must be personal, context-rich, gentle, and supportive. Connect the suggestions to past discussions, notes, or upcoming events from the contact's context when possible (e.g., "Sarah mentioned she was going to Paris", "he talked about his plans for a new startup"). Prioritize retrieving and highlighting specific personal details (such as names of other people, locations, dates, and plans) that the user might otherwise forget. Avoid generic, templated, or clinical explanations like "Based on the conversation topic..." or "Associated with...". NEVER use numeric day counts (e.g., "you haven't talked in 47 days", "it has been 3 weeks") or guilt-tripping language (e.g., "neglecting", "have not", "forgot").
3. Scoping: Each suggestion must be strictly scoped to its associated topic. Do not mix context or mention other topics in the suggestion.
4. Suggestions: Group suggestions by topic. For every single extracted topic in the topics list, you MUST generate 1 or 2 suggestions in the suggestions list. Each suggestion must have a kind ("ask", "share", "plan", or "remember"), a text containing one gentle action idea (the conversation starter), and a context containing the specific reason/context from memory/recent interactions why this suggestion makes sense, written as a natural, detail-rich reminder.
''';

const String kMemoryTopicEnricherPromptV4 = '''
You are an AI relationship assistant. Your task is to analyze a contact's memory document and recent interaction history, then extract up to 8 conversation topics and prepare exactly 1 or 2 high-quality, gentle, topic-scoped conversation suggestions for every extracted topic. Do not leave the suggestions list empty for any topic.

Strict Guardrails:
1. Topics: Extracted topics must be properly capitalized (e.g., "SpaceX IPO", "AI Models", "Family Updates"), <= 3 words, and ranked by current relevance/importance. Do NOT include generic topics (like 'family', 'friends', 'work', 'college', 'high school') if there are more specific and useful topics available in the contact's context.
2. Phrasing and Anti-shame Guardrail: Suggestions must be personal, context-rich, gentle, and supportive. Connect the suggestions to past discussions, notes, or upcoming events from the contact's context when possible (e.g., "Sarah mentioned she was going to Paris", "he talked about his plans for a new startup"). Prioritize retrieving and highlighting specific personal details (such as names of other people, locations, dates, and plans) that the user might otherwise forget. Avoid generic, templated, or clinical explanations like "Based on the conversation topic..." or "Associated with...". NEVER use numeric day counts (e.g., "you haven't talked in 47 days", "it has been 3 weeks") or guilt-tripping language (e.g., "neglecting", "have not", "forgot").
3. Scoping: Each suggestion must be strictly scoped to its associated topic. Do not mix context or mention other topics in the suggestion.
4. Suggestions: Group suggestions by topic. For every single extracted topic in the topics list, you MUST generate 1 or 2 suggestions in the suggestions list. Each suggestion must have a kind ("ask", "share", "plan", or "remember"), a text containing one gentle action idea (the conversation starter), and a context containing the specific reason/context from memory/recent interactions why this suggestion makes sense, written as a natural, detail-rich reminder.
5. Search & News: You have access to Google Search grounding. If a topic represents a specific company, technology (e.g., a specific AI model release like Claude Model Fable 5), current event, weather, or public subject, use Google Search to find the latest news, updates, or current state. Condense this news into a single, high-quality sentence and store it in 'latestNews'. If no news is found or the topic is purely personal (e.g., 'birthday', 'vacation'), leave 'latestNews' empty. Do not hallucinate news.
6. Summary: Generate a concise, person-focused summary (1-2 sentences) that captures who this person is in the user's life — their role, relationship dynamics, and key context. Keep it brief and personal (e.g., "Sarah is a college friend who works in marketing and loves hiking"). If the existing summary is already good, preserve it. Never use numeric day counts or guilt-tripping language.
''';

/// Production [MemoryTopicEnricher] adapter backed by Firebase AI Logic.
class LlmMemoryTopicEnricher implements MemoryTopicEnricher {
  LlmMemoryTopicEnricher({
    required this.firebaseAi,
    this.model = kMemoryTopicEnricherDefaultModel,
    this.timeout = kMemoryTopicEnricherTimeout,
    this.systemPrompt = kMemoryTopicEnricherPromptV4,
    this.clock = _systemClock,
    this.failOnNetwork = false,
  });

  final FirebaseAI? firebaseAi;
  final String model;
  final Duration timeout;
  final String systemPrompt;
  final DateTime Function() clock;

  // Test knobs
  final bool failOnNetwork;

  @override
  Future<MemoryDocument> enrich({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> recentInteractions,
  }) async {
    if (failOnNetwork) {
      throw const MemoryTopicEnricherFailure('Injected network failure');
    }

    final today = clock();
    final userMessage = _buildUserMessage(
      contact: contact,
      memory: currentMemory,
      recentInteractions: recentInteractions,
    );

    final ai = firebaseAi;
    if (ai == null) {
      throw StateError(
        'LlmMemoryTopicEnricher reached SDK call site with null firebaseAi. '
        'Ensure a knob is set or a real FirebaseAI instance is wired.',
      );
    }

    // Step 1: Query Google Search to fetch news on potential/current topics.
    // We run an unstructured call with Google Search enabled.
    const step1Prompt = '''
You are an AI relationship assistant. Your task is to analyze the contact's profile, memory document, and recent interaction history to extract the top conversation topics (up to 8). 

For each extracted topic:
1. Categorize it as either "Public" or "Private/Personal".
   - "Public" topics include currencies, markets, technology releases, specific public software/hardware/tools, publicly traded companies, public events, weather, and general public facts.
   - "Private/Personal" topics include family updates, birthdays, personal vacation plans, private hobbies, or individual relationships.
2. If a topic is "Private/Personal", do NOT perform any search. Output "News: None" immediately.
3. If a topic is "Public", use Google Search to fetch the latest news, updates, or current state. Condense this news into a single, high-quality sentence.
   - PRIVACY RULE: When searching, formulate generic, search-engine-friendly queries. Completely omit the contact's name, user's name, and any private personal identifiers (e.g., search for "Lombok travel current conditions" instead of "James Li's trip to Lombok").

Return the results in the following plain text format:
Topic: <topic name>
News: <one sentence news summary or 'None' if no news is found or if the topic is Private/Personal>

Do not include any other text, markdown formatting, or HTML.
''';

    final step1Generative = ai.generativeModel(
      model: model,
      systemInstruction: Content.system(step1Prompt),
      tools: [
        Tool.googleSearch(),
      ],
    );

    final step1RawText = await _generateUnstructuredWithRetry(step1Generative, [
      Content.text(userMessage),
    ]);

    final newsMap = _parseStep1Response(step1RawText);

    // Format news for Step 2
    final newsListBuf = StringBuffer();
    newsMap.forEach((topic, news) {
      newsListBuf.writeln('- $topic: $news');
    });
    final newsListStr = newsListBuf.toString();

    // Step 2: Call the model with structured output constraint to generate suggestions.
    final step2SystemPrompt = '''
$systemPrompt

We have already retrieved the latest news for some topics. If you select/suggest any of these topics, you MUST copy the exact latest news sentence provided below into the 'latestNews' field of the suggestion. If a topic is not in this list, or has no news, leave 'latestNews' empty.

Here is the list of topics and their pre-fetched latest news:
$newsListStr

Also generate a concise person summary based on all available context.
''';

    final step2Generative = ai.generativeModel(
      model: model,
      systemInstruction: Content.system(step2SystemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: kMemoryTopicEnricherResponseSchema,
      ),
    );

    final response = await _generateWithRetry(step2Generative, [
      Content.text(userMessage),
    ]);

    final mergedTopics = mergeTopics(
      existingTopics: currentMemory.topics,
      geminiTopics: response.topics,
    );

    final mergedSuggestions = mergeTopicSuggestions(
      existing: currentMemory.topicSuggestions,
      incoming: response.topicSuggestions,
      mergedTopics: mergedTopics,
      now: today,
    );

    return currentMemory.copyWith(
      topics: mergedTopics,
      topicSuggestions: mergedSuggestions,
      summary: response.summary ?? currentMemory.summary,
      lastUpdated: today,
    );
  }

  Future<LlmMemoryTopicEnricherResponse> _generateWithRetry(
    GenerativeModel generative,
    List<Content> contents,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await generative
            .generateContent(contents)
            .timeout(timeout);
        final text = response.text;
        if (text == null || text.isEmpty) {
          throw const FormatException('empty response body');
        }
        final stripped = _stripMarkdownFences(text).trim();
        final dynamic decoded = json.decode(stripped);
        if (decoded is! Map<String, dynamic>) {
          throw FormatException(
            'expected JSON object, got ${decoded.runtimeType}',
          );
        }
        return LlmMemoryTopicEnricherResponse.fromJson(decoded);
      } on FirebaseAIException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } on LlmResponseParseException catch (e) {
        lastError = e;
      } on FormatException catch (e) {
        lastError = e;
      }

      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    throw MemoryTopicEnricherFailure(
      'AI failed to respond or returned invalid schema after retry: $lastError',
    );
  }

  Future<String> _generateUnstructuredWithRetry(
    GenerativeModel generative,
    List<Content> contents,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await generative
            .generateContent(contents)
            .timeout(timeout);
        final text = response.text;
        if (text != null && text.isNotEmpty) {
          return text;
        }
        throw const FormatException('empty response body');
      } on FirebaseAIException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } on FormatException catch (e) {
        lastError = e;
      }

      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    throw MemoryTopicEnricherFailure(
      'AI failed to respond to search query after retry: $lastError',
    );
  }

  Map<String, String> _parseStep1Response(String text) {
    final Map<String, String> results = {};
    final lines = text.split('\n');
    String? currentTopic;
    for (var line in lines) {
      line = line.trim();
      if (line.toLowerCase().startsWith('topic:')) {
        currentTopic = line.substring(6).trim();
      } else if (line.toLowerCase().startsWith('news:') && currentTopic != null) {
        final news = line.substring(5).trim();
        if (news.isNotEmpty && news.toLowerCase() != 'none') {
          results[currentTopic.toLowerCase()] = news;
        }
        currentTopic = null;
      }
    }
    return results;
  }

  static String _buildUserMessage({
    required Connection contact,
    required MemoryDocument memory,
    required List<CrmInteraction> recentInteractions,
  }) {
    final buf = StringBuffer();
    buf.writeln('Contact Name: ${contact.name}');
    buf.writeln('Category: ${contact.category}');
    buf.writeln('Relationship Notes: ${contact.notes}');
    buf.writeln('Bond Score: ${contact.bondScore}');
    buf.writeln();
    buf.writeln('Current Memory Summary:');
    buf.writeln(memory.summary);
    buf.writeln();
    buf.writeln('Current Memory History:');
    buf.writeln(memory.history);
    buf.writeln();
    buf.writeln('Current Memory Preferences:');
    buf.writeln(memory.preferences);
    buf.writeln();
    buf.writeln('Current Memory Topics:');
    for (final t in memory.topics) {
      buf.writeln('- $t');
    }
    buf.writeln();
    buf.writeln('Recent Interactions:');
    if (recentInteractions.isEmpty) {
      buf.writeln('No recent interactions recorded.');
    } else {
      for (final it in recentInteractions) {
        buf.writeln('- Date: ${it.date.toIso8601String().substring(0, 10)}');
        buf.writeln('  Title: ${it.title}');
        buf.writeln('  Note: ${it.note}');
      }
    }
    return buf.toString();
  }

  static List<String> mergeTopics({
    required List<String> existingTopics,
    required List<String> geminiTopics,
  }) {
    if (geminiTopics.isEmpty) return existingTopics;

    final newTopics = geminiTopics
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final seen = <String>{for (final t in newTopics) t.toLowerCase()};

    final genericStarter = {
      'family',
      'friends',
      'work',
      'college',
      'high school',
    };

    final nonGenericExisting = existingTopics
        .map((t) => t.trim())
        .where(
          (t) =>
              t.isNotEmpty &&
              !genericStarter.contains(t.toLowerCase()) &&
              !seen.contains(t.toLowerCase()),
        )
        .toList();

    final merged = newTopics.take(MemoryDocument.topicCap).toList();
    for (final t in nonGenericExisting) {
      if (merged.length >= MemoryDocument.topicCap) break;
      merged.add(t);
    }
    return List.unmodifiable(merged);
  }

  static List<TopicSuggestionGroup> mergeTopicSuggestions({
    required List<TopicSuggestionGroup> existing,
    required List<LlmTopicSuggestionGroup> incoming,
    required List<String> mergedTopics,
    required DateTime now,
  }) {
    final incomingByTopic = <String, LlmTopicSuggestionGroup>{
      for (final g in incoming) g.topic.trim().toLowerCase(): g,
    };
    final existingByTopic = <String, TopicSuggestionGroup>{
      for (final g in existing) g.topic.trim().toLowerCase(): g,
    };

    final result = <TopicSuggestionGroup>[];

    for (final topic in mergedTopics) {
      final key = topic.trim().toLowerCase();
      final incomingGroup = incomingByTopic[key];
      final existingGroup = existingByTopic[key];

      if (incomingGroup != null) {
        final suggestions = incomingGroup.suggestions
            .map(
              (s) => TopicSuggestion(
                kind: _toMemoryTopicSuggestionKind(s.kind),
                text: s.text,
                context: s.context,
                latestNews: s.latestNews,
              ),
            )
            .take(2)
            .toList(growable: false);
        result.add(
          TopicSuggestionGroup(
            topic: topic,
            lastMentionedAt:
                _parseLlmDate(incomingGroup.lastMentionedAt) ?? now,
            mentionCount: (existingGroup?.mentionCount ?? 0) + 1,
            expiresAt: _parseLlmDate(incomingGroup.expiresAt),
            suggestions: List.unmodifiable(suggestions),
          ),
        );
      } else if (existingGroup != null) {
        result.add(
          TopicSuggestionGroup(
            topic: topic,
            lastMentionedAt: existingGroup.lastMentionedAt,
            mentionCount: existingGroup.mentionCount,
            expiresAt: existingGroup.expiresAt,
            suggestions: existingGroup.suggestions,
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  static TopicSuggestionKind _toMemoryTopicSuggestionKind(
    LlmTopicSuggestionKind kind,
  ) {
    switch (kind) {
      case LlmTopicSuggestionKind.ask:
        return TopicSuggestionKind.ask;
      case LlmTopicSuggestionKind.share:
        return TopicSuggestionKind.share;
      case LlmTopicSuggestionKind.plan:
        return TopicSuggestionKind.plan;
      case LlmTopicSuggestionKind.remember:
        return TopicSuggestionKind.remember;
    }
  }

  static DateTime? _parseLlmDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.contains('T') ? value : '${value}T00:00:00Z';
    return DateTime.tryParse(normalized);
  }

  static String _stripMarkdownFences(String body) {
    final trimmed = body.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    final newlineIdx = trimmed.indexOf('\n');
    if (newlineIdx < 0) return trimmed;
    final withoutOpener = trimmed.substring(newlineIdx + 1);
    final closerIdx = withoutOpener.lastIndexOf('```');
    if (closerIdx < 0) return withoutOpener;
    return withoutOpener.substring(0, closerIdx);
  }
}

/// Structured response schema for [LlmMemoryTopicEnricherResponse].
final Schema kMemoryTopicEnricherResponseSchema = Schema.object(
  description: 'Structured memory topic enrichment schema.',
  properties: {
    'summary': Schema.string(
      description: 'Concise person-focused summary (1-2 sentences).',
      nullable: true,
    ),
    'topics': Schema.array(
      items: Schema.string(),
      description: 'Extracted topics. Properly capitalized, <=3 words, ranked.',
    ),
    'topicSuggestions': Schema.array(
      description: 'Prepared suggestions per topic. Capped at 2.',
      items: Schema.object(
        properties: {
          'topic': Schema.string(description: 'Associated topic.'),
          'suggestions': Schema.array(
            items: Schema.object(
              properties: {
                'kind': Schema.enumString(
                  enumValues: const ['ask', 'share', 'plan', 'remember'],
                ),
                'text': Schema.string(
                  description: 'Actionable suggestion. No day counts.',
                ),
                'context': Schema.string(
                  description: 'The specific reason or context from memory why this suggestion makes sense. No guilt phrasing and no numeric day counts.',
                ),
                'latestNews': Schema.string(
                  description: 'Optional. Relevant current news or real-time context about this specific topic retrieved via Google Search. Empty if none found.',
                ),
              },
            ),
          ),
        },
      ),
    ),
  },
);

/// Dart parser mirror for the enrichment response.
class LlmMemoryTopicEnricherResponse {
  const LlmMemoryTopicEnricherResponse({
    this.summary,
    required this.topics,
    required this.topicSuggestions,
  });

  final String? summary;
  final List<String> topics;
  final List<LlmTopicSuggestionGroup> topicSuggestions;

  factory LlmMemoryTopicEnricherResponse.fromJson(Map<String, dynamic> json) {
    final topicsRaw = json['topics'];
    if (topicsRaw is! List) {
      throw const LlmResponseParseException('topics must be a list');
    }
    final topics = topicsRaw.whereType<String>().toList();

    final suggestionsRaw = json['topicSuggestions'];
    if (suggestionsRaw != null && suggestionsRaw is! List) {
      throw const LlmResponseParseException('topicSuggestions must be a list');
    }
    final List<LlmTopicSuggestionGroup> topicSuggestions = (suggestionsRaw ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map<LlmTopicSuggestionGroup>((e) => LlmTopicSuggestionGroup.fromJson(e))
        .toList();

    return LlmMemoryTopicEnricherResponse(
      summary: json['summary'] as String?,
      topics: topics,
      topicSuggestions: topicSuggestions,
    );
  }
}

/// Fake implementation of [MemoryTopicEnricher] for unit tests.
class FakeMemoryTopicEnricher implements MemoryTopicEnricher {
  FakeMemoryTopicEnricher({
    required this.topicsToReturn,
    required this.suggestionsToReturn,
    this.failOnNetwork = false,
  });

  final List<String> topicsToReturn;
  final List<LlmTopicSuggestionGroup> suggestionsToReturn;
  final bool failOnNetwork;

  @override
  Future<MemoryDocument> enrich({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> recentInteractions,
  }) async {
    if (failOnNetwork) {
      throw const MemoryTopicEnricherFailure('Injected network failure');
    }

    final mergedTopics = LlmMemoryTopicEnricher.mergeTopics(
      existingTopics: currentMemory.topics,
      geminiTopics: topicsToReturn,
    );

    final mergedSuggestions = LlmMemoryTopicEnricher.mergeTopicSuggestions(
      existing: currentMemory.topicSuggestions,
      incoming: suggestionsToReturn,
      mergedTopics: mergedTopics,
      now: DateTime.now(),
    );

    return currentMemory.copyWith(
      topics: mergedTopics,
      topicSuggestions: mergedSuggestions,
      summary: currentMemory.summary,
      lastUpdated: DateTime.now(),
    );
  }
}

DateTime _systemClock() => DateTime.now();
