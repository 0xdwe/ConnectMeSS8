import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

Future<void> showAddEventModal(BuildContext context, {DateTime? initialDate}) => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => AddEventModal(initialDate: initialDate));

class AddEventModal extends ConsumerStatefulWidget {
  const AddEventModal({super.key, this.initialDate});
  final DateTime? initialDate;

  @override
  ConsumerState<AddEventModal> createState() => _AddEventModalState();
}

class _AddEventModalState extends ConsumerState<AddEventModal> {
  final title = TextEditingController();
  final note = TextEditingController();
  late DateTime date = widget.initialDate ?? DateTime.now();
  String? contactId;
  String? category;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    contactId ??= state.connections.first.id;
    category ??= state.categories.first;
    return Padding(
      padding: EdgeInsets.only(left: 22, right: 22, top: 22, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Create Event', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: contactId, decoration: const InputDecoration(labelText: 'Connection'), items: state.connections.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => setState(() => contactId = v)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: state.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => category = v)),
        const SizedBox(height: 10),
        ListTile(contentPadding: EdgeInsets.zero, title: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'), trailing: const Icon(Icons.calendar_today), onTap: () async { final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2035)); if (picked != null) setState(() => date = picked); }),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
        const SizedBox(height: 16),
        FilledButton(onPressed: () { ref.read(appControllerProvider.notifier).addEvent(title.text.trim().isEmpty ? 'New Event' : title.text.trim(), contactId!, category!, date, note.text.trim()); Navigator.pop(context); }, child: const Text('Save Event')),
      ]),
    );
  }
}
