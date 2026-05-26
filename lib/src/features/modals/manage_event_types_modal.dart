import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

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
        AppSpacing.space5,
        AppSpacing.space4,
        AppSpacing.space5,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.space5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Manage Event Types',
                    style: AppTypography.h1(),
                  ),
                ),
                IconButton(
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.space2),
            Container(
              padding: EdgeInsets.all(AppSpacing.space3),
              decoration: BoxDecoration(
                color: tokens.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: tokens.border),
              ),
              child: const Text(
                'Default event types cannot be deleted. Custom types can be edited or removed.',
              ),
            ),
            SizedBox(height: AppSpacing.space3),
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
                  onPressed: () async {
                    try {
                      await controller.addEventType(eventType.text);
                      eventType.clear();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not add event type. Try again.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.space3),
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
                            onPressed: () async {
                              try {
                                await controller.renameEventType(type, editValue.text);
                                if (context.mounted) {
                                  setState(() => editing = null);
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not rename event type. Try again.')),
                                  );
                                }
                              }
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
                              padding: EdgeInsets.only(top: AppSpacing.space3, right: AppSpacing.space2),
                              child: Text(
                                'Default',
                                style: AppTypography.caption(
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
                                : () async {
                                    try {
                                      await controller.deleteEventType(type);
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not delete event type. Try again.')),
                                        );
                                      }
                                    }
                                  },
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
