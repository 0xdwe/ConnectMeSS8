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
/// `bondScoreDelta` is clamped 0..5 at decode time. The model is
/// instructed (in the prompt) to stay in that range and the schema
/// will reject out-of-range values, but the clamp is belt-and-braces
/// — a single LLM hiccup will not move bond score wildly.
library;

import '../models/social_models.dart' show InteractionType;

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
enum LlmUpcomingKind {
  milestone,
  trip,
  appointment,
  celebration,
  other,
}

/// Memory-document delta produced by one AI Update run. Applied
/// client-side (merge + cap rules from Pass 3 §Q7) on top of the
/// existing [MemoryDocument].
class LlmMemoryUpdate {
  const LlmMemoryUpdate({
    required this.newHistoryBullet,
    this.summary,
    this.topicsToAdd = const [],
    this.preferencesToAdd = const [],
    this.upcomingToAdd = const [],
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'summary': summary,
        'newHistoryBullet': newHistoryBullet,
        'topicsToAdd': topicsToAdd,
        'preferencesToAdd': preferencesToAdd,
        'upcomingToAdd': upcomingToAdd.map((e) => e.toJson()).toList(),
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
      upcomingToAdd: (json['upcomingToAdd'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LlmUpcomingEntry.fromJson)
          .toList(growable: false),
    );
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
    required this.bondScoreDelta,
    this.nextStep,
    this.promptVersion,
    this.modelName,
  });

  final InteractionType interactionType;
  final String interactionTitle;
  final String interactionNote;
  final LlmMemoryUpdate memoryUpdate;

  /// Clamped 0..5 at decode time. The model picks per the prompt
  /// rubric; the clamp is belt-and-braces against a single hiccup.
  final int bondScoreDelta;
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
        'bondScoreDelta': bondScoreDelta,
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
    final delta = _requireInt(json, 'bondScoreDelta');
    final clampedDelta = delta < 0 ? 0 : (delta > 5 ? 5 : delta);
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
      bondScoreDelta: clampedDelta,
      nextStep: nextStep,
      promptVersion: promptVersion,
      modelName: modelName,
    );
  }
}

// History bullet must look like "- YYYY-MM-DD — <body>" exactly.
// Em dash U+2014 is required (the prompt asks for it explicitly to
// keep the format unambiguous). Body must be non-empty.
final RegExp _historyBulletPattern = RegExp(
  r'^- \d{4}-\d{2}-\d{2} \u2014 .+$',
);

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

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw LlmResponseParseException(
    '$key must be an int but was ${value.runtimeType}',
  );
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) {
    throw LlmResponseParseException(
      '$key must be a list but was ${value.runtimeType}',
    );
  }
  return value.whereType<String>().toList(growable: false);
}
