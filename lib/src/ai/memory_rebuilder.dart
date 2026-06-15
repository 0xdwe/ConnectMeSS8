import '../models/social_models.dart';
import '../state/memory/memory_document.dart';

/// Result of a memory rebuild operation (#124).
class MemoryRebuildResult {
  const MemoryRebuildResult({
    required this.memoryDocument,
    this.nextStep,
  });

  /// The rebuilt memory document with references to the deleted
  /// interaction removed and sections regenerated from remaining history.
  final MemoryDocument memoryDocument;

  /// Updated next-step suggestion derived from the rebuild.
  /// Null means no next step was produced; the caller should clear
  /// the existing next step.
  final String? nextStep;
}

/// Seam for rebuilding a contact's memory document after an interaction
/// is deleted (#124).
///
/// The rebuild removes references to the deleted interaction and
/// regenerates summary, history, preferences, topics, upcoming, and
/// topic-scoped suggestions from the remaining interactions and current
/// memory context.
///
/// Two adapters: [FakeMemoryRebuilder] for tests and [LlmMemoryRebuilder]
/// for production.
abstract interface class MemoryRebuilder {
  Future<MemoryRebuildResult> rebuild({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> remainingInteractions,
    required CrmInteraction deletedInteraction,
  });
}
