/// Structured response model for the [LlmAiUpdate] adapter (Pass 4.3,
/// PRD §Q4).
///
/// Pass 4.3 uses Gemini's `responseSchema` feature so the model
/// returns JSON validated against a fixed shape rather than free-form
/// prose. This file defines the Dart-side mirror of that shape — the
/// canonical type the adapter parses Gemini's response into before
/// mapping it onto an [AiUpdateResult]. Decoding is total over
/// well-formed JSON; malformed JSON throws [LlmResponseParseException]
/// which the adapter surfaces as one of the transient failures from
/// PRD §Q8 (single-retry-then-`AiUpdateFailure`).
///
/// The Gemini-side `responseSchema` JSON Schema instance lands in
/// `llm_ai_update.dart` alongside the actual SDK call (issue #080).
/// Splitting the Dart model out here keeps the parser unit-testable
/// without booting the Firebase AI Logic SDK and lets #078 ship
/// before #077's SDK wiring.
///
/// `interactionDepth` is clamped -100..100 at decode time. Negative
/// values represent conflictual/harmful interactions (fights, betrayals,
/// etc.) and produce a negative Bond Score delta via the curve in
/// `bond_score_curve.dart`. The clamp is belt-and-braces — an LLM
/// hiccup outside the [-100, 100] range is silently bounded.
library;

import '../models/social_models.dart' show InteractionType;

/// Suggestion kind for a Gemini-prepared Topic Suggestion.
enum LlmTopicSuggestionKind { ask, share, plan, remember }

class LlmTopicSuggestion {
  const LlmTopicSuggestion({
    required this.kind,
    required this.text,
    this.context,
    this.latestNews,
  });

  final LlmTopicSuggestionKind kind;
  final String text;
  final String? context;
  final String? latestNews;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'text': text,
    if (context != null) 'context': context,
    if (latestNews != null) 'latestNews': latestNews,
  };

  factory LlmTopicSuggestion.fromJson(Map<String, dynamic> json) {
    final kindRaw = _requireString(json, 'kind');
    final kind = LlmTopicSuggestionKind.values.firstWhere(
      (k) => k.name == kindRaw,
      orElse: () => throw LlmResponseParseException(
        'topicSuggestions[].suggestions[].kind unknown: "$kindRaw"',
      ),
    );
    final text = _requireString(json, 'text');
    if (_containsNumericDayCountShame(text)) {
      throw LlmResponseParseException(
        'topicSuggestions[].suggestions[].text violates anti-shame guardrail',
      );
    }
    final context = json['context'] as String?;
    if (context != null && _containsNumericDayCountShame(context)) {
      throw LlmResponseParseException(
        'topicSuggestions[].suggestions[].context violates anti-shame guardrail',
      );
    }
    final latestNews = json['latestNews'] as String?;
    if (latestNews != null && _containsNumericDayCountShame(latestNews)) {
      throw LlmResponseParseException(
        'topicSuggestions[].suggestions[].latestNews violates anti-shame guardrail',
      );
    }
    return LlmTopicSuggestion(
      kind: kind,
      text: text,
      context: context,
      latestNews: latestNews,
    );
  }
}

class LlmTopicSuggestionGroup {
  const LlmTopicSuggestionGroup({
    required this.topic,
    this.lastMentionedAt,
    this.mentionCount,
    this.expiresAt,
    this.suggestions = const <LlmTopicSuggestion>[],
  });

  final String topic;
  final String? lastMentionedAt;
  final int? mentionCount;
  final String? expiresAt;
  final List<LlmTopicSuggestion> suggestions;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'topic': topic,
    if (lastMentionedAt != null) 'lastMentionedAt': lastMentionedAt,
    if (mentionCount != null) 'mentionCount': mentionCount,
    if (expiresAt != null) 'expiresAt': expiresAt,
    'suggestions': suggestions.map((s) => s.toJson()).toList(),
  };

  factory LlmTopicSuggestionGroup.fromJson(Map<String, dynamic> json) {
    final suggestionsRaw = json['suggestions'];
    if (suggestionsRaw != null && suggestionsRaw is! List) {
      throw LlmResponseParseException(
        'topicSuggestions[].suggestions must be a list but was '
        '${suggestionsRaw.runtimeType}',
      );
    }
    return LlmTopicSuggestionGroup(
      topic: _requireString(json, 'topic'),
      lastMentionedAt: _readOptionalString(json, 'lastMentionedAt'),
      mentionCount: json['mentionCount'] is int
          ? json['mentionCount'] as int
          : (json['mentionCount'] is num
                ? (json['mentionCount'] as num).toInt()
                : null),
      expiresAt: _readOptionalString(json, 'expiresAt'),
      suggestions: (suggestionsRaw ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map<LlmTopicSuggestion>((e) => LlmTopicSuggestion.fromJson(e))
          .take(2)
          .toList(growable: false),
    );
  }
}

