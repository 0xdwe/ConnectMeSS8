import 'package:uuid/uuid.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../state/memory/memory_document.dart';
import '../state/memory/memory_store.dart';

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
class MockAiUpdate implements AiUpdate {
  MockAiUpdate({
    required this.memoryStore,
    required this.appController,
  });

  final MemoryStore memoryStore;
  final AppController appController;

  static const _uuid = Uuid();

  @override
  Future<AiUpdateResult> run({
    required Connection contact,
    required String userInput,
    required MemoryDocument currentMemory,
    required List<AttachmentRef> attachments,
  }) async {
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
    final newMemory = currentMemory.copyWith(
      history: newHistory,
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
    // 1. Persist the memory first. If save throws, the in-memory state
    //    delta is never applied. The engine-level all-or-nothing
    //    rollback is hardened in #046.
    final memory = result.memoryDocument;
    if (memory != null) {
      await memoryStore.save(memory);
    }
    // 2. Apply the AppState delta: append interactions, bump bond,
    //    update lastContact, set lastAiSummary. Same logic the old
    //    AppController.commitAiUpdate had.
    appController.applyAiUpdateResult(result);
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
