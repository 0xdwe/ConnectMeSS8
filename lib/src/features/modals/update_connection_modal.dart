import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

Future<void> showUpdateConnectionModal(BuildContext context, Connection connection) {
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => UpdateConnectionModal(connection: connection));
}

class UpdateConnectionModal extends ConsumerStatefulWidget {
  const UpdateConnectionModal({super.key, required this.connection});
  final Connection connection;

  @override
  ConsumerState<UpdateConnectionModal> createState() => _UpdateConnectionModalState();
}

class _UpdateConnectionModalState extends ConsumerState<UpdateConnectionModal> {
  InteractionType type = InteractionType.interaction;
  final title = TextEditingController();
  final note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.space5,
        right: AppSpacing.space5,
        top: AppSpacing.space4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space5,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Update ${widget.connection.name}', style: AppTypography.h1()),
        SizedBox(height: AppSpacing.space2),
        DropdownButtonFormField<InteractionType>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Basket'),
          items: InteractionType.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
          onChanged: (value) => setState(() => type = value ?? type),
        ),
        SizedBox(height: AppSpacing.space2),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
        SizedBox(height: AppSpacing.space2),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note'), minLines: 2, maxLines: 5),
        SizedBox(height: AppSpacing.space4),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(appControllerProvider.notifier).logInteraction(
                    widget.connection.id,
                    type,
                    title.text.trim().isEmpty ? type.label : title.text.trim(),
                    note.text.trim().isEmpty ? 'Manual update logged.' : note.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not log update. Try again.')),
                );
              }
            }
          },
          child: const Text('Log update'),
        ),
      ]),
    );
  }
}
