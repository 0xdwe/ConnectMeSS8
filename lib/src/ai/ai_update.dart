import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../state/memory/memory_document.dart';
import '../state/memory/memory_store.dart';
import 'bond_score_curve.dart';

/// Marker exception for engine-level [AiUpdate] failures (PRD Q4).
///
/// Thrown by [MockAiUpdate] under test-injection or by future LLM
/// adapters when the run cannot produce a coherent result. Surfaced
/// to the user as a snackbar by the AI Update screen.
class AiUpdateFailure implements Exception {
  const AiUpdateFailure(this.message);
  final String message;
  @override
  String toString() => 'AiUpdateFailure: $message';
}

/// Marker exception thrown when the user cancels an in-flight AI
/// Update before the result is committed (PRD Pass 4.3 §Q8 group 3 /
/// #080).
///
/// Sibling of [AiUpdateFailure] rather than a subtype — cancellation
/// is not an error and the modal handles it as a silent close (no
/// snackbar). The two exception types are exhaustive at the call
/// site so nothing slips through generic `catch (e)`.
///
/// Lives in this file (rather than next to [LlmAiUpdate]) so
/// [MockAiUpdate] can throw it without an upward import. Both
/// adapters honor the `cancelToken` parameter on [AiUpdate.run].
class AiUpdateCancelled implements Exception {
  const AiUpdateCancelled();
  @override
  String toString() => 'AiUpdateCancelled';
}

/// Marker exception thrown by the relevance pre-classifier
/// (Pass 4.4 / #112) when the LLM judges the user's input as
/// irrelevant to relationship maintenance for the named contact.
///
/// Sibling of [AiUpdateFailure] and [AiUpdateCancelled] rather than
/// a subtype of either — the routing at the call site is different
/// (a dialog instead of a snackbar) and the type-exhaustive match in
/// the AI Update screen catches each branch distinctly. The
/// classifier sits between attachment preparation and the main
/// Gemini call, so this exception is only ever thrown from
/// [AiUpdate.run] — never from [AiUpdate.commit].
///
/// [reason] is the warm, specific, non-shaming explanation the
/// classifier LLM supplied; it lands verbatim in the user-facing
/// dialog. The prompt explicitly forbids numeric day-count shaming
/// language, so callers can render the reason without filtering.
class AiUpdateRejected implements Exception {
  const AiUpdateRejected({required this.reason});
  final String reason;
  @override
  String toString() => 'AiUpdateRejected: $reason';
}

/// Unified AI-update seam (PRD Q1).
///
/// One public entry point for the user-level operation "Update with AI
/// on `<contact>`": [run] produces the candidate result; [commit]
/// persists it. The two-step shape is what makes the Q5 cancel path
/// "discard both interactions and memory delta" cheap — a cancelled
/// run never hits the store.
///
/// Two adapters land downstream: a deterministic [MockAiUpdate] for
/// Pass 3, and a future `LlmAiUpdate` (Pass 4+, not implemented). The
/// engine-level all-or-nothing contract (PRD Q4) is hardened in #046;
/// this slice persists memory first, then applies the state delta.
abstract interface class AiUpdate {
  /// Produces the candidate [AiUpdateResult] for the given inputs.
  ///
  /// The result is **not** persisted — callers commit separately via
  /// [commit] (or by reading `aiUpdateProvider` and calling commit on
  /// the same instance).
  ///
  /// [cancelToken] (Pass 4.3 §Q8 / #080) is an optional Future the
  /// caller can complete to abort an in-flight run; production wires
  /// it from the AI Update modal's Cancel button (#081). Adapters
  /// that race against `cancelToken` throw [AiUpdateCancelled]
  /// (a sibling of [AiUpdateFailure]); the modal handles cancellation
  /// silently with no snackbar. [MockAiUpdate] ignores the token —
  /// its run is fast enough that mid-run cancellation has no
  /// observable effect.
  ///
  /// **Trade-off in [LlmAiUpdate]:** cancellation stops the adapter's
  /// `await` on the in-flight Gemini request, but it does NOT abort
  /// the underlying HTTP call — Firebase AI Logic's SDK does not
  /// expose a cancel hook on `GenerativeModel.generateContent`, and
  /// Dart `Future` has no platform-cancellation primitive. The
  /// orphan request continues in the background and may consume the
  /// project's token budget before settling. The user-visible
  /// experience (modal closes, no result observed) is correct; the
  /// cost-tracking implication is documented.
  Future<AiUpdateResult> run({
    required Connection contact,
    required String userInput,
    required MemoryDocument currentMemory,
    required List<AttachmentRef> attachments,
    Future<void>? cancelToken,
    Future<void> Function()? onClassifierPassed,
  });

