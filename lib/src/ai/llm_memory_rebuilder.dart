/// Production [MemoryRebuilder] adapter backed by Gemini (#124).
///
/// Uses Firebase AI Logic to regenerate a contact's memory document
/// after an interaction is deleted, removing references to the deleted
/// interaction and regenerating summary, history, preferences, topics,
/// upcoming, and topic-scoped suggestions from the remaining
/// interactions.
///
/// **Pattern:** Mirrors [LlmMemoryTopicEnricher] — single structured
/// output call to Gemini with retry logic, function-injection seam
/// for tests, and [MemoryRebuildFailure] for all errors.
library;

import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/social_models.dart';
import '../state/memory/memory_document.dart';
import 'llm_ai_update_response.dart'
    show
        LlmResponseParseException,
        LlmTopicSuggestion,
        LlmTopicSuggestionGroup,
        LlmTopicSuggestionKind,
        LlmUpcomingEntry;
import 'llm_memory_rebuild_response.dart';
import 'memory_rebuilder.dart';

/// Thrown when memory rebuild fails.
class MemoryRebuildFailure implements Exception {
  const MemoryRebuildFailure(this.message);
  final String message;
  @override
  String toString() => 'MemoryRebuildFailure: $message';
}

/// Default model for memory rebuild.
const String kLlmMemoryRebuilderDefaultModel = 'gemini-2.5-flash';
const Duration kLlmMemoryRebuilderTimeout = Duration(seconds: 20);
const int kLlmMemoryRebuilderPromptVersion = 1;

/// System prompt for memory rebuild.
const String kLlmMemoryRebuilderPromptV1 = '''
You are an AI relationship assistant. Your task is to rebuild a contact's memory document after an activity log entry has been deleted. You must remove all references to the deleted activity and regenerate the memory sections from the remaining interaction history.

Input:
- The contact's current memory document (may contain references to the deleted activity)
- The remaining interaction history (after deletion)
- The deleted interaction that was removed

Output:
You must produce a complete, updated memory document with these sections:
- Summary: A concise summary of the contact's relationship with the user, updated to reflect the remaining interactions only.
- History: A chronological narrative of the relationship, removing any mention of the deleted activity.
- Preferences: The contact's known preferences, updated if the deleted activity was the sole source.
- Topics: Up to 8 lowercase topic keywords (\u22643 words each) relevant to the remaining interactions.
- Topic Suggestions: For each topic, 1-2 conversation starter suggestions with kind (ask/share/plan/remember), text, and context.
- Upcoming: Upcoming events/dates from the remaining interactions.

Strict Guardrails:
1. NEVER mention or reference the deleted activity in any section.
2. Preserve information from the remaining interactions that was not dependent on the deleted one.
3. If the deleted activity was the sole source of a topic or preference, remove it.
4. Anti-shame: NEVER use numeric day counts (e.g., "you haven't talked in 47 days") or guilt-tripping language.
5. Keep the summary concise (2-3 sentences).
6. Keep the history as a flowing narrative paragraph, not bullet points.
7. Each topic suggestion must have exactly 1 or 2 suggestions.
8. The nextStep field should be a single, actionable suggestion for what the user should do next with this contact.
''';

/// Function-injection seam for the Gemini `generateContent` call.
///
/// Tests inject a fake function that returns canned text;
/// production wires the real SDK call. Mirrors the
/// [GeminiGenerateContentFn] typedef in [LlmAiUpdate].
typedef GeminiRebuildContentFn = Future<String> Function({
  required String modelName,
  required String systemPrompt,
  required Schema responseSchema,
  required List<Content> contents,
  required Duration timeout,
});

/// Production [MemoryRebuilder] adapter backed by Gemini (#124).
class LlmMemoryRebuilder implements MemoryRebuilder {
  LlmMemoryRebuilder({
    required this.firebaseAi,
    this.model = kLlmMemoryRebuilderDefaultModel,
    this.timeout = kLlmMemoryRebuilderTimeout,
    this.systemPrompt = kLlmMemoryRebuilderPromptV1,
    this.promptVersion = kLlmMemoryRebuilderPromptVersion,
    this.clock = _systemClock,
    this.geminiRebuildContentFn,
    this.failOnNetwork = false,
  });

  final FirebaseAI? firebaseAi;
  final String model;
  final Duration timeout;
  final String systemPrompt;
  final int promptVersion;
  final DateTime Function() clock;

  /// Function-injection seam for tests. When null, the default
  /// implementation uses [firebaseAi] to build a [GenerativeModel].
  final GeminiRebuildContentFn? geminiRebuildContentFn;

