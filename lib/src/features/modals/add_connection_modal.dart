import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

Future<void> showAddConnectionModal(BuildContext context) => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const AddConnectionModal());

class AddConnectionModal extends ConsumerStatefulWidget {
  const AddConnectionModal({super.key});

  @override
  ConsumerState<AddConnectionModal> createState() => _AddConnectionModalState();
}

class _AddConnectionModalState extends ConsumerState<AddConnectionModal> {
  final name = TextEditingController();
  final email = TextEditingController();
  final notes = TextEditingController();
  String? category;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    category ??= state.categories.first;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.space5,
        right: AppSpacing.space5,
        top: AppSpacing.space5,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space5,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add Connection', style: AppTypography.h1()),
        SizedBox(height: AppSpacing.space3),
        TextField(key: const Key('add-name-field'), controller: name, decoration: const InputDecoration(labelText: 'Name')),
        SizedBox(height: AppSpacing.space2),
        TextField(key: const Key('add-email-field'), controller: email, decoration: const InputDecoration(labelText: 'Email')),
        SizedBox(height: AppSpacing.space2),
        DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: state.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (value) => setState(() => category = value)),
        SizedBox(height: AppSpacing.space2),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'First connection starter'), minLines: 2, maxLines: 4),
        SizedBox(height: AppSpacing.space4),
        FilledButton(
          key: const Key('save-connection-button'),
          onPressed: () {
            ref.read(appControllerProvider.notifier).addConnection(name: name.text.trim().isEmpty ? 'New Connection' : name.text.trim(), email: email.text.trim().isEmpty ? 'new@email.com' : email.text.trim(), category: category!, notes: notes.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Save Connection'),
        ),
      ]),
    );
  }
}