  /// Persists a previously-produced [AiUpdateResult]: writes the new
  /// memory document via [MemoryStore] and applies the interaction
  /// delta to [AppController].
  ///
  /// Engine-level all-or-nothing is enforced in #046; this slice
  /// persists the memory first, then the state.
  Future<void> commit(AiUpdateResult result);
}

/// Deterministic Pass 3 adapter for [AiUpdate].
///
/// Reproduces [MockAiUpdateService.categorizeAndUpdate] (string-match
/// categorizer + interaction construction) and additionally appends a
/// date-stamped bullet to [MemoryDocument.history] so memory grows
/// narrative on each AI update — the "memory grows" property is the
/// whole point of #042.
///
/// All-or-nothing failure contract per PRD Q4 (#046):
/// - [run] is purely constructive — no I/O, no state mutation. A
///   failure in `run` cannot leave anything persisted.
/// - [commit] persists memory first, then applies the state delta.
///   If the state delta throws after the save succeeds, [commit]
///   reverts the memory file so neither side observes the failed run.
///
/// Test injection: [failOnRun], [failOnSave], and [failOnApply] force
/// failures at specific points to prove the contract. Not used in
/// production wiring — only set by tests.
class MockAiUpdate implements AiUpdate {
  MockAiUpdate({
    required this.memoryStore,
    required this.appController,
    this.onMemoryWritten,
    this.failOnRelevanceCheck = false,
    this.failOnRun = false,
    this.failOnSave = false,
    this.failOnApply = false,
    this.slowRunDuration,
  });

  final MemoryStore memoryStore;
  final AppController appController;

  /// Optional hook fired after [MemoryStore.save] succeeds in
  /// [commit]. Wired in production to bump `memoryEpochProvider` so
  /// `recommendationsProvider` sees the memory-change half of the
  /// PRD Q2 dual invalidation. Tests can wire it to count writes.
  final void Function()? onMemoryWritten;

  /// When true, [run] throws before producing a result. Test-only.
  final bool failOnRun;

  /// When true, [commit] throws on the [MemoryStore.save] step.
  /// Wraps the store in a failing decorator. Test-only.
  final bool failOnSave;

  /// When true, [commit] throws on the state-delta step *after* the
  /// memory save succeeds, exercising the rollback path. Test-only.
  final bool failOnApply;

  /// When true, [run] throws [AiUpdateRejected] before any other
  /// work, simulating a relevance-classifier rejection. Test-only
  /// (Pass 4.4 / #112). Must fire before [failOnRun] so test
  /// injection precedence is relevance → run → save → apply.
  final bool failOnRelevanceCheck;

  /// Test-only delay before [run] returns. Used by widget tests in
  /// #081 to exercise the modal's loading view + Cancel affordance
  /// without booting Gemini. Production never sets this; the Mock's
  /// run is otherwise instantaneous.
  ///
  /// While the delay is in flight, the run races against the
  /// supplied `cancelToken` (if any) and throws [AiUpdateCancelled]
  /// if cancellation wins.
  final Duration? slowRunDuration;

  static const _uuid = Uuid();