/// Marker exception thrown when an LLM response cannot be parsed
/// against the structured-output contract.
///
/// Per PRD §Q8 the [LlmAiUpdate] adapter classifies this as transient
/// (the schema-constrained-output API guarantees the shape, so a
/// malformed payload is almost always a network glitch or rare SDK
/// hiccup) and retries once before surfacing as `AiUpdateFailure`.
class LlmResponseParseException implements Exception {
  const LlmResponseParseException(this.message);
  final String message;
  @override
  String toString() => 'LlmResponseParseException: $message';
}

/// One tag the LLM proposes adding to a [MemoryDocument]'s upcoming
/// list. Mirrors the schema in PRD §Q4 (`upcomingToAdd[]`).
///
/// `dateIso` is the ISO-8601 day (YYYY-MM-DD) when the model could
/// infer one. When the model cannot pin a date but the entry is still
/// forward-looking, [relativeWhen] carries the human phrase
/// (e.g. "next month") and `dateIso` is null. Exactly one of the two
/// is required; the parser rejects entries with neither.
class LlmUpcomingEntry {
  const LlmUpcomingEntry({
    required this.label,
    required this.kind,
    this.dateIso,
    this.relativeWhen,
  });

  final String label;
  final LlmUpcomingKind kind;
  final String? dateIso;
  final String? relativeWhen;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'kind': kind.name,
    if (dateIso != null) 'dateIso': dateIso,
    if (relativeWhen != null) 'relativeWhen': relativeWhen,
  };

  factory LlmUpcomingEntry.fromJson(Map<String, dynamic> json) {
    final label = _requireString(json, 'label');
    final kindRaw = _requireString(json, 'kind');
    final kind = LlmUpcomingKind.values.firstWhere(
      (k) => k.name == kindRaw,
      orElse: () => throw LlmResponseParseException(
        'upcomingToAdd[].kind unknown: "$kindRaw"',
      ),
    );
    final dateIso = json['dateIso'] as String?;
    final relativeWhen = json['relativeWhen'] as String?;
    if ((dateIso == null || dateIso.isEmpty) &&
        (relativeWhen == null || relativeWhen.isEmpty)) {
      throw const LlmResponseParseException(
        'upcomingToAdd[] requires dateIso or relativeWhen',
      );
    }
    return LlmUpcomingEntry(
      label: label,
      kind: kind,
      dateIso: dateIso,
      relativeWhen: relativeWhen,
    );
  }
}

/// Coarse classification for [LlmUpcomingEntry]. Mirrors the prompt
/// rule "milestone | trip | appointment | celebration | other."
enum LlmUpcomingKind { milestone, trip, appointment, celebration, other }

/// Memory-document delta produced by one AI Update run. Applied
/// client-side (merge + cap rules from Pass 3 §Q7) on top of the
/// existing [MemoryDocument].
class LlmMemoryUpdate {
  const LlmMemoryUpdate({
    required this.newHistoryBullet,
    this.summary,
    this.topicsToAdd = const <String>[],
    this.preferencesToAdd = const <String>[],
    this.upcomingToAdd = const <LlmUpcomingEntry>[],
    this.topicSuggestions = const <LlmTopicSuggestionGroup>[],
  });

  /// Full-replacement summary, or null when the input does not
  /// materially change the contact's narrative (PRD §Q6).
  final String? summary;

