import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
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
      padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Update ${widget.connection.name}', style: AppTypography.h1()),
        const SizedBox(height: 10),
        DropdownButtonFormField<InteractionType>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Basket'),
          items: InteractionType.values.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(),
          onChanged: (value) => setState(() => type = value ?? type),
        ),
        const SizedBox(height: 10),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 10),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note'), minLines: 2, maxLines: 5),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            ref.read(appControllerProvider.notifier).logInteraction(
                  widget.connection.id,
                  type,
                  title.text.trim().isEmpty ? type.label : title.text.trim(),
                  note.text.trim().isEmpty ? 'Manual update logged.' : note.text.trim(),
                );
            Navigator.pop(context);
          },
          child: const Text('Log update'),
        ),
      ]),
    );
  }
}
