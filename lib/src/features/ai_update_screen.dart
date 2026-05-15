import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';

class AiUpdateScreen extends ConsumerStatefulWidget {
  const AiUpdateScreen({super.key, required this.contactId, @visibleForTesting this.initialAttachments});
  final String contactId;
  final List<AttachmentRef>? initialAttachments;

  @override
  ConsumerState<AiUpdateScreen> createState() => _AiUpdateScreenState();
}

class _AiUpdateScreenState extends ConsumerState<AiUpdateScreen> {
  final input = TextEditingController();
  final attachments = <AttachmentRef>[];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAttachments != null) {
      attachments.addAll(widget.initialAttachments!);
    }
  }

  Future<void> pick() async {
    final result = await openFiles();
    if (result.isEmpty) return;
    setState(() => attachments.addAll(result.map((f) => AttachmentRef(name: f.name, path: f.path))));
  }

  Future<void> pickImage() async {
    const imageGroup = XTypeGroup(
      label: 'images',
      extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic'],
    );
    final result = await openFiles(acceptedTypeGroups: [imageGroup]);
    if (result.isEmpty) return;
    setState(() => attachments.addAll(result.map((f) => AttachmentRef(name: f.name, path: f.path))));
  }

  bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  Future<void> submit() async {
    setState(() => loading = true);
    await ref.read(appControllerProvider.notifier).runAiUpdate(widget.contactId, input.text.trim(), attachments);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final person = ref.watch(appControllerProvider).connections.firstWhere((c) => c.id == widget.contactId);
    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text('Update with AI', style: AppTypography.h2()),
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
      ),
      body: ListView(padding: const EdgeInsets.all(26), children: [
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Update ${person.name}', style: AppTypography.h1()),
          const SizedBox(height: 10),
          Text('Tell AI anything', style: AppTypography.h2()),
          const SizedBox(height: 8),
          Text('Text, images, files. Mock AI categorizes info into correct basket and updates history/dashboard.', style: AppTypography.body(color: tokens.inkMuted)),
          const SizedBox(height: 16),
          TextField(key: const Key('ai-input-field'), controller: input, minLines: 4, maxLines: 12, decoration: const InputDecoration(hintText: 'Example: Sam said today is first day at job. Ask how it went tomorrow.')),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(avatar: const Icon(Icons.attach_file), label: const Text('Attach'), onPressed: pick),
            ActionChip(key: const Key('add-image-chip'), avatar: const Icon(Icons.image), label: const Text('Add image'), onPressed: pickImage),
            for (final file in attachments)
              if (_isImage(file.name))
                ClipRRect(
                  key: Key('attachment-preview-${file.name}'),
                  borderRadius: BorderRadius.circular(8),
                  child: file.path != null
                      ? Image.file(
                          File(file.path!),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 64,
                            height: 64,
                            color: tokens.surfaceSunken,
                            child: Icon(Icons.image_outlined, color: tokens.inkSubtle),
                          ),
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: tokens.surfaceSunken,
                          child: Icon(Icons.image_outlined, color: tokens.inkSubtle),
                        ),
                )
              else
                Chip(label: Text(file.name)),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(key: const Key('run-ai-button'), onPressed: loading ? null : submit, icon: const Icon(Icons.auto_awesome), label: const Text('Update Connection')),
        ])),
      ]),
    );
  }
}