  /// Test injection knob — throws [MemoryRebuildFailure] before the
  /// Gemini call to simulate a network failure.
  final bool failOnNetwork;

  @override
  Future<MemoryRebuildResult> rebuild({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> remainingInteractions,
    required CrmInteraction deletedInteraction,
  }) async {
    if (failOnNetwork) {
      throw const MemoryRebuildFailure('Injected network failure');
    }

    final today = clock();
    final userMessage = _buildUserMessage(
      contact: contact,
      currentMemory: currentMemory,
      remainingInteractions: remainingInteractions,
      deletedInteraction: deletedInteraction,
      today: today,
    );

    final parsed = await _generateAndParseWithRetry(
      [Content.text(userMessage)],
    );

    // Convert LLM types to domain types before merge.
    final convertedTopicSuggestions = parsed.topicSuggestions != null
        ? _convertTopicSuggestions(parsed.topicSuggestions!)
        : null;

    // Merge the rebuilt sections into the current memory, keeping
    // existing values when the model chose not to provide a replacement.
    final rebuiltMemory = currentMemory.copyWith(
      summary: parsed.summary ?? currentMemory.summary,
      history: parsed.history ?? currentMemory.history,
      preferences: parsed.preferences ?? currentMemory.preferences,
      topics: parsed.topics ?? currentMemory.topics,
      topicSuggestions:
          convertedTopicSuggestions ?? currentMemory.topicSuggestions,
      upcoming: _mergeUpcoming(parsed.upcoming, currentMemory.upcoming),
      lastUpdated: today,
    );

    return MemoryRebuildResult(
      memoryDocument: rebuiltMemory,
      nextStep: parsed.nextStep,
    );
  }

  // ── Gemini integration ──────────────────────────────────────────

  /// Resolves [geminiRebuildContentFn] to the effective function.
  GeminiRebuildContentFn get _effectiveRebuildContentFn =>
      geminiRebuildContentFn ?? _defaultRebuildContentFn;

