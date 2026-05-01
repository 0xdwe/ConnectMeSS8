import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

Future<void> showManageCategoriesModal(BuildContext context) {
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const ManageCategoriesModal());
}

class ManageCategoriesModal extends ConsumerStatefulWidget {
  const ManageCategoriesModal({super.key});

  @override
  ConsumerState<ManageCategoriesModal> createState() => _ManageCategoriesModalState();
}

class _ManageCategoriesModalState extends ConsumerState<ManageCategoriesModal> {
  final category = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(appControllerProvider.select((state) => state.categories));
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Manage categories', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        Wrap(spacing: 8, children: categories.map((item) => Chip(label: Text(item))).toList()),
        const SizedBox(height: 10),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'New category')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            ref.read(appControllerProvider.notifier).addCategory(category.text);
            category.clear();
          },
          child: const Text('Add category'),
        ),
      ]),
    );
  }
}
