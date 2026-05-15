import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

Future<void> showSharedActivityModal(
  BuildContext context, {
  String? initialContactId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SharedActivityModal(initialContactId: initialContactId),
  );
}

class SharedActivityModal extends ConsumerStatefulWidget {
  const SharedActivityModal({super.key, this.initialContactId});
  final String? initialContactId;

  @override
  ConsumerState<SharedActivityModal> createState() =>
      _SharedActivityModalState();
}

class _SharedActivityModalState extends ConsumerState<SharedActivityModal> {
  String? contactId;
  SharedActivityType type = SharedActivityType.note;
  final content = TextEditingController();

  @override
  void initState() {
    super.initState();
    contactId = widget.initialContactId;
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    contactId ??= state.connections.first.id;
    final hasContent = content.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Share Activity',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: contactId,
              decoration: const InputDecoration(labelText: 'Contact'),
              items: state.connections
                  .map(
                    (contact) => DropdownMenuItem(
                      value: contact.id,
                      child: Text(contact.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => contactId = value),
            ),
            const SizedBox(height: 14),
            SegmentedButton<SharedActivityType>(
              segments: const [
                ButtonSegment(
                  value: SharedActivityType.note,
                  icon: Icon(Icons.notes_outlined),
                  label: Text('Note'),
                ),
                ButtonSegment(
                  value: SharedActivityType.photo,
                  icon: Icon(Icons.image_outlined),
                  label: Text('Photo'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (value) => setState(() => type = value.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: content,
              minLines: type == SharedActivityType.note ? 4 : 1,
              maxLines: type == SharedActivityType.note ? 6 : 1,
              decoration: InputDecoration(
                labelText: type == SharedActivityType.note
                    ? 'Notes'
                    : 'Photo URL or path',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (hasContent) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7D6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Suggestion',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This shared moment shows strong connection. Plan a follow-up activity within the next week to maintain momentum.',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Navigator.of(context).pop,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.moss,
                    ),
                    onPressed: hasContent
                        ? () {
                            ref
                                .read(appControllerProvider.notifier)
                                .logSharedActivity(
                                  contactId: contactId!,
                                  type: type,
                                  content: content.text,
                                );
                            Navigator.pop(context);
                          }
                        : null,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share Activity'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
