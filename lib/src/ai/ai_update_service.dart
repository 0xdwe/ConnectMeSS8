import 'package:uuid/uuid.dart';

import '../models/social_models.dart';

abstract class AiUpdateService {
  Future<AiUpdateResult> categorizeAndUpdate({
    required String input,
    required String fallbackContactId,
    required List<AttachmentRef> attachments,
  });
}

class MockAiUpdateService implements AiUpdateService {
  const MockAiUpdateService();

  static const _uuid = Uuid();

  @override
  Future<AiUpdateResult> categorizeAndUpdate({
    required String input,
    required String fallbackContactId,
    required List<AttachmentRef> attachments,
  }) async {
    final lower = input.toLowerCase();
    final type = lower.contains('birthday') || lower.contains('family')
        ? InteractionType.personalDetail
        : lower.contains('coffee') || lower.contains('dinner') || lower.contains('met')
            ? InteractionType.sharedActivity
            : lower.contains('follow') || lower.contains('remind') || lower.contains('next')
                ? InteractionType.reminder
                : lower.contains('likes') || lower.contains('prefers') || lower.contains('favorite')
                    ? InteractionType.preference
                    : InteractionType.interaction;
    final title = switch (type) {
      InteractionType.personalDetail => 'Personal context captured',
      InteractionType.sharedActivity => 'Shared activity logged',
      InteractionType.reminder => 'Follow-up reminder created',
      InteractionType.preference => 'Preference added',
      InteractionType.relationshipNote => 'Relationship note added',
      InteractionType.interaction => 'Interaction summarized',
    };
    final interaction = CrmInteraction(
      id: _uuid.v4(),
      contactId: fallbackContactId,
      type: type,
      title: title,
      note: input.isEmpty ? 'AI reviewed ${attachments.length} attachment(s).' : input,
      date: DateTime.now(),
      attachments: attachments,
    );
    return AiUpdateResult(
      summary: 'Mock AI sorted this into ${type.label} and updated connection history.',
      contactId: fallbackContactId,
      interactions: [interaction],
      nextStep: type == InteractionType.reminder ? 'Follow up this week' : null,
    );
  }
}
