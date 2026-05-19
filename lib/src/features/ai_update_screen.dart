import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../state/memory/memory_document.dart';
import '../state/memory/memory_providers.dart';
import '../state/query_providers.dart';
import '../theme/app_spacing.dart';
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

class _AiUpdateScreenState extends ConsumerState<AiUpdateScreen> with TickerProviderStateMixin {
  final input = TextEditingController();
  final attachments = <AttachmentRef>[];
  AiUpdateState currentState = AiUpdateState.inputting;
  AiUpdateResult? previewResult;
  // Pre-run memory captured at submit time so the preview view can
  // compute the memory delta against `previewResult.memoryDocument`
  // without depending on `MockAiUpdate`'s internal append shape.
  // Cleared alongside `previewResult` on cancel/save.
  MemoryDocument? priorMemory;
  List<TextEditingController> titleControllers = [];
  List<TextEditingController> noteControllers = [];
  // Animation controllers for the staggered preview entrance. There are
  // N controllers for N interaction cards plus one extra controller at
  // index N driving the "About <Name> ✨" memory delta card when one is
  // shown. Total length is therefore `interactions.length` or
  // `interactions.length + 1`.
  List<AnimationController> cardAnimationControllers = [];

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
      final connection = ref
          .read(appControllerProvider)
          .connections
          .firstWhere((c) => c.id == widget.contactId);
      final memory = await ref.read(memoryProvider(widget.contactId).future);
      final result = await ref.read(aiUpdateProvider).run(
            contact: connection,
            userInput: input.text.trim(),
            currentMemory: memory,
            attachments: attachments,
          );
      
      // Initialize controllers for editable fields
      titleControllers = result.interactions
          .map((i) => TextEditingController(text: i.title))
          .toList();
      noteControllers = result.interactions
          .map((i) => TextEditingController(text: i.note))
          .toList();
      