  /// Exactly one bullet, prefixed `- YYYY-MM-DD — ...`. Format is
  /// validated against [_historyBulletPattern] at decode time.
  final String newHistoryBullet;

  final List<String> topicsToAdd;
  final List<String> preferencesToAdd;
  final List<LlmUpcomingEntry> upcomingToAdd;
  final List<LlmTopicSuggestionGroup> topicSuggestions;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'summary': summary,
    'newHistoryBullet': newHistoryBullet,
    'topicsToAdd': topicsToAdd,
    'preferencesToAdd': preferencesToAdd,
    'upcomingToAdd': upcomingToAdd.map((e) => e.toJson()).toList(),
    'topicSuggestions': topicSuggestions.map((e) => e.toJson()).toList(),
  };

  factory LlmMemoryUpdate.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as String?;
    final bullet = _requireString(json, 'newHistoryBullet');
    if (!_historyBulletPattern.hasMatch(bullet)) {
      throw LlmResponseParseException(
        'newHistoryBullet must match "- YYYY-MM-DD — ..." but was: '
        '"$bullet"',
      );
    }
    return LlmMemoryUpdate(
      summary: summary,
      newHistoryBullet: bullet,
      topicsToAdd: _readStringList(json, 'topicsToAdd'),
      preferencesToAdd: _readStringList(json, 'preferencesToAdd'),
      upcomingToAdd: (json['upcomingToAdd'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map<LlmUpcomingEntry>((e) => LlmUpcomingEntry.fromJson(e))
          .toList(growable: false),
      topicSuggestions: _readTopicSuggestionGroups(json),
    );
  }
}

/// Relevance-classifier result (Pass 4.4 / #112).
///
/// Returned by the lightweight Gemini pre-classifier that runs before
/// the main AI Update call. [isRelevant] gates whether the main call
/// proceeds; [reason] provides the user-facing explanation when the
/// classifier rejects the input.
class LlmRelevanceResult {
  const LlmRelevanceResult({required this.isRelevant, required this.reason});

  final bool isRelevant;
  final String reason;

  factory LlmRelevanceResult.fromJson(Map<String, dynamic> json) {
    final isRelevant = json['isRelevant'];
    if (isRelevant is! bool) {
      throw const LlmResponseParseException(
        'isRelevant must be a bool',
      );
    }
    final reason = json['reason'];
    if (reason is! String || reason.isEmpty) {
      throw const LlmResponseParseException(
        'reason must be a non-empty string',
      );
    }
    return LlmRelevanceResult(isRelevant: isRelevant, reason: reason);
  }
}

/// Top-level shape Gemini returns under PRD §Q4's structured output
/// schema. The adapter maps this onto an [AiUpdateResult] before
/// commit; this class is a wire format, not a domain object.
class LlmAiUpdateResponse {
  const LlmAiUpdateResponse({
    required this.interactionType,
    required this.interactionTitle,
    required this.interactionNote,
    required this.memoryUpdate,
    required this.interactionDepth,
    this.nextStep,
    this.promptVersion,
    this.modelName,
  });

  final InteractionType interactionType;
  final String interactionTitle;
  final String interactionNote;
  final LlmMemoryUpdate memoryUpdate;

  /// Clamped 0..100 at decode time. The LLM judges the input's depth
  /// on its own merits per the prompt rubric (0=trivial, 25=brief,
  /// 50=substantive, 75=significant, 100=deep day-long bonding).
  /// `LlmAiUpdate._projectOntoAiUpdateResult` runs the diminishing-
  /// returns curve in `applyBondScoreCurve` to translate this into
  /// the actual Bond Score delta. The clamp is belt-and-braces
  /// against a single hiccup. See PRD §Q6 addendum (2026-06-01) and
  /// `docs/issues/085-apply-llm-bondscoredelta.md`.
  final int interactionDepth;
  final String? nextStep;