  /// Default implementation of [GeminiRebuildContentFn] that builds
  /// a real [GenerativeModel] from [firebaseAi] and returns
  /// `response.text`. Throws [StateError] if [firebaseAi] is null —
  /// which only happens when a test forgets to inject a custom
  /// function or set a failure knob.
  Future<String> _defaultRebuildContentFn({
    required String modelName,
    required String systemPrompt,
    required Schema responseSchema,
    required List<Content> contents,
    required Duration timeout,
  }) async {
    final ai = firebaseAi;
    if (ai == null) {
      throw StateError(
        'LlmMemoryRebuilder reached the SDK call site with a null '
        'firebaseAi. Set geminiRebuildContentFn or wire a real '
        'FirebaseAI instance.',
      );
    }
    final generative = ai.generativeModel(
      model: modelName,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: responseSchema,
      ),
    );
    final response = await generative
        .generateContent(contents)
        .timeout(timeout);
    return response.text ?? '';
  }

  /// Generate-and-parse with one retry on transient errors.
  ///
  /// Retries on: [FirebaseAIException], [TimeoutException],
  /// [FormatException], [LlmResponseParseException].
  /// Throws [MemoryRebuildFailure] when both attempts fail.
  /// Parse is INSIDE the retry loop so a malformed response gets
  /// the same retry budget as a transient SDK error.
  Future<LlmMemoryRebuildResponse> _generateAndParseWithRetry(
    List<Content> contents,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final rawText = await _effectiveRebuildContentFn(
          modelName: model,
          systemPrompt: systemPrompt,
          responseSchema: kLlmMemoryRebuildResponseSchema,
          contents: contents,
          timeout: timeout,
        );
        return _parseResponse(rawText);
      } on FirebaseAIException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } on FormatException catch (e) {
        lastError = e;
      } on LlmResponseParseException catch (e) {
        lastError = e;
      }

      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    throw MemoryRebuildFailure(
      'AI failed to respond or returned invalid schema after retry: $lastError',
    );
  }

  /// Parses the raw Gemini response text into [LlmMemoryRebuildResponse].
  LlmMemoryRebuildResponse _parseResponse(String rawText) {
    if (rawText.isEmpty) {
      throw const FormatException('empty response body');
    }
    final stripped = _stripMarkdownFences(rawText).trim();
    final dynamic decoded = json.decode(stripped);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'expected JSON object, got ${decoded.runtimeType}',
      );
    }
    return LlmMemoryRebuildResponse.fromJson(decoded);
  }

  // ── prompt builder ──────────────────────────────────────────────

  String _buildUserMessage({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> remainingInteractions,
    required CrmInteraction deletedInteraction,
    required DateTime today,
  }) {
    final buf = StringBuffer();
    buf.writeln('Today: ${today.toIso8601String().substring(0, 10)}');
    buf.writeln();
    buf.writeln('Contact: ${contact.name}');
    buf.writeln('Category: ${contact.category}');
    buf.writeln('Bond Score: ${contact.bondScore}');
    buf.writeln();
    buf.writeln('=== CURRENT MEMORY DOCUMENT ===');
    buf.writeln(currentMemory.render());
    buf.writeln();
    buf.writeln('=== REMAINING INTERACTIONS (after deletion) ===');
    if (remainingInteractions.isEmpty) {
      buf.writeln('(No remaining interactions)');
    } else {
      for (final i in remainingInteractions.take(10)) {
        buf.writeln(
          '- ${i.date.toIso8601String().substring(0, 10)}: ${i.title} '
          '(${i.type.name})'
          '${i.note.isNotEmpty ? ' \u2014 ${i.note}' : ''}'
          '${i.source == InteractionSource.aiSuggested ? ' [AI]' : ''}',
        );
      }
    }
    buf.writeln();
    buf.writeln('=== DELETED INTERACTION (to remove from memory) ===');
    buf.writeln(
      'Date: ${deletedInteraction.date.toIso8601String().substring(0, 10)}',
    );
    buf.writeln('Title: ${deletedInteraction.title}');
    buf.writeln('Type: ${deletedInteraction.type.name}');
    buf.writeln('Note: ${deletedInteraction.note}');
    buf.writeln('Source: ${deletedInteraction.source.name}');
    buf.writeln();
    buf.writeln(
      'Rebuild the memory document, removing all references to the '
      'deleted interaction and regenerating sections from the remaining '
      'history.',
    );
    return buf.toString();
  }

  // ── helpers ─────────────────────────────────────────────────────

  /// Strips markdown code fences (```json ... ```) from the response.
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

  /// Merges upcoming entries from the LLM response with existing
  /// entries. When the LLM provides new entries, they replace the
  /// existing list. When null, the existing list is kept.
  static List<UpcomingEntry> _mergeUpcoming(
    List<LlmUpcomingEntry>? llmEntries,
    List<UpcomingEntry> existing,
  ) {
    if (llmEntries == null) return existing;
    if (llmEntries.isEmpty) return const [];
    return List.unmodifiable(
      llmEntries.map(_toUpcomingEntry).toList(),
    );
  }

  /// Converts an [LlmUpcomingEntry] to an [UpcomingEntry].
  static UpcomingEntry _toUpcomingEntry(LlmUpcomingEntry entry) {
    final iso = entry.dateIso;
    if (iso != null && iso.isNotEmpty) {
      final hasTimezone =
          iso.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(iso);
      final hasTime = iso.contains('T');
      final normalized = hasTimezone
          ? iso
          : (hasTime ? '${iso}Z' : '${iso}T00:00:00Z');
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) {
        return UpcomingEntry(startDate: parsed, description: entry.label);
      }
    }
    // Fall back to today when no parseable date is available.
    return UpcomingEntry(
      startDate: DateTime.now(),
      description: entry.label,
    );
  }

  /// Converts a [LlmTopicSuggestionGroup] list to domain [TopicSuggestionGroup].
  static List<TopicSuggestionGroup> _convertTopicSuggestions(
    List<LlmTopicSuggestionGroup> groups,
  ) {
    return List.unmodifiable(
      groups.map(_convertTopicSuggestionGroup).toList(),
    );
  }

  /// Converts a single [LlmTopicSuggestionGroup] to a [TopicSuggestionGroup].
  static TopicSuggestionGroup _convertTopicSuggestionGroup(
    LlmTopicSuggestionGroup group,
  ) {
    return TopicSuggestionGroup(
      topic: group.topic,
      lastMentionedAt: _tryParseDate(group.lastMentionedAt),
      mentionCount: group.mentionCount ?? 0,
      expiresAt: _tryParseDate(group.expiresAt),
      suggestions: List.unmodifiable(
        group.suggestions.map(_convertTopicSuggestion).toList(),
      ),
    );
  }

  /// Converts a [LlmTopicSuggestion] to a [TopicSuggestion].
  static TopicSuggestion _convertTopicSuggestion(LlmTopicSuggestion s) {
    return TopicSuggestion(
      kind: _toTopicSuggestionKind(s.kind),
      text: s.text,
      context: s.context,
      latestNews: s.latestNews,
    );
  }

  static TopicSuggestionKind _toTopicSuggestionKind(LlmTopicSuggestionKind k) {
    switch (k) {
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

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.contains('T') ? value : '${value}T00:00:00Z';
    return DateTime.tryParse(normalized);
  }
}

DateTime _systemClock() => DateTime.now();