  @override
  Future<AiUpdateResult> run({
    required Connection contact,
    required String userInput,
    required MemoryDocument currentMemory,
    required List<AttachmentRef> attachments,
    Future<void>? cancelToken,
    Future<void> Function()? onClassifierPassed,
  }) async {
    if (failOnRelevanceCheck) {
      throw const AiUpdateRejected(reason: 'test-injected relevance rejection');
    }
    if (failOnRun) {
      throw const AiUpdateFailure('test-injected run failure');
    }
    final delay = slowRunDuration;
    if (delay != null) {
      // Race the delay against the cancel token. If the token
      // completes first, throw [AiUpdateCancelled] and short-
      // circuit before producing a result — mirrors the
      // [LlmAiUpdate] cancel contract from #080. Production never
      // sets `slowRunDuration`, so production cancel is a no-op
      // (the run finishes faster than any user can tap Cancel).
      //
      // We use a cancellable Timer here rather than
      // [Future.any]/[Future.delayed] so the pending timer is torn
      // down when cancel wins; otherwise widget tests under
      // fake_async report "a Timer is still pending" after the
      // widget tree disposes.
      final completer = Completer<void>();
      final timer = Timer(delay, () {
        if (!completer.isCompleted) completer.complete();
      });
      final tokenSub = cancelToken?.then((_) {
        if (!completer.isCompleted) {
          timer.cancel();
          completer.completeError(const AiUpdateCancelled());
        }
      });
      // Fire onClassifierPassed after a short delay to simulate
      // the classifier passing, so widget tests can verify the
      // loading label transition (Pass 4.4 / #113).
      final callbackDelay = const Duration(milliseconds: 50);
      Timer(callbackDelay, () {
        onClassifierPassed?.call();
      });
      try {
        await completer.future;
      } finally {
        timer.cancel();
        // Detach the token-listener Future from any further effect
        // on this completer; the local completer is already settled
        // and the next run allocates a fresh one.
        tokenSub?.ignore();
      }
    }
    final type = _categorize(userInput);
    final title = _titleFor(type);
    final now = DateTime.now();

    final interaction = CrmInteraction(
      id: _uuid.v4(),
      contactId: contact.id,
      type: type,
      title: title,
      note: userInput.isEmpty
          ? 'AI reviewed ${attachments.length} attachment(s).'
          : userInput,
      date: now,
      attachments: attachments,
      // Marked at construction time, not post-hoc — that distinction
      // is what unifies the seam shape (PRD Q1).
      source: InteractionSource.aiSuggested,
    );

    final bulletBody = userInput.isEmpty
        ? 'AI reviewed ${attachments.length} attachment(s).'
        : userInput;
    final bullet = '- ${_isoDate(now)} — ${_truncate(bulletBody, 500)}';
    final newHistory = currentMemory.history.isEmpty
        ? bullet
        : '${currentMemory.history}\n$bullet';

    // Extract topics from the user input and merge into the existing
    // memory.topics list. Dedup is case-insensitive (existing entry
    // wins so original case is preserved); cap is 8 with oldest-first
    // eviction (PRD Q6). Cap is enforced both here — so the preview
    // shows the post-cap candidate — and in `MemoryDocument.render()`.
    final extracted = _extractTopics(userInput);
    final mergedTopics = _mergeTopics(currentMemory.topics, extracted);
    final plannedEvents = _extractPlannedEvents(
      userInput: userInput,
      contact: contact,
      now: now,
    );

    final newMemory = currentMemory.copyWith(
      history: newHistory,
      topics: mergedTopics,
      lastUpdated: now,
    );

    return AiUpdateResult(
      summary:
          'Mock AI sorted this into ${type.label} and updated connection history.',
      contactId: contact.id,
      interactions: [interaction],
      nextStep: type == InteractionType.reminder ? 'Follow up this week' : null,
      memoryDocument: newMemory,
      plannedEvents: plannedEvents,
      // Pass 4.3 PRD §Q6 addendum / #085: parity with LlmAiUpdate.
      // Mock pretends the LLM judged interactionDepth=50 (a
      // "substantive" middle-of-the-rubric value) and applies the
      // same curve as production. Real LLM output varies; the
      // fixed depth keeps Mock-driven tests deterministic while
      // still exercising the wiring end-to-end.
      bondScoreDelta: applyBondScoreCurve(
        depth: 50,
        currentBond: contact.bondScore,
      ),
    );
  }

