import '../models/social_models.dart';
import '../state/memory/memory_document.dart';
import 'memory_rebuilder.dart';

/// Deterministic [MemoryRebuilder] for tests (#124).
///
/// Returns a [MemoryRebuildResult] with:
/// - A memory document whose summary mentions the contact name and
///   excludes the deleted interaction title.
/// - A next step of "Check in with {contact name}".
class FakeMemoryRebuilder implements MemoryRebuilder {
  int rebuildCallCount = 0;
  MemoryRebuildResult? nextResult;

  @override
  Future<MemoryRebuildResult> rebuild({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> remainingInteractions,
    required CrmInteraction deletedInteraction,
  }) async {
    rebuildCallCount++;
    if (nextResult != null) return nextResult!;

    return MemoryRebuildResult(
      memoryDocument: currentMemory.copyWith(
        summary:
            'Rebuilt memory for ${contact.name} without "${deletedInteraction.title}".',
        history:
            'Updated history after removing "${deletedInteraction.title}".',
      ),
      nextStep: 'Check in with ${contact.name}',
    );
  }
}
