import '../models/social_models.dart';
import '../state/memory/memory_document.dart';
import 'memory_rebuilder.dart';

/// Production [MemoryRebuilder] adapter backed by Gemini (#124).
///
/// Uses Firebase AI Logic to regenerate a contact's memory document
/// after an interaction is deleted, removing references to the deleted
/// interaction and regenerating summary, history, preferences, topics,
/// upcoming, and topic-scoped suggestions from the remaining
/// interactions.
///
/// **Stub:** Full LLM prompt implementation is deferred. Calling
/// [rebuild] throws [UnimplementedError]. The seam exists so the
/// [memoryRebuilderProvider] wiring and
/// [AppController.deleteInteraction] integration can be tested with
/// [FakeMemoryRebuilder].
class LlmMemoryRebuilder implements MemoryRebuilder {
  const LlmMemoryRebuilder();

  @override
  Future<MemoryRebuildResult> rebuild({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> remainingInteractions,
    required CrmInteraction deletedInteraction,
  }) {
    throw UnimplementedError(
      'LlmMemoryRebuilder not yet implemented',
    );
  }
}