  @override
  Future<void> commit(AiUpdateResult result) async {
    final memory = result.memoryDocument;

    // Capture the pre-run memory so the state-delta-failure path can
    // restore the file. Loaded by contactId rather than passed in so
    // the [AiUpdate] interface stays narrow — callers do not have to
    // hand commit() the prior memory document.
    final priorMemory = memory == null
        ? null
        : await memoryStore.load(memory.contactId);

    // 1. Persist the memory. If save throws, the in-memory state
    //    delta is never applied — nothing has changed for the user.
    if (memory != null) {
      if (failOnSave) {
        throw const AiUpdateFailure('test-injected save failure');
      }
      await memoryStore.save(memory);
      // Signal "memory changed" to subscribers (e.g.
      // `recommendationsProvider`) before the state delta lands so
      // the next read sees a fresh epoch. The rollback path below
      // does not unsignal this — a transient bump on a rolled-back
      // commit is harmless: it just causes one extra recompute that
      // produces the same output as the pre-run cache.
      onMemoryWritten?.call();
    }

    // 2. Apply the AppState delta. If this throws after step 1
    //    succeeded, the file rename has already committed but the
    //    in-memory state has not — roll the file back so neither side
    //    observes the failed run. This is the all-or-nothing rollback
    //    PRD Q4 specifies (#046).
    try {
      if (failOnApply) {
        throw const AiUpdateFailure('test-injected apply failure');
      }
      await appController.applyAiUpdateResult(result);
    } catch (e) {
      if (memory != null) {
        try {
          if (priorMemory != null) {
            await memoryStore.save(priorMemory);
          } else {
            await memoryStore.delete(memory.contactId);
          }
        } catch (_) {
          // Best-effort rollback. The original failure is what the
          // caller cares about; surfacing a rollback error would mask
          // it.
        }
      }
      rethrow;
    }
  }

  // -- private helpers ------------------------------------------------

  static InteractionType _categorize(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('birthday') || lower.contains('family')) {
      return InteractionType.personalDetail;
    }
    if (lower.contains('coffee') ||
        lower.contains('dinner') ||
        lower.contains('met')) {
      return InteractionType.sharedActivity;
    }
    if (lower.contains('follow') ||
        lower.contains('remind') ||
        lower.contains('next')) {
      return InteractionType.reminder;
    }
    if (lower.contains('likes') ||
        lower.contains('prefers') ||
        lower.contains('favorite')) {
      return InteractionType.preference;
    }
    return InteractionType.interaction;
  }

  static String _titleFor(InteractionType type) => switch (type) {
    InteractionType.personalDetail => 'Personal context captured',
    InteractionType.sharedActivity => 'Shared activity logged',
    InteractionType.reminder => 'Follow-up reminder created',
    InteractionType.preference => 'Preference added',
    InteractionType.relationshipNote => 'Relationship note added',
    InteractionType.interaction => 'Interaction summarized',
  };

  static String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic extractor (PRD Q7).
//
// Hand-curated keyword list across family, career, location, health,
// hobbies, and milestones. Substring matching against the
// lowercased user input. Determinism: results follow keyword-list
// order (not input order), so the same input always produces the
// same extracted topics in the same sequence — the property the
// PRD calls out explicitly.
//
// Templated suggestion fallback for memory-extracted topics with no
// curated entry lands in #044, not here.
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _topicKeywords = <String>[
  // family
  'kindergarten', 'wedding', 'engaged', 'pregnant', 'baby', 'married',
  'divorced', 'parent', 'mom', 'dad',
  // career
  'promotion', 'startup', 'interview', 'fired', 'quit', 'hired', 'raise',
  'job', 'project',
  // location
  'moved', 'travel', 'vacation', 'relocated', 'trip',
  // health
  'surgery', 'sick', 'hospital', 'recovering', 'doctor',
  // hobbies
  'marathon', 'gym', 'learning', 'reading', 'concert', 'art', 'music',
  // milestones
  'birthday', 'anniversary', 'graduated', 'bought', 'house',
];