      // Compute whether a memory delta card will render so we know
      // whether to allocate the extra animation controller. The view
      // recomputes the delta itself; this is just for controller sizing.
      final hasDelta = _computeMemoryDelta(
            priorMemory: memory,
            result: result,
            contactDisplayName: connection.name,
          ) !=
          null;
      // Initialize animation controllers for stagger effect (one extra
      // slot at index N for the memory delta card when present).
      final disableAnimations = MediaQuery.of(context).disableAnimations;
      final controllerCount =
          result.interactions.length + (hasDelta ? 1 : 0);
      cardAnimationControllers = List.generate(
        controllerCount,
        (index) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 240),
        ),
      );
      
      setState(() {
        priorMemory = memory;
        previewResult = result;
        currentState = AiUpdateState.previewing;
      });
      
      // Start staggered animations
      if (!disableAnimations) {
        for (int i = 0; i < cardAnimationControllers.length; i++) {
          Future.delayed(Duration(milliseconds: 80 * i), () {
            if (mounted && cardAnimationControllers.length > i) {
              cardAnimationControllers[i].forward();
            }
          });
        }
      } else {
        // Skip animation if reduce motion is enabled
        for (final controller in cardAnimationControllers) {
          controller.value = 1.0;
        }
      }
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
      // Discard both the interaction preview AND the captured memory
      // delta — the all-or-nothing contract from PRD Q4 at the UI seam.
      previewResult = null;
      priorMemory = null;
      for (final controller in titleControllers) {
        controller.dispose();
      }
      for (final controller in noteControllers) {
        controller.dispose();
      }
      for (final controller in cardAnimationControllers) {
        controller.dispose();
      }
      titleControllers.clear();
      noteControllers.clear();
      cardAnimationControllers.clear();
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
      // Pass through the memory delta unchanged — the user only edits
      // interaction title/note in this slice; the memory append is
      // produced by `AiUpdate.run` and committed as-is.
      memoryDocument: previewResult!.memoryDocument,
    );

    await ref.read(aiUpdateProvider).commit(editedResult);
    // Drop the captured pre-run memory once committed; the next run
    // will recapture it from `memoryProvider`.
    priorMemory = null;
    
    if (mounted) {
      final person = ref.read(contactByIdProvider(widget.contactId));
      final count = editedInteractions.length;
      final plural = count == 1 ? '' : 's';
      final message = person == null
          ? 'Logged $count update$plural'
          : 'Logged $count update$plural with ${person.name}';
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
    for (final controller in cardAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final person = ref.watch(contactByIdProvider(widget.contactId));

    if (person == null) {
      return Scaffold(
        backgroundColor: tokens.surface,
        appBar: AppBar(
          title: Text('Contact Not Found', style: AppTypography.h2()),
          elevation: 0,
          backgroundColor: tokens.surface,
          foregroundColor: tokens.ink,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.space8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'This contact no longer exists.',
                  style: AppTypography.bodyLg(color: tokens.inkMuted),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.space4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
    return ListView(padding: EdgeInsets.all(AppSpacing.space6), children: [
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Update ${person.name}', style: AppTypography.h1()),
        SizedBox(height: AppSpacing.space2),
        Text('Tell AI anything', style: AppTypography.h2()),
        SizedBox(height: AppSpacing.space2),
        Text('Text, images, files. Mock AI categorizes info into correct basket and updates history/dashboard.', style: AppTypography.body(color: tokens.inkMuted)),
        SizedBox(height: AppSpacing.space4),
        TextField(key: const Key('ai-input-field'), controller: input, minLines: 4, maxLines: 12, decoration: const InputDecoration(hintText: 'Example: Sam said today is first day at job. Ask how it went tomorrow.')),
        SizedBox(height: AppSpacing.space3),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(avatar: const Icon(Icons.attach_file), label: const Text('Attach'), onPressed: pick),
          ActionChip(key: const Key('add-image-chip'), avatar: const Icon(Icons.image), label: const Text('Add image'), onPressed: pickImage),
          for (final file in attachments)
            if (_isImage(file.name))
              ClipRRect(
                key: Key('attachment-preview-${file.name}'),
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
        SizedBox(height: AppSpacing.space5),
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

    final delta = _computeMemoryDelta(
      priorMemory: priorMemory,
      result: previewResult!,
      contactDisplayName: person.name,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space6,
              AppSpacing.space6,
              AppSpacing.space6,
              AppSpacing.space5,
            ),
            children: [
              Text('Here\'s what I found', style: AppTypography.h2()),
              SizedBox(height: AppSpacing.space4),
              for (int i = 0; i < previewResult!.interactions.length; i++)
                _buildPreviewCard(tokens, person, i),
              // Memory delta card. Rendered as the final card in the
              // stagger sequence at controller index N (==
              // interactions.length). Suppressed entirely when there is
              // nothing new to show.
              if (delta != null)
                _buildMemoryDeltaCard(
                  tokens,
                  delta,
                  previewResult!.interactions.length,
                ),
            ],
          ),
        ),
        // Save/Cancel sits outside the scrollable area so it stays
        // visible regardless of how tall the preview body grows (the
        // delta card and any future additions can push the body height
        // beyond the viewport without burying the primary action).
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space6,
            0,
            AppSpacing.space6,
            AppSpacing.space6,
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('save-button'),
                  onPressed: currentState == AiUpdateState.saving ? null : save,
                  child: Text('Save these (${previewResult!.interactions.length})'),
                ),
              ),
              SizedBox(width: AppSpacing.space3),
              TextButton(
                key: const Key('cancel-button'),
                onPressed: currentState == AiUpdateState.saving ? null : cancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(AppTokens tokens, Connection person, int index) {
    final interaction = previewResult!.interactions[index];
    final animationController = cardAnimationControllers[index];
    
    // Create curved animation for smooth easing
    final animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutQuart,
    );
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: CardBox(
        key: Key('preview-card-$index'),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact match row
          Row(
            children: [
              Text(person.avatar, style: const TextStyle(fontSize: 32)),
              SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(person.name, style: AppTypography.bodyLg()),
              ),
              // AI suggested tag
              Container(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.space2, vertical: AppSpacing.space1),
                decoration: BoxDecoration(
                  color: tokens.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: tokens.primary),
                    SizedBox(width: AppSpacing.space1),
                    Text(
                      'AI suggested',
                      style: AppTypography.caption(color: tokens.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space3),
          // Type chip
          Chip(
            avatar: Icon(interaction.type.icon, size: 16),
            label: Text(interaction.type.label),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(height: AppSpacing.space3),
          // Editable title
          TextField(
            key: Key('preview-title-$index'),
            controller: titleControllers[index],
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: AppSpacing.space3),
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
          SizedBox(height: AppSpacing.space3),
          // Date row
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: tokens.inkMuted),
              SizedBox(width: AppSpacing.space2),
              Text(
                DateFormat.yMMMd().format(interaction.date),
                style: AppTypography.caption(color: tokens.inkMuted),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  /// Read-only "About `<Name>` ✨" delta card. Renders below the
  /// interaction cards and participates in the same stagger as the
  /// final entry (240ms ease-out-quart, 80ms offset). Per PRD Q5 the
  /// section uses `primary` on `primaryTint` for the ✨ tag and chips,
  /// never `secondary` or `tertiary` (which DESIGN.md forbids carrying
  /// text on light surfaces).
  Widget _buildMemoryDeltaCard(
    AppTokens tokens,
    _MemoryDelta delta,
    int controllerIndex,
  ) {
    final animationController = cardAnimationControllers[controllerIndex];
    final animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutQuart,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Semantics(
        header: true,
        label: 'About ${delta.contactDisplayName}, AI suggested',
        explicitChildNodes: true,
        child: CardBox(
          key: const Key('memory-delta-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: "About <Name>" + ✨ tag chip.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'About ${delta.contactDisplayName}',
                      style: AppTypography.h2(),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.primaryTint,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Semantics(
                      label: 'AI suggested',
                      child: Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: tokens.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (delta.newTopics.isNotEmpty) ...[
                SizedBox(height: AppSpacing.space3),
                Text(
                  'New topics',
                  style: AppTypography.caption(color: tokens.inkMuted),
                ),
                SizedBox(height: AppSpacing.space2),
                Wrap(
                  spacing: AppSpacing.space2,
                  runSpacing: AppSpacing.space2,
                  children: [
                    for (final topic in delta.newTopics)
                      _NewTopicChip(
                        key: Key('memory-delta-topic-$topic'),
                        topic: topic,
                        tokens: tokens,
                      ),
                  ],
                ),
              ],
              if (delta.appendedBullet.isNotEmpty) ...[
                SizedBox(height: AppSpacing.space3),
                Text(
                  'Adding to history: "${delta.appendedBullet}"',
                  style: AppTypography.caption(color: tokens.inkMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only value object describing what the AI run is about to
/// append to memory. Computed by [_computeMemoryDelta] from the pre-run
/// memory and the candidate result. `null` from the helper means there
/// is nothing new to show and the delta card should be suppressed.
class _MemoryDelta {
  const _MemoryDelta({
    required this.newTopics,
    required this.appendedBullet,
    required this.contactDisplayName,
  });

  /// Topics in the candidate that are not in the pre-run memory.
  /// Case-insensitive comparison; original case from the candidate is
  /// preserved for display.
  final List<String> newTopics;

  /// The new history bullet body (without the leading `- ` and without
  /// the `YYYY-MM-DD — ` date prefix). Empty string when no bullet was
  /// appended.
  final String appendedBullet;

  final String contactDisplayName;
}

/// Computes the [_MemoryDelta] for the preview view. Returns null when
/// there are no new topics and no appended history bullet — callers
/// suppress the card in that case (PRD Q5 empty-additions rule).
_MemoryDelta? _computeMemoryDelta({
  required MemoryDocument? priorMemory,
  required AiUpdateResult result,
  required String contactDisplayName,
}) {
  final candidate = result.memoryDocument;
  if (candidate == null) return null;

  // New topics: in candidate.topics but not in priorMemory.topics,
  // case-insensitive. When priorMemory is null (defensive fallback),
  // every candidate topic counts as new.
  final priorKeys = <String>{
    for (final t in priorMemory?.topics ?? const <String>[]) t.toLowerCase(),
  };
  final newTopics = <String>[
    for (final topic in candidate.topics)
      if (!priorKeys.contains(topic.toLowerCase())) topic,
  ];

  // Appended history bullet: the LAST non-empty `- ` line in
  // candidate.history that does NOT appear in priorMemory.history. The
  // simpler "last `- ` line" rule from the spec works for MockAiUpdate
  // (which always appends a single bullet to the end), and the
  // "not in priorMemory" guard keeps the section honest if the run
  // produced no append at all.
  final appendedBullet = _extractAppendedBullet(
    priorHistory: priorMemory?.history ?? '',
    candidateHistory: candidate.history,
  );

  if (newTopics.isEmpty && appendedBullet.isEmpty) return null;

  return _MemoryDelta(
    newTopics: newTopics,
    appendedBullet: appendedBullet,
    contactDisplayName: contactDisplayName,
  );
}

/// Extracts the last `- ` bullet from `candidateHistory` that is not
/// present in `priorHistory`, stripped of its leading `- ` and any
/// `YYYY-MM-DD — ` date prefix (the format `MockAiUpdate` writes).
/// Returns the empty string when no new bullet is found.
String _extractAppendedBullet({
  required String priorHistory,
  required String candidateHistory,
}) {
  if (candidateHistory.isEmpty) return '';
  final priorLines = priorHistory.split('\n').toSet();
  final candidateLines = candidateHistory.split('\n');
  for (int i = candidateLines.length - 1; i >= 0; i--) {
    final line = candidateLines[i];
    if (!line.startsWith('- ')) continue;
    if (priorLines.contains(line)) continue;
    final body = line.substring(2).trim();
    // Strip a leading `YYYY-MM-DD — ` (or `YYYY-MM-DD - `) date prefix.
    final dated = RegExp(r'^\d{4}-\d{2}-\d{2}\s*[—-]\s*').matchAsPrefix(body);
    if (dated != null) {
      return body.substring(dated.end).trim();
    }
    return body;
  }
  return '';
}

/// A small `primary-tint` chip with a leading `primary` accent dot,
/// announcing as "`<topic>`, newly added" for screen readers.
class _NewTopicChip extends StatelessWidget {
  const _NewTopicChip({
    super.key,
    required this.topic,
    required this.tokens,
  });

  final String topic;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$topic, newly added',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space1,
        ),
        decoration: BoxDecoration(
          color: tokens.primaryTint,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tokens.primary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: AppSpacing.space2),
            Text(
              topic,
              style: AppTypography.caption(color: tokens.ink),
            ),
          ],
        ),
      ),
    );
  }
}
