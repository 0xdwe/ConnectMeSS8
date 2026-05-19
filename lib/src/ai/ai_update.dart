import 'package:uuid/uuid.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../state/memory/memory_document.dart';
import '../state/memory/memory_store.dart';

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
  Future<AiUpdateResult> run({
    required Connection contact,
    required String userInput,
    required MemoryDocument currentMemory,
    required List<AttachmentRef> attachments,
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
    this.failOnRun = false,
    this.failOnSave = false,
    this.failOnApply = false,
  });

  final MemoryStore memoryStore;
  final AppController appController;

  /// When true, [run] throws before producing a result. Test-only.
  final bool failOnRun;

  /// When true, [commit] throws on the [MemoryStore.save] step.
  /// Wraps the store in a failing decorator. Test-only.
  final bool failOnSave;

  /// When true, [commit] throws on the state-delta step *after* the
  /// memory save succeeds, exercising the rollback path. Test-only.
  final bool failOnApply;

  static const _uuid = Uuid();

  @override
  Future<AiUpdateResult> run({
    required Connection contact,
    required String userInput,
    required MemoryDocument currentMemory,
    required List<AttachmentRef> attachments,
  }) async {
    if (failOnRun) {
      throw const AiUpdateFailure('test-injected run failure');
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
    final bullet = '- ${_isoDate(now)} — ${_truncate(bulletBody, 120)}';
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
      nextStep:
          type == InteractionType.reminder ? 'Follow up this week' : null,
      memoryDocument: newMemory,
    );
  }

  @override
  Future<void> commit(AiUpdateResult result) async {
    final memory = result.memoryDocument;

    // Capture the pre-run memory so the state-delta-failure path can
    // restore the file. Loaded by contactId rather than passed in so
    // the [AiUpdate] interface stays narrow — callers do not have to
    // hand commit() the prior memory document.
    final priorMemory =
        memory == null ? null : await memoryStore.load(memory.contactId);

    // 1. Persist the memory. If save throws, the in-memory state
    //    delta is never applied — nothing has changed for the user.
    if (memory != null) {
      if (failOnSave) {
        throw const AiUpdateFailure('test-injected save failure');
      }
      await memoryStore.save(memory);
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
      appController.applyAiUpdateResult(result);
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