/// Returns the keywords from [_topicKeywords] that appear as substrings
/// of [userInput] (case-insensitive). Output preserves keyword-list
/// order, so callers get a deterministic sequence regardless of where
/// the keyword appears in the input.
List<String> _extractTopics(String userInput) {
  if (userInput.isEmpty) return const [];
  final haystack = userInput.toLowerCase();
  final found = <String>[];
  for (final keyword in _topicKeywords) {
    if (haystack.contains(keyword)) found.add(keyword);
  }
  return found;
}

/// Merges [extracted] into [existing] with case-insensitive dedup
/// (existing entry wins so the on-disk case is preserved), then caps
/// at [MemoryDocument.topicCap] with oldest-first eviction.
///
/// Note: this is dedup-on-merge; render also dedupes/caps. The two
/// rules agree on the final state, but merging here keeps the preview
/// candidate already capped — callers do not have to round-trip
/// through render to see the persisted shape.
List<String> _mergeTopics(List<String> existing, List<String> extracted) {
  final seen = <String>{for (final t in existing) t.toLowerCase()};
  final out = <String>[...existing];
  for (final topic in extracted) {
    final key = topic.toLowerCase();
    if (seen.add(key)) out.add(topic);
  }
  if (out.length <= MemoryDocument.topicCap) return out;
  // Oldest-first eviction: drop from the head until we hit the cap.
  return out.sublist(out.length - MemoryDocument.topicCap);
}

List<PlannerEvent> _extractPlannedEvents({
  required String userInput,
  required Connection contact,
  required DateTime now,
}) {
  if (userInput.trim().isEmpty) return const <PlannerEvent>[];
  final date = _extractDayMonth(userInput, now: now);
  if (date == null) return const <PlannerEvent>[];
  final title = _extractTripTitle(userInput) ?? 'Planned Event';
  return <PlannerEvent>[
    PlannerEvent(
      id: MockAiUpdate._uuid.v4(),
      title: title,
      contactId: contact.id,
      category: contact.category,
      date: date,
      note: 'Created from AI Update: ${_truncateText(userInput, 240)}',
      eventType: 'Plan',
    ),
  ];
}

DateTime? _extractDayMonth(String input, {required DateTime now}) {
  const months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  final dayMonth = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)\b',
    caseSensitive: false,
  ).firstMatch(input);
  final monthDay = RegExp(
    r'\b([A-Za-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?\b',
    caseSensitive: false,
  ).firstMatch(input);
  final match = dayMonth ?? monthDay;
  if (match == null) return null;

  final dayRaw = dayMonth != null ? match.group(1)! : match.group(2)!;
  final monthRaw = dayMonth != null ? match.group(2)! : match.group(1)!;
  final month = months[monthRaw.toLowerCase()];
  if (month == null) return null;
  final day = int.tryParse(dayRaw);
  if (day == null || day < 1 || day > 31) return null;
  return DateTime(now.year, month, day);
}

String? _extractTripTitle(String input) {
  final explicitTrip = RegExp(
    r'\b([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){0,2})\s+trip\b',
  ).firstMatch(input);
  final toPlace = RegExp(
    r'\b(?:go(?:ing)?|travel(?:ing|ling)?|fly(?:ing)?|head(?:ing)?)\s+to\s+([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){0,2})',
  ).firstMatch(input);
  final place = explicitTrip?.group(1) ?? toPlace?.group(1);
  if (place == null || place.trim().isEmpty) return null;
  return '${place.trim()} Trip';
}

String _truncateText(String value, int max) {
  if (value.length <= max) return value;
  return '${value.substring(0, max)}...';
}
