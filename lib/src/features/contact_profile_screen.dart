import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../state/memory/memory_providers.dart';
import '../state/query_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/bond_ring.dart';
import '../widgets/crm_widgets.dart';
import 'modals/edit_connection_modal.dart';

class ContactProfileScreen extends ConsumerWidget {
  const ContactProfileScreen({
    super.key,
    required this.contactId,
    this.initialSelectedTopic,
  });
  final String contactId;
  final String? initialSelectedTopic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final person = ref.watch(contactByIdProvider(contactId));

    // Handle missing contact gracefully
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
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(appControllerProvider);
    final insight = state.contactInsightFor(contactId);
    final history = ref.watch(interactionsByContactProvider(contactId));
    final upcomingPlans = state.events.where((event) {
      if (event.contactId != person.id) return false;
      final eventDay = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);
      return !eventDay.isBefore(todayDay);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
    final lastContactLabel = _lastInteractionLabel(history);
    final memoryAsync = ref.watch(memoryProvider(contactId));
    final memory = memoryAsync.maybeWhen(
      data: (doc) => doc,
      orElse: () => null,
    );
    final memorySummary = (memory != null && memory.summary.trim().isNotEmpty)
        ? memory.summary
        : null;
    final statusLabel = _connectionStatusLabel(person.bondScore);
    final statusColor = _connectionStatusColor(tokens, person.bondScore);

    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text(person.name, style: AppTypography.h2()),
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
        actions: [
          IconButton(
            key: const Key('edit-connection-button'),
            tooltip: 'Edit',
            onPressed: () => showEditConnectionModal(context, person),
            icon: Icon(
              Icons.edit,
              size: 20,
              color: tokens.primary,
            ),
            splashRadius: 20,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      floatingActionButton: AiActionFab(
        key: const Key('update-with-ai-button'),
        onTap: () => context.push('/ai-update/${person.id}'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: AppSurface(
        child: ListView(
          // Reserve room at the bottom so the floating Update with AI
          // button (AiActionFab, ~72pt + safe area) does not obscure the
          // last History row. Reuses the existing pageBottomPadding token
          // already used by the home/people tabs for nav-bar clearance.
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space4,
            AppSpacing.space4,
            AppSpacing.space4,
            AppSpacing.pageBottomPadding,
          ),
          children: [
            // Header section: avatar, email, category, and bond details.
            Container(
              padding: EdgeInsets.all(AppSpacing.space5),
              decoration: BoxDecoration(
                gradient: tokens.cardGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: tokens.border),
                boxShadow: AppTokens.elevation1(dark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: tokens.surfaceRaised,
                        backgroundImage: _contactAvatarImage(person.avatar),
                        child: _contactAvatarImage(person.avatar) == null
                            ? Text(
                                _contactAvatarGlyph(person.avatar, person.name),
                                style: AppTypography.bodyLg(
                                  color: tokens.primary,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: AppSpacing.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Colors.white,
                                            Colors.transparent,
                                          ],
                                          stops: [0.0, 0.88, 1.0],
                                        ).createShader(bounds),
                                    blendMode: BlendMode.dstIn,
                                    child: Text(
                                      person.name,
                                      style: AppTypography.display(),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                    ),
                                  ),
                                ),
                                SizedBox(width: AppSpacing.space3),
                                SizedBox.shrink(),
                              ],
                            ),
                            SizedBox(height: AppSpacing.space2),
                            Text(
                              person.category,
                              style: AppTypography.caption(
                                color: tokens.inkMuted,
                              ),
                            ),
                            SizedBox(height: AppSpacing.space1),
                            Text(
                              person.email,
                              style: AppTypography.body(
                                color: tokens.inkSubtle,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.space5),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.space4,
                      AppSpacing.space4,
                      AppSpacing.space4,
                      AppSpacing.space4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connection Score',
                                style: AppTypography.caption(
                                  color: tokens.inkMuted,
                                ),
                              ),
                              SizedBox(height: AppSpacing.space1),
                              Wrap(
                                spacing: AppSpacing.space2,
                                runSpacing: AppSpacing.space1,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    person.bondScore.toString(),
                                    style: AppTypography.display(),
                                  ),
                                  Icon(
                                    person.bondTrendAt(DateTime.now()) ==
                                            BondTrend.up
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    color:
                                        person.bondTrendAt(DateTime.now()) ==
                                            BondTrend.up
                                        ? tokens.success
                                        : tokens.danger,
                                    size: 20,
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.space2,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: AppTypography.caption(
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.space4),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Last contact',
                              style: AppTypography.caption(
                                color: tokens.inkMuted,
                              ),
                            ),
                            SizedBox(height: AppSpacing.space2),
                            Text(
                              lastContactLabel,
                              style: AppTypography.h2(
                                color: history.isEmpty
                                    ? tokens.inkMuted
                                    : tokens.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.space4),
            // AI Insights collapsible card (Pass 2 #034)
            AiInsightsCard(
              connection: person,
              insight: insight,
              memorySummary: memorySummary,
              memory: memory,
              initialSelectedTopic: initialSelectedTopic,
            ),
            InteractionDetailsCard(person: person, history: history),
            SizedBox(height: AppSpacing.space4),
            UpcomingPlansCard(person: person, plans: upcomingPlans),
            SizedBox(height: AppSpacing.space4),
            _ActivityLogSection(person: person, history: history),
          ],
        ),
      ),
    );
  }
}

String _initials(String fullName) {
  final words = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.length >= 2) {
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
  if (words.isNotEmpty) {
    return words.first.substring(0, min(2, words.first.length)).toUpperCase();
  }
  return '';
}

bool _isImageAttachment(AttachmentRef attachment) {
  final lower = attachment.name.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic');
}

Future<void> _showAttachmentViewer(
  BuildContext context,
  AttachmentRef attachment,
) async {
  if (!_isImageAttachment(attachment) ||
      attachment.storageUrl == null ||
      attachment.storageUrl!.isEmpty) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      attachment.name,
                      style: AppTypography.h2(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.network(
                  attachment.storageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return SizedBox(
                      width: 320,
                      height: 240,
                      child: Center(
                        child: Text(
                          'Image unavailable',
                          style: AppTypography.bodyLg(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, required this.onTap});

  final AttachmentRef attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isImage = _isImageAttachment(attachment);
    final hasUrl = attachment.storageUrl?.trim().isNotEmpty == true;

    if (isImage && hasUrl) {
      return InkWell(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tokens.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md - 1),
            child: Image.network(
              attachment.storageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: tokens.inkSubtle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ActionChip(
      avatar: Icon(isImage ? Icons.image_outlined : Icons.attach_file),
      label: Text(attachment.name),
      onPressed: isImage && hasUrl ? onTap : null,
    );
  }
}

/// Renders the Activity Log section for a contact with per-row delete
/// support. Shows a confirmation dialog on tap, then a 4-second undo
/// SnackBar before actually deleting the interaction and recalculating
/// the connection fields.
class _ActivityLogSection extends ConsumerStatefulWidget {
  const _ActivityLogSection({required this.person, required this.history});

  final Connection person;
  final List<CrmInteraction> history;

  @override
  ConsumerState<_ActivityLogSection> createState() =>
      _ActivityLogSectionState();
}

class _ActivityLogSectionState extends ConsumerState<_ActivityLogSection> {
  String? _deletingInteractionId;
  Timer? _deleteTimer;
  bool _deleteCancelled = false;
  CrmInteraction? _pendingDeletedInteraction;

  @override
  void dispose() {
    _deleteTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmDelete(CrmInteraction interaction) async {
    final personName = widget.person.name.split(' ').first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this activity?'),
        content: Text(
          'This activity is part of $personName\'s history. '
          'Deleting it will reprocess AI Insights, connection score, '
          'and last contact from the remaining activity log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    _startDeleteWithUndo(interaction);
  }

  void _startDeleteWithUndo(CrmInteraction interaction) {
    // Cancel any in-flight timer from a previous delete attempt
    // to prevent a silent double-delete race condition.
    _deleteTimer?.cancel();
    _deleteTimer = null;
    _deleteCancelled = false;

    setState(() => _deletingInteractionId = interaction.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 4),
        content: Text('Deleting ${interaction.title}...'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _deleteTimer?.cancel();
            _deleteTimer = null;
            _deleteCancelled = true;
            setState(() => _deletingInteractionId = null);

            // If the interaction has already been removed (race/case
            // where timer fired before the user tapped Undo), attempt
            // to restore it so it reappears in the Activity Log.
            final exists = ref
                .read(appControllerProvider)
                .interactions
                .any((i) => i.id == interaction.id);
            if (!exists) {
              // Fire-and-forget restore; the store/save will update
              // the snapshot listeners and UI.
              unawaited(
                ref
                    .read(appControllerProvider.notifier)
                    .restoreInteraction(interaction),
              );
            }
          },
        ),
      ),
    );

    _pendingDeletedInteraction = interaction;
    _deleteTimer = Timer(const Duration(milliseconds: 4100), () async {
      if (!mounted || _deleteCancelled) {
        _pendingDeletedInteraction = null;
        _deleteTimer = null;
        return;
      }

      // Capture ScaffoldMessenger before the await so it's available
      // even if the widget tree rebuilds during the async chain.
      final messenger = ScaffoldMessenger.of(context);
      try {
        final rebuildSucceeded = await ref
            .read(appControllerProvider.notifier)
            .deleteInteraction(interaction.id);
        if (!rebuildSucceeded) {
          messenger.showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.fixed,
              content: Text(
                'AI Insights could not be refreshed. Try refreshing manually later.',
              ),
            ),
          );
        }
      } finally {
        // ignore: use_build_context_synchronously
        if (mounted) {
          setState(() {
            _deletingInteractionId = null;
            _deleteTimer = null;
          });
          // Offer a post-delete Undo so users can restore even after
          // the deletion completed (mirrors restoreEvent behavior).
          final deleted = _pendingDeletedInteraction;
          if (deleted != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.fixed,
                content: Text('Deleted ${deleted.title}'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    ref
                        .read(appControllerProvider.notifier)
                        .restoreInteraction(deleted);
                  },
                ),
              ),
            );
          }
          _pendingDeletedInteraction = null;
        } else {
          _pendingDeletedInteraction = null;
          _deleteTimer = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final history = widget.history;

    return CardBox(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space5,
              AppSpacing.space5,
              AppSpacing.space5,
              AppSpacing.space4,
            ),
            child: Text('Activity Log', style: AppTypography.h2()),
          ),
          if (history.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.space5,
                0,
                AppSpacing.space5,
                AppSpacing.space5,
              ),
              child: Center(
                child: Text(
                  "${widget.person.name.split(' ').first}'s new \u2014 you'll fill this in over time.",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLg(color: tokens.inkMuted),
                ),
              ),
            )
          else
            for (var i = 0; i < history.length; i++) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.space5,
                  vertical: AppSpacing.space3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left date column
                    SizedBox(
                      width: 96,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('yyyy-MM-dd').format(history[i].date),
                            style: AppTypography.caption(
                              color: tokens.inkMuted,
                            ),
                          ),
                          if (history[i].attachments.isNotEmpty) ...[
                            SizedBox(height: AppSpacing.space2),
                            _AttachmentChip(
                              attachment: history[i].attachments.first,
                              onTap: () => _showAttachmentViewer(
                                context,
                                history[i].attachments.first,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.space3),
                    // Main content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Text(history[i].title, style: AppTypography.bodyLg()),
                          SizedBox(height: AppSpacing.space1),
                          // AI badge + delete row
                          Row(
                            children: [
                              if (history[i].source ==
                                  InteractionSource.aiSuggested) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space2,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.primaryTint,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 11,
                                        color: tokens.primary,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'AI',
                                        style: AppTypography.caption(
                                          color: tokens.primary,
                                        ).copyWith(fontSize: 10, height: 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Spacer(),
                              IconButton(
                                key: Key('delete-interaction-${history[i].id}'),
                                icon: Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: _deletingInteractionId == history[i].id
                                      ? tokens.inkSubtle
                                      : tokens.inkMuted,
                                ),
                                onPressed:
                                    _deletingInteractionId == history[i].id
                                    ? null
                                    : () => _confirmDelete(history[i]),
                                tooltip: 'Delete activity',
                                visualDensity: VisualDensity.compact,
                                constraints: BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                            ],
                          ),
                          // Note text
                          if (history[i].note.isNotEmpty) ...[
                            SizedBox(height: AppSpacing.space1),
                            Text(
                              history[i].note,
                              style: AppTypography.bodyLg(
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < history.length - 1)
                Divider(color: tokens.border, height: 1, thickness: 1),
            ],
        ],
      ),
    );
  }
}

ImageProvider<Object>? _contactAvatarImage(String avatar) {
  final trimmed = avatar.trim();
  if (!trimmed.startsWith('data:image/')) return null;
  final parts = trimmed.split(',');
  if (parts.length != 2) return null;
  try {
    return MemoryImage(base64Decode(parts[1]));
  } catch (_) {
    return null;
  }
}

String _contactAvatarGlyph(String avatar, String fullName) {
  final trimmed = avatar.trim();
  if (trimmed.isNotEmpty && !trimmed.startsWith('data:image/')) {
    return trimmed;
  }
  return _initials(fullName);
}

String _connectionStatusLabel(int score) {
  final label = BondTier.from(score).label;
  return '${label[0].toUpperCase()}${label.substring(1)}';
}

DateTime? _latestInteractionDate(List<CrmInteraction> history) {
  if (history.isEmpty) return null;
  return history
      .map((interaction) => interaction.date)
      .reduce((latest, date) => date.isAfter(latest) ? date : latest);
}

String _lastInteractionLabel(List<CrmInteraction> history) {
  final latest = _latestInteractionDate(history);
  if (latest == null) return '—';
  return DateFormat.yMMMd().format(latest);
}

Color _connectionStatusColor(AppTokens tokens, int score) {
  final tier = BondTier.from(score);
  return switch (tier) {
    BondTier.close => tokens.primary,
    BondTier.steady => tokens.inkMuted,
    BondTier.drifting => tokens.secondary,
  };
}

class InteractionDetailsCard extends StatefulWidget {
  const InteractionDetailsCard({
    super.key,
    required this.person,
    required this.history,
  });

  final Connection person;
  final List<CrmInteraction> history;

  @override
  State<InteractionDetailsCard> createState() => _InteractionDetailsCardState();
}

class _InteractionDetailsCardState extends State<InteractionDetailsCard> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lastContactLabel = _lastInteractionLabel(widget.history);
    final detailRows = [
      _DetailRow(
        label: 'Connection Score',
        value: widget.person.bondScore.toString(),
      ),
      _DetailRow(
        label: 'Status',
        value: _connectionStatusLabel(widget.person.bondScore),
      ),
      _DetailRow(label: 'Last Contact', value: lastContactLabel),
      _DetailRow(
        label: 'Interactions',
        value: widget.history.isEmpty
            ? 'No recent activity'
            : '${widget.history.length} recent',
      ),
    ];

    return CardBox(
      padding: EdgeInsets.zero,
      onTap: () => setState(() => expanded = !expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space5,
              AppSpacing.space5,
              AppSpacing.space5,
              AppSpacing.space4,
            ),
            child: Row(
              children: [
                Icon(Icons.bar_chart, color: tokens.primary),
                SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Text('Interaction Details', style: AppTypography.h2()),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: tokens.inkMuted,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutQuart,
            child: expanded
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.space5,
                      0,
                      AppSpacing.space5,
                      AppSpacing.space5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Heatmap: last 12 months interaction counts
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.space2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Interaction Frequency (12 months)',
                                style: AppTypography.caption(
                                  color: tokens.inkMuted,
                                ),
                              ),
                              SizedBox(height: AppSpacing.space2),
                              _buildHeatmap(context, widget.history),
                            ],
                          ),
                        ),
                        SizedBox(height: AppSpacing.space3),
                        // Keep the simple metadata rows below
                        for (var row in detailRows) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.space2,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.label,
                                    style: AppTypography.caption(
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                                ),
                                Text(row.value, style: AppTypography.bodyLg()),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Builds a 12-month heatmap row based on the given interactions.
  Widget _buildHeatmap(BuildContext context, List<CrmInteraction> history) {
    final now = DateTime.now();
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final heatColor = categoryColor(widget.person.category, tokens);
    // Build month buckets for the last 12 months (oldest first)
    final months = List<DateTime>.generate(12, (i) {
      final dt = DateTime(now.year, now.month - (11 - i), 1);
      return dt;
    });

    final counts = Map<String, int>.fromEntries(
      months.map((m) => MapEntry(_monthKey(m), 0)),
    );

    for (final it in history) {
      final key = _monthKey(DateTime(it.date.year, it.date.month, 1));
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }

    final maxCount = counts.values.fold(0, max);

    return Row(
      children: months.asMap().entries.map((entry) {
        final i = entry.key;
        final month = entry.value;
        final count = counts[_monthKey(month)] ?? 0;
        final alpha = count == 0 || maxCount == 0
            ? 0.0
            : 0.36 + (count / maxCount) * 0.54;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : AppSpacing.space1,
              right: i == 11 ? 0 : AppSpacing.space1,
            ),
            child: Tooltip(
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: AppTokens.elevation2(dark),
              ),
              textStyle: AppTypography.caption(
                color: tokens.ink,
              ).copyWith(fontWeight: FontWeight.w700),
              message:
                  '${DateFormat.MMM().format(month)}\n$count interaction${count == 1 ? '' : 's'}',
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: count == 0
                      ? tokens.surfaceSunken
                      : heatColor.withValues(alpha: alpha),
                  border: Border.all(
                    color: count == 0
                        ? tokens.border.withValues(alpha: .72)
                        : heatColor.withValues(alpha: .86),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _monthKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
}

String _plannerEventTimeLabel(PlannerEvent event) {
  if (event.isAllDay) return 'All day';

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHour = hours % 12 == 0 ? 12 : hours % 12;
    final displayMinute = mins.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  final start = event.startTimeMinutes;
  final end = event.endTimeMinutes;
  if (start == null) return 'Scheduled';
  if (end == null) return formatMinutes(start);
  return '${formatMinutes(start)} - ${formatMinutes(end)}';
}

IconData _plannerEventIconForType(String eventType) {
  final value = eventType.toLowerCase().trim();
  if (value.contains('coffee') || value.contains('cafe')) {
    return Icons.local_cafe_outlined;
  }
  if (value.contains('meeting') ||
      value.contains('sync') ||
      value.contains('team')) {
    return Icons.groups_2_outlined;
  }
  if (value.contains('lunch') ||
      value.contains('dinner') ||
      value.contains('food') ||
      value.contains('restaurant')) {
    return Icons.restaurant_outlined;
  }
  if (value.contains('call') || value.contains('phone')) {
    return Icons.call_outlined;
  }
  if (value.contains('party') || value.contains('celebrate')) {
    return Icons.celebration_outlined;
  }
  if (value.contains('birth') || value.contains('anniversary')) {
    return Icons.cake_outlined;
  }
  if (value.contains('remind') || value.contains('alert')) {
    return Icons.notifications_none;
  }
  if (value.contains('workshop') ||
      value.contains('class') ||
      value.contains('study') ||
      value.contains('school')) {
    return Icons.menu_book_outlined;
  }
  if (value.contains('travel') ||
      value.contains('trip') ||
      value.contains('flight')) {
    return Icons.flight_takeoff_outlined;
  }
  if (value.contains('plan') || value.contains('schedule')) {
    return Icons.event_note_outlined;
  }
  if (value.contains('gift')) return Icons.card_giftcard_outlined;
  return Icons.event_outlined;
}

class UpcomingPlansCard extends StatefulWidget {
  const UpcomingPlansCard({
    super.key,
    required this.person,
    required this.plans,
  });

  final Connection person;
  final List<PlannerEvent> plans;

  @override
  State<UpcomingPlansCard> createState() => _UpcomingPlansCardState();
}

class _UpcomingPlansCardState extends State<UpcomingPlansCard> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return CardBox(
      padding: EdgeInsets.zero,
      onTap: () => setState(() => expanded = !expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space5,
              AppSpacing.space5,
              AppSpacing.space5,
              AppSpacing.space4,
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_outlined, color: tokens.primary),
                SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Text('Upcoming Plans', style: AppTypography.h2()),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${widget.plans.length} plan${widget.plans.length == 1 ? '' : 's'}',
                    style: AppTypography.caption(
                      color: tokens.primary,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: tokens.inkMuted,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutQuart,
            child: expanded
                ? (widget.plans.isEmpty
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.space5,
                            0,
                            AppSpacing.space5,
                            AppSpacing.space5,
                          ),
                          child: Text(
                            'No upcoming plans yet for ${widget.person.name.split(' ').first}.',
                            style: AppTypography.bodyLg(color: tokens.inkMuted),
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.space5,
                            0,
                            AppSpacing.space5,
                            AppSpacing.space5,
                          ),
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < widget.plans.length;
                                index++
                              ) ...[
                                if (index > 0)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppSpacing.space3,
                                    ),
                                    child: Divider(
                                      color: tokens.border,
                                      height: 1,
                                    ),
                                  ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: tokens.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _plannerEventIconForType(
                                          widget.plans[index].eventType,
                                        ),
                                        color: tokens.primary,
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: AppSpacing.space3),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.plans[index].title,
                                            style:
                                                AppTypography.bodyLg(
                                                  color: tokens.ink,
                                                ).copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          SizedBox(height: AppSpacing.space1),
                                          Text(
                                            '${DateFormat.MMMd().format(widget.plans[index].date)} • ${_plannerEventTimeLabel(widget.plans[index])}',
                                            style: AppTypography.caption(
                                              color: tokens.inkMuted,
                                            ),
                                          ),
                                          if (widget.plans[index].note
                                              .trim()
                                              .isNotEmpty) ...[
                                            SizedBox(height: AppSpacing.space1),
                                            Text(
                                              widget.plans[index].note,
                                              style: AppTypography.caption(
                                                color: tokens.inkSubtle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;
}
