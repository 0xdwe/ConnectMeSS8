import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';

enum AiUpdateState { inputting, generating, previewing, saving }

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
  AiUpdateState currentState = AiUpdateState.inputting;
  AiUpdateResult? previewResult;
  List<TextEditingController> titleControllers = [];
  List<TextEditingController> noteControllers = [];

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
    setState(() => currentState = AiUpdateState.generating);
    try {
      final result = await ref.read(appControllerProvider.notifier).previewAiUpdate(
        widget.contactId,
        input.text.trim(),
        attachments,
      );
      
      // Initialize controllers for editable fields
      titleControllers = result.interactions
          .map((i) => TextEditingController(text: i.title))
          .toList();
      noteControllers = result.interactions
          .map((i) => TextEditingController(text: i.note))
          .toList();
      
      setState(() {
        previewResult = result;
        currentState = AiUpdateState.previewing;
      });
    } catch (e) {
      setState(() => currentState = AiUpdateState.inputting);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void cancel() {
    setState(() {
      currentState = AiUpdateState.inputting;
      previewResult = null;
      for (final controller in titleControllers) {
        controller.dispose();
      }
      for (final controller in noteControllers) {
        controller.dispose();
      }
      titleControllers.clear();
      noteControllers.clear();
    });
  }

  Future<void> save() async {
    if (previewResult == null) return;
    
    setState(() => currentState = AiUpdateState.saving);
    
    // Build edited result with user changes
    final editedInteractions = <CrmInteraction>[];
    for (int i = 0; i < previewResult!.interactions.length; i++) {
      final original = previewResult!.interactions[i];
      editedInteractions.add(
        original.copyWith(
          title: titleControllers[i].text.trim(),
          note: noteControllers[i].text.trim(),
        ),
      );
    }
    
    final editedResult = AiUpdateResult(
      summary: previewResult!.summary,
      contactId: previewResult!.contactId,
      interactions: editedInteractions,
      nextStep: previewResult!.nextStep,
    );
    
    ref.read(appControllerProvider.notifier).commitAiUpdate(editedResult);
    
    if (mounted) {
      final person = ref.read(appControllerProvider).connections.firstWhere(
        (c) => c.id == widget.contactId,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ${editedInteractions.length} update${editedInteractions.length == 1 ? '' : 's'} with ${person.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // TODO: Implement undo by removing the saved interactions
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    input.dispose();
    for (final controller in titleControllers) {
      controller.dispose();
    }
    for (final controller in noteControllers) {
      controller.dispose();
    }
    super.dispose();
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
      body: currentState == AiUpdateState.previewing
          ? _buildPreviewView(tokens, person)
          : _buildInputView(tokens, person),
    );
  }

  Widget _buildInputView(AppTokens tokens, Connection person) {
    return ListView(padding: const EdgeInsets.all(26), children: [
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
        FilledButton.icon(
          key: const Key('run-ai-button'),
          onPressed: currentState == AiUpdateState.generating ? null : submit,
          icon: const Icon(Icons.auto_awesome),
          label: Text(currentState == AiUpdateState.generating ? 'Generating...' : 'Update Connection'),
        ),
      ])),
    ]);
  }

  Widget _buildPreviewView(AppTokens tokens, Connection person) {
    if (previewResult == null) return const SizedBox.shrink();
    
    return ListView(padding: const EdgeInsets.all(26), children: [
      Text('Here\'s what I found', style: AppTypography.h2()),
      const SizedBox(height: 16),
      for (int i = 0; i < previewResult!.interactions.length; i++)
        _buildPreviewCard(tokens, person, i),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const Key('save-button'),
              onPressed: currentState == AiUpdateState.saving ? null : save,
              child: Text('Save these (${previewResult!.interactions.length})'),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            key: const Key('cancel-button'),
            onPressed: currentState == AiUpdateState.saving ? null : cancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    ]);
  }

  Widget _buildPreviewCard(AppTokens tokens, Connection person, int index) {
    final interaction = previewResult!.interactions[index];
    
    return CardBox(
      key: Key('preview-card-$index'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact match row
          Row(
            children: [
              Text(person.avatar, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(person.name, style: AppTypography.bodyLg()),
              ),
              // AI suggested tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: tokens.primary),
                    const SizedBox(width: 4),
                    Text(
                      'AI suggested',
                      style: AppTypography.caption(color: tokens.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Type chip
          Chip(
            avatar: Icon(interaction.type.icon, size: 16),
            label: Text(interaction.type.label),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(height: 12),
          // Editable title
          TextField(
            key: Key('preview-title-$index'),
            controller: titleControllers[index],
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Editable note
          TextField(
            key: Key('preview-note-$index'),
            controller: noteControllers[index],
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 6,
          ),
          const SizedBox(height: 12),
          // Date row
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: tokens.inkMuted),
              const SizedBox(width: 8),
              Text(
                DateFormat.yMMMd().format(interaction.date),
                style: AppTypography.caption(color: tokens.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
