import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../widgets/crm_widgets.dart';

class AiUpdateScreen extends ConsumerStatefulWidget {
  const AiUpdateScreen({super.key, required this.contactId});
  final String contactId;

  @override
  ConsumerState<AiUpdateScreen> createState() => _AiUpdateScreenState();
}

class _AiUpdateScreenState extends ConsumerState<AiUpdateScreen> {
  final input = TextEditingController();
  final attachments = <AttachmentRef>[];
  bool loading = false;

  Future<void> pick() async {
    final result = await openFiles();
    if (result.isEmpty) return;
    setState(() => attachments.addAll(result.map((f) => AttachmentRef(name: f.name, path: f.path))));
  }

  Future<void> submit() async {
    setState(() => loading = true);
    await ref.read(appControllerProvider.notifier).runAiUpdate(widget.contactId, input.text.trim(), attachments);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(appControllerProvider).connections.firstWhere((c) => c.id == widget.contactId);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      body: Column(children: [
        TealPageHeader(title: 'AI Update', subtitle: 'Update ${person.name}', backLabel: 'Back'),
        Expanded(child: ListView(padding: const EdgeInsets.all(26), children: [
          CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tell AI anything', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Text, images, files. Mock AI categorizes info into correct basket and updates history/dashboard.', style: TextStyle(fontSize: 18, color: Colors.black54)),
            const SizedBox(height: 16),
            TextField(key: const Key('ai-input-field'), controller: input, minLines: 4, maxLines: 12, decoration: const InputDecoration(hintText: 'Example: Sam said today is first day at job. Ask how it went tomorrow.')),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [ActionChip(avatar: const Icon(Icons.attach_file), label: const Text('Attach'), onPressed: pick), for (final file in attachments) Chip(label: Text(file.name))]),
            const SizedBox(height: 20),
            FilledButton.icon(key: const Key('run-ai-button'), onPressed: loading ? null : submit, icon: const Icon(Icons.auto_awesome), label: const Text('Update Connection')),
          ])),
        ])),
      ]),
    );
  }
}
