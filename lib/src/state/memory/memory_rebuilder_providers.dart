import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/llm_memory_rebuilder.dart';
import '../../ai/memory_rebuilder.dart';
import '../../models/social_models.dart';
import '../firebase_providers.dart';
import 'memory_document.dart';

/// Auth-aware [MemoryRebuilder] provider (#124).
///
/// Signed-in users get [LlmMemoryRebuilder]; signed-out users get a
/// sentinel that throws on rebuild.
///
/// Tests override this provider with [FakeMemoryRebuilder] directly.
final memoryRebuilderProvider = Provider<MemoryRebuilder>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
  if (user == null) return _SignedOutMemoryRebuilder();
  final firebaseAi = ref.watch(firebaseAiProvider);
  return LlmMemoryRebuilder(firebaseAi: firebaseAi);
});

/// Sentinel returned by [memoryRebuilderProvider] while signed out.
/// Every method throws [StateError] so a signed-out rebuild attempt
/// surfaces immediately.
class _SignedOutMemoryRebuilder implements MemoryRebuilder {
  @override
  Future<MemoryRebuildResult> rebuild({
    required Connection contact,
    required MemoryDocument currentMemory,
    required List<CrmInteraction> remainingInteractions,
    required CrmInteraction deletedInteraction,
  }) {
    throw StateError('Cannot rebuild memory while signed out');
  }
}
