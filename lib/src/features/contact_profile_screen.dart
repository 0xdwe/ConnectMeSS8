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
  const ContactProfileScreen({super.key, required this.contactId});
  final String contactId;

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
    final memoryAsync = ref.watch(memoryProvider(contactId));
    final memory = memoryAsync.maybeWhen(
      data: (doc) => doc,
      orElse: () => null,
    );
    final memorySummary = (memory != null && memory.summary.trim().isNotEmpty)
        ? memory.summary
        : null;
    
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
                      child: Text(
                        _initials(person.name),
                        style: AppTypography.bodyLg(color: tokens.primary),
                      ),
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
                                icon: Icon(Icons.edit,
                                    size: 16, color: tokens.primary),
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
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space3,
                                    vertical: AppSpacing.space2,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.space2),
                          Text(
                            person.category,
                            style: AppTypography.caption(color: tokens.inkMuted),
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
                  padding: EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    color: tokens.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BondRing(connection: person, size: 72),
                      SizedBox(width: AppSpacing.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bond Score',
                              style: AppTypography.caption(color: tokens.inkMuted),
                            ),
                            SizedBox(height: AppSpacing.space1),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  person.bondScore.toString(),
                                  style: AppTypography.display(),
                                ),
                                SizedBox(width: AppSpacing.space2),
                                Icon(
                                  person.bondTrend == BondTrend.up
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: person.bondTrend == BondTrend.up
                                      ? tokens.success
                                      : tokens.danger,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Known Since',
                            style: AppTypography.caption(color: tokens.inkMuted),
                          ),
                          SizedBox(height: AppSpacing.space1),
                          Text(
                            '${insight.knownSinceYears} years',
                            style: AppTypography.bodyLg(),
                          ),
                          SizedBox(height: AppSpacing.space3),
                          Text(
                            'Last contact',
                            style: AppTypography.caption(color: tokens.inkMuted),
                          ),
                          SizedBox(height: AppSpacing.space1),
                          Text(
                            DateFormat.yMMMd().format(person.lastContact),
                            style: AppTypography.bodyLg(),
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
          ),
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
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: tokens.primary),
                      SizedBox(width: AppSpacing.space3),
                      Text('Communication Channels', style: AppTypography.h2()),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    0,
                    AppSpacing.space5,
                    AppSpacing.space5,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.space2,
                    runSpacing: AppSpacing.space2,
                    children: [
                      for (final channel in person.preferredChannels)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.space3,
                            vertical: AppSpacing.space2,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.primary,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            channel,
                            style: AppTypography.body(color: tokens.surface),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InteractionDetailsCard(
            person: person,
            insight: insight,
            history: history,
          ),
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
                            child: Text(
                              DateFormat('yyyy-MM-dd').format(history[i].date),
                              style: AppTypography.caption(color: tokens.inkMuted),
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
                                    if (history[i].source == InteractionSource.aiSuggested) ...[
                                      SizedBox(width: AppSpacing.space2),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.space2,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.primaryTint,
                                          borderRadius: BorderRadius.circular(AppRadius.sm),
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
                                              style: AppTypography.caption(color: tokens.primary).copyWith(fontSize: 10, height: 1),
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
                                    style: AppTypography.bodyLg(color: tokens.inkMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < history.length - 1)
                      Divider(
                        color: tokens.border,
                        height: 1,
                        thickness: 1,
                      ),
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

class InteractionDetailsCard extends StatefulWidget {
  const InteractionDetailsCard({
    super.key,
    required this.person,
    required this.insight,
    required this.history,
  });

  final Connection person;
  final ContactInsight insight;
  final List<CrmInteraction> history;

  @override
  State<InteractionDetailsCard> createState() => _InteractionDetailsCardState();
}

class _InteractionDetailsCardState extends State<InteractionDetailsCard> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final detailRows = [
      _DetailRow(
        label: 'Bond Score',
        value: widget.person.bondScore.toString(),
      ),
      _DetailRow(
        label: 'Known Since',
        value: '${widget.insight.knownSinceYears} years',
      ),
      _DetailRow(
        label: 'Last Contact',
        value: DateFormat.yMMMd().format(widget.person.lastContact),
      ),
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
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.space2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Interaction Frequency (12 months)', style: AppTypography.caption(color: tokens.inkMuted)),
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
                                    style: AppTypography.caption(color: tokens.inkMuted),
                                  ),
                                ),
                                Text(
                                  row.value,
                                  style: AppTypography.bodyLg(),
                                ),
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

    final maxCount = counts.values.isEmpty ? 0 : counts.values.reduce(max);
    final tokens = context.tokens;

    return Row(
      children: [
        for (final m in months)
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.space2),
            child: Tooltip(
              message: '${DateFormat.MMM().format(m)}\n${counts[_monthKey(m)]} interactions',
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _heatColor(tokens, counts[_monthKey(m)] ?? 0, maxCount),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _monthKey(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';

  Color _heatColor(AppTokens tokens, int count, int maxCount) {
    if (maxCount <= 0 || count <= 0) return tokens.surfaceRaised;
    final intensity = count / maxCount; // 0..1
    // Map intensity to an opacity of the success color for visibility.
    final base = tokens.success;
    return base.withOpacity(0.25 + (0.7 * intensity));
  }
}

class _DetailRow {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;
}