  /// Echoed back from the request for traceability. Optional on the
  /// wire; the adapter populates it when emitting the [AiUpdateResult].
  final int? promptVersion;
  final String? modelName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'interactionType': interactionType.name,
    'interactionTitle': interactionTitle,
    'interactionNote': interactionNote,
    'memoryUpdate': memoryUpdate.toJson(),
    'interactionDepth': interactionDepth,
    if (nextStep != null) 'nextStep': nextStep,
    if (promptVersion != null) 'promptVersion': promptVersion,
    if (modelName != null) 'modelName': modelName,
  };

  factory LlmAiUpdateResponse.fromJson(Map<String, dynamic> json) {
    final typeRaw = _requireString(json, 'interactionType');
    final type = InteractionType.values.firstWhere(
      (t) => t.name == typeRaw,
      orElse: () => throw LlmResponseParseException(
        'interactionType unknown: "$typeRaw"',
      ),
    );
    final title = _requireString(json, 'interactionTitle');
    if (title.length > 60) {
      throw LlmResponseParseException(
        'interactionTitle must be ≤60 chars (was ${title.length})',
      );
    }
    final note = _requireString(json, 'interactionNote');
    final memoryRaw = json['memoryUpdate'];
    if (memoryRaw is! Map<String, dynamic>) {
      throw const LlmResponseParseException('memoryUpdate is required');
    }
    final memory = LlmMemoryUpdate.fromJson(memoryRaw);
    final depth = _requireInt(json, 'interactionDepth');
    final clampedDepth = depth.clamp(-100, 100);
    final nextStep = json['nextStep'] as String?;
    if (nextStep != null && nextStep.length > 80) {
      throw LlmResponseParseException(
        'nextStep must be ≤80 chars (was ${nextStep.length})',
      );
    }
    final promptVersion = json['promptVersion'] as int?;
    final modelName = json['modelName'] as String?;
    return LlmAiUpdateResponse(
      interactionType: type,
      interactionTitle: title,
      interactionNote: note,
      memoryUpdate: memory,
      interactionDepth: clampedDepth,
      nextStep: nextStep,
      promptVersion: promptVersion,
      modelName: modelName,
    );
  }
}

// History bullet must look like "- YYYY-MM-DD — <body>" exactly.
// Em dash U+2014 is required (the prompt asks for it explicitly to
// keep the format unambiguous). Body must be non-empty.
final RegExp _historyBulletPattern = RegExp(r'^- \d{4}-\d{2}-\d{2} \u2014 .+$');

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw LlmResponseParseException(
      '$key must be a string but was ${value.runtimeType}',
    );
  }
  if (value.isEmpty) {
    throw LlmResponseParseException('$key must be non-empty');
  }
  return value;
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw LlmResponseParseException(
      '$key must be a string when present but was ${value.runtimeType}',
    );
  }
  if (value.isEmpty) return null;
  return value;
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw LlmResponseParseException(
    '$key must be an int but was ${value.runtimeType}',
  );
}

bool _containsNumericDayCountShame(String text) {
  final lower = text.toLowerCase();
  final hasNumericDayCount = RegExp(r'\b\d+\s+days?\b').hasMatch(lower);
  final hasGuiltPhrase =
      lower.contains("haven't") ||
      lower.contains('have not') ||
      lower.contains('neglect') ||
      lower.contains('forgot') ||
      lower.contains('you are letting') ||
      lower.contains("you're letting") ||
      lower.contains('you should have') ||
      lower.contains('you failed');
  return (hasNumericDayCount && hasGuiltPhrase) ||
      lower.contains('you are neglecting') ||
      lower.contains("you're neglecting") ||
      lower.contains('you neglect') ||
      lower.contains('you forgot') ||
      lower.contains('you failed');
}

List<LlmTopicSuggestionGroup> _readTopicSuggestionGroups(
  Map<String, dynamic> json,
) {
  final value = json['topicSuggestions'];
  if (value == null) return const <LlmTopicSuggestionGroup>[];
  if (value is! List) {
    throw LlmResponseParseException(
      'topicSuggestions must be a list but was ${value.runtimeType}',
    );
  }
  return value
      .whereType<Map<String, dynamic>>()
      .map<LlmTopicSuggestionGroup>((e) => LlmTopicSuggestionGroup.fromJson(e))
      .toList(growable: false);
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const <String>[];
  if (value is! List) {
    throw LlmResponseParseException(
      '$key must be a list but was ${value.runtimeType}',
    );
  }
  return value.whereType<String>().toList(growable: false);
}
