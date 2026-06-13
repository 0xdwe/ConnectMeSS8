import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'update_person_picker_modal.dart';

Future<void> showAiUpdateModal(BuildContext context) =>
    showUpdatePersonPickerModal(context);

class AiUpdateModal extends StatelessWidget {
  const AiUpdateModal({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('AI Update'),
    content: const Text('Choose a person first.'),
    actions: [
      TextButton(onPressed: () => context.pop(), child: const Text('OK')),
    ],
  );
}
