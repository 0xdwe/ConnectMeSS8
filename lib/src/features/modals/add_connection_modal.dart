import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

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
      padding: EdgeInsets.only(left: 22, right: 22, top: 22, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add Connection', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(key: const Key('add-name-field'), controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(key: const Key('add-email-field'), controller: email, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: state.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (value) => setState(() => category = value)),
        const SizedBox(height: 10),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'First connection starter'), minLines: 2, maxLines: 4),
        const SizedBox(height: 18),
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
