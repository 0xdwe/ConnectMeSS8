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
      ),
      floatingActionButton: AiActionFab(
        key: const Key('update-with-ai-button'),
        onTap: () => context.push('/ai-update/${person.id}'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListView(
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
              color: tokens.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.lg),
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
                                child: Text(
                                  person.name,
                                  style: AppTypography.display(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: AppSpacing.space3),
                              OutlinedButton.icon(
                                key: const Key('edit-connection-button'),
                                onPressed: () =>
                                    showEditConnectionModal(context, person),
                                icon: Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: tokens.primary,
                                ),
                                label: Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: tokens.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: tokens.surfaceRaised,
                                  side: BorderSide(color: tokens.surfaceRaised),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space3,
                                    vertical: AppSpacing.space2,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
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
                            style: AppTypography.body(color: tokens.inkSubtle),
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
                                  person.bondTrend == BondTrend.up
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: person.bondTrend == BondTrend.up
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
                                    color: statusColor.withValues(alpha: 0.14),
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
          CardBox(
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
                        "${person.name.split(' ').first}'s new \u2014 you'll fill this in over time.",
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
                          // Main content: title (bold) + note (muted)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        history[i].title,
                                        style: AppTypography.bodyLg(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (history[i].source ==
                                        InteractionSource.aiSuggested) ...[
                                      SizedBox(width: AppSpacing.space2),
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
                                              style:
                                                  AppTypography.caption(
                                                    color: tokens.primary,
                                                  ).copyWith(
                                                    fontSize: 10,
                                                    height: 1,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (history[i].note.isNotEmpty) ...[
                                  SizedBox(height: AppSpacing.space2),
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
          ),
        ],
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
                child: Icon(Icons.broken_image_outlined, color: tokens.inkSubtle),
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

class _DetailRow {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;
}