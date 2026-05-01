import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';

Future<void> showEditConnectionModal(BuildContext context, Connection connection) => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => EditConnectionModal(connection: connection));

class EditConnectionModal extends ConsumerStatefulWidget {
  const EditConnectionModal({super.key, required this.connection});
  final Connection connection;

  @override
  ConsumerState<EditConnectionModal> createState() => _EditConnectionModalState();
}

class _EditConnectionModalState extends ConsumerState<EditConnectionModal> {
  late final name = TextEditingController(text: widget.connection.name);
  late final email = TextEditingController(text: widget.connection.email);
  late final notes = TextEditingController(text: widget.connection.notes);
  late String category = widget.connection.category;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(appControllerProvider).categories;
    return Padding(
      padding: EdgeInsets.only(left: 22, right: 22, top: 22, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Edit Connection', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => category = v ?? category)),
        const SizedBox(height: 10),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Starter detail')),
        const SizedBox(height: 16),
        FilledButton(onPressed: () { ref.read(appControllerProvider.notifier).updateConnection(widget.connection.copyWith(name: name.text, email: email.text, category: category, notes: notes.text)); Navigator.pop(context); }, child: const Text('Save')),
      ]),
    );
  }
}
