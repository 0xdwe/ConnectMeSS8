import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_tokens.dart';

Future<void> showManageEventTypesModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ManageEventTypesModal(),
  );
}

class ManageEventTypesModal extends ConsumerStatefulWidget {
  const ManageEventTypesModal({super.key});

  @override
  ConsumerState<ManageEventTypesModal> createState() =>
      _ManageEventTypesModalState();
}

class _ManageEventTypesModalState extends ConsumerState<ManageEventTypesModal> {
  final eventType = TextEditingController();
  final editValue = TextEditingController();
  String? editing;

  @override
  void dispose() {
    eventType.dispose();
    editValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final types = ref.watch(
      appControllerProvider.select((state) => state.eventTypes),
    );
    final controller = ref.read(appControllerProvider.notifier);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Manage Event Types',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.primaryTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.border),
              ),
              child: const Text(
                'Default event types cannot be deleted. Custom types can be edited or removed.',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: eventType,
                    decoration: const InputDecoration(
                      labelText: 'New event type',
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: () {
                    controller.addEventType(eventType.text);
                    eventType.clear();
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final type in types)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: editing == type
                    ? TextField(
                        controller: editValue,
                        decoration: const InputDecoration(
                          labelText: 'Event type name',
                        ),
                      )
                    : Text(type),
                trailing: editing == type
                    ? Wrap(
                        children: [
                          IconButton(
                            onPressed: () {
                              controller.renameEventType(type, editValue.text);
                              setState(() => editing = null);
                            },
                            icon: const Icon(Icons.check),
                          ),
                          IconButton(
                            onPressed: () => setState(() => editing = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      )
                    : Wrap(
                        children: [
                          if (AppController.defaultEventTypes.contains(type))
                            Padding(
                              padding: const EdgeInsets.only(top: 12, right: 8),
                              child: Text(
                                'Default',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: () {
                              editValue.text = type;
                              setState(() => editing = type);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed:
                                AppController.defaultEventTypes.contains(type)
                                ? null
                                : () => controller.deleteEventType(type),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
