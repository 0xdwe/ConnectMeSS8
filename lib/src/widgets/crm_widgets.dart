import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../state/conversation_topics.dart';
import '../state/memory/memory_document.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'bond_ring.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.tokens.surface, child: child);
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.onProfileTap,
    required this.userName,
    required this.userAvatar,
  });
  final VoidCallback onProfileTap;
  final String userName;
  final String userAvatar;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 108,
      padding: EdgeInsets.fromLTRB(AppSpacing.space6, AppSpacing.space5, AppSpacing.space5, AppSpacing.space4),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        boxShadow: AppTokens.elevation1(dark),
      ),
      child: Row(
        children: [
          Text('🔗', style: AppTypography.glyph(38)),
          SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Connect Me',
                  style: AppTypography.h1(color: tokens.primary),
                ),
                Text(
                  userName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          InkWell(
            key: const Key('profile-button'),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 34,
              backgroundColor: tokens.primaryTint,
              child: Text(userAvatar, style: AppTypography.glyph(32)),
            ),
          ),
        ],
      ),
    );
  }
}

@Deprecated('Use BondRing instead. ScoreRing will be removed in a future release.')
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.size = 72,
    this.stroke = 8,
  });
  final int score;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: stroke,
              color: tokens.border,
            ),
          ),
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: stroke,
              color: tokens.primary,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Score number uses tabular figures for consistent width across 0-100 range.
          Text(
            '$score',
            style: AppTypography.monoTabular().copyWith(
              fontSize: size * .28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.space5),
    this.border,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Border? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: tokens.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: border,
      boxShadow: AppTokens.elevation1(dark),
    );
    if (onTap == null) {
      return Container(
        margin: EdgeInsets.only(bottom: AppSpacing.space4),
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.space4),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class ContactListCard extends StatelessWidget {
  const ContactListCard({
    super.key,
    required this.connection,
    required this.onTap,
  });
  final Connection connection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CardBox(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: tokens.primaryTint,
              child: Text(
                connection.avatar,
                style: AppTypography.glyph(26),
              ),
            ),
            SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          connection.name,
                          style: AppTypography.h2(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: AppSpacing.space2),
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: categoryColor(connection.category, tokens),
                      ),
                      if (connection.isSample) ...[
                        SizedBox(width: AppSpacing.space2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.space2,
                            vertical: AppSpacing.space1,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceSunken,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'Sample',
                            style: AppTypography.caption(color: tokens.inkSubtle),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    connection.email,
                    style: AppTypography.body(color: tokens.inkMuted),
                  ),
                ],
              ),
            ),
            BondRing(connection: connection, size: 48, showAvatar: false),
          ],
        ),
      ),
    );
  }
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.connection,
    required this.recommendation,
    this.onTap,
  });
  final Connection connection;
  final Recommendation recommendation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final priority = _recommendationPriority(connection.bondScore);
    final priorityColor = _recommendationPriorityColor(connection.bondScore, tokens);

    return CardBox(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: tokens.primaryTint,
            child: Text(
              connection.avatar,
              style: AppTypography.glyph(20, color: tokens.primary),
            ),
          ),
          SizedBox(width: AppSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.name,
                  style: AppTypography.h2(color: tokens.ink),
                ),
                SizedBox(height: AppSpacing.space2),
                Text(
                  recommendation.reason,
                  style: AppTypography.body(color: tokens.inkMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.space4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                  vertical: AppSpacing.space1,
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  priority,
                  style: AppTypography.caption(color: priorityColor),
                ),
              ),
              SizedBox(height: AppSpacing.space3),
              BondRing.fromScore(
                score: connection.bondScore,
                label: connection.name,
                size: 44,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _recommendationPriority(int score) => score < 55 ? 'High' : 'Medium';

Color _recommendationPriorityColor(int score, AppTokens tokens) =>
    score < 55 ? tokens.danger : tokens.secondary;

/// Returns the category-color mapping per DESIGN.md.
Color categoryColor(String category, AppTokens tokens) {
  switch (category) {
    case 'Family':
      return tokens.categoryFamily;
    case 'Friends':
      return tokens.categoryFriends;
    case 'College':
      return tokens.categoryCollege;
    case 'High School':
      return tokens.categoryHighSchool;
    case 'Work':
      return tokens.categoryWork;
    default:
      return tokens.inkMuted;
  }
}

class HeatmapCard extends StatelessWidget {
  const HeatmapCard({super.key, required this.connections});
  final List<Connection> connections;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final categories = ['Family', 'Friends', 'High School', 'College', 'Work'];
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: tokens.primary),
              SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  'Connection Heatmap by Category',
                  style: AppTypography.h1(),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space5),
          Text(
            'Your social activity patterns over months',
            style: AppTypography.bodyLg(color: tokens.inkMuted),
          ),
          SizedBox(height: AppSpacing.space5),
          for (final category in categories)
            _HeatmapRow(
              category: category,
              count: connections.where((c) => c.category == category).length,
              color: categoryColor(category, tokens),
            ),
        ],
      ),
    );
  }
}

class _HeatmapRow extends StatelessWidget {
  const _HeatmapRow({
    required this.category,
    required this.count,
    required this.color,
  });
  final String category;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 9, backgroundColor: color),
              SizedBox(width: AppSpacing.space3),
              Text(
                category,
                style: AppTypography.h2(),
              ),
              Text(
                '  ($count contact)',
                style: AppTypography.bodyLg(color: tokens.inkMuted),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space3),
          Row(
            children: List.generate(12, (i) {
              final active = (i * 19 + category.length * 7) % 100;
              return Expanded(
                child: Container(
                  height: 56,
                  margin: EdgeInsets.only(right: AppSpacing.space2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .35 + (active % 60) / 100),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.titleStyle});
  final String title;
  final Widget? action;
  final TextStyle? titleStyle;

  /// Threshold below which the action stacks beneath the title.
  ///
  /// At h1 (26pt bold) a long title like "Today's Recommendation" needs
  /// ~290pt of width. With a typical action (~110pt) and gutter, the Row
  /// layout requires roughly 420pt of constraint width to avoid wrapping
  /// the title. Phones (320–414pt) sit below that line; tablets (≥768pt)
  /// have plenty of room. 420 is the empirically-tuned cutoff.
  static const double _stackBelowWidth = 420;

  /// Title length below which the Row layout is safe even on narrow
  /// phones. "History" (7), "Plan" (4), "Settings" (8) all fit easily.
  /// "Today's Recommendation" (22) does not.
  static const int _shortTitleMaxChars = 12;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space1,
        AppSpacing.space4,
        AppSpacing.space1,
        AppSpacing.space2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleWidget = Text(
            title,
            style: titleStyle ?? AppTypography.h1(),
            softWrap: true,
          );

          if (action == null) {
            return titleWidget;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleWidget),
              action!,
            ],
          );
        },
      ),
    );
  }
}

class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.event,
    this.contact,
    this.onTap,
    this.onDelete,
  });
  final PlannerEvent event;
  final Connection? contact;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CardBox(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space4),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        title: Text(
          event.title,
          style: AppTypography.h2(),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy-MM-dd').format(event.date),
              style: AppTypography.bodyLg(color: tokens.inkMuted),
            ),
            Text(
              event.isAllDay
                  ? '${event.eventType}${event.isRecurring ? ' • ${event.recurrencePattern?.label ?? 'Repeats'}' : ''}'
                  : '${event.eventType} • ${_formatMinutes(event.startTimeMinutes)}-${_formatMinutes(event.endTimeMinutes)}',
              style: AppTypography.caption(color: tokens.inkMuted),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contact != null)
              Text(contact!.avatar, style: AppTypography.glyph(28)),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatMinutes(int? minutes) {
    if (minutes == null) return '';
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CardBox(
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 42, color: tokens.primary),
          Text(title, style: AppTypography.h2()),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body(color: tokens.inkMuted),
          ),
        ],
      ),
    );
  }
}

class GradientScaffold extends AppSurface {
  const GradientScaffold({super.key, required super.child});
}

/// ConnectionScoreHero: displays the user's average connection score
/// as a horizontal layout with the BondRing on the left and a
/// display-size score number plus tier label on the right. The score
/// is rendered at AppTypography.display so it reads as the page hero,
/// larger than the section titles below it.
class ConnectionScoreHero extends StatelessWidget {
  const ConnectionScoreHero({super.key, required this.score});
  
  final int score;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final semanticLabel = 'Connection score: $score';

    return Semantics(
      label: semanticLabel,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space5,
          vertical: AppSpacing.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Connection score',
              style: AppTypography.bodyLg(color: tokens.inkMuted),
            ),
            SizedBox(height: AppSpacing.space4),
            BondRing.fromScore(
              score: score,
              label: 'Connection score',
              size: 176,
              strokeWidth: 11,
            ),
            SizedBox(height: AppSpacing.space4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.space2,
              alignment: WrapAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: tokens.primary,
                  size: 18,
                ),
                Text(
                  'Keep nurturing your relationships!',
                  style: AppTypography.body(color: tokens.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Insights card (Pass 2, issue #034)
//
// Three subsections:
//   1. Recommendation callout — bond-tier-derived encouragement
//   2. Person Summary         — ContactInsight.why / memory.summary
//   3. Conversation Topics    — memory-derived pill tags + tap-to-open
//                                bottom sheet of static suggestions
//
// The category-keyed topics helper and suggestions map live in
// `lib/src/state/conversation_topics.dart` (extracted in #043). When
// `memory.topics` is non-empty, those topics drive the pill row;
// otherwise the static category-default fallback applies.
// ─────────────────────────────────────────────────────────────────────────────

/// Bond-tier-derived encouragement copy for the Recommendation callout.
String _bondEncouragement(BondTier tier) => switch (tier) {
      BondTier.close    => 'Strong bond! Keep up the regular communication.',
      BondTier.steady   => 'Steady ground — a quick check-in keeps it warm.',
      BondTier.drifting => 'It\'s been a while. A short hello goes a long way.',
    };

// Recommendation callout interior text colors.
//
// These are intentionally hardcoded brown/gold. There is no semantic
// "on-recommendation" token in the system yet. If we keep this pattern
// long-term we should add tokens for these colors.
const Color _recommendationTitleColor = Color(0xFF7B4F12);
const Color _recommendationBodyColor  = Color(0xFF6B4513);
const Color _recommendationIconColor  = Color(0xFFB7791F);

class AiInsightsCard extends StatefulWidget {
  const AiInsightsCard({
    super.key,
    required this.connection,
    required this.insight,
    this.memorySummary,
    this.memory,
  });
  final Connection connection;
  final ContactInsight insight;

  /// Person Summary text from `MemoryDocument.summary`. When null or
  /// empty, the card renders an empty body (memory is the single
  /// source of truth post-#050).
  final String? memorySummary;

  /// Full memory document for the contact. Drives the Conversation
  /// Topics pill row via `memory.topics` (#043). Null when memory is
  /// still loading or unavailable — falls back to category defaults.
  final MemoryDocument? memory;

  @override
  State<AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<AiInsightsCard> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tier = BondTier.from(widget.connection.bondScore);
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return CardBox(
      padding: EdgeInsets.zero,
      border: Border.all(color: tokens.border, width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: sparkle + "AI Insights" + chevron, full-width tap target.
          InkWell(
            key: const Key('ai-insights-header'),
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.space5,
                AppSpacing.space5,
                AppSpacing.space5,
                AppSpacing.space4,
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: tokens.primary),
                  SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Text(
                      'AI Insights',
                      style: AppTypography.h2(),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: tokens.inkMuted,
                  ),
                ],
              ),
            ),
          ),
          // Body — animated collapse, instant under reduced motion.
          //
          // We deliberately skip the AnimatedSize wrapper under
          // MediaQuery.disableAnimations: AnimatedSize with Duration.zero
          // trips a framework RenderAnimatedSize layout assertion, and
          // skipping the wrapper entirely is also semantically correct
          // when the user has reduced-motion preference.
          if (disableAnimations)
            expanded
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.space5,
                      0,
                      AppSpacing.space5,
                      AppSpacing.space5,
                    ),
                    child: _AiInsightsBody(
                      connection: widget.connection,
                      insight: widget.insight,
                      memorySummary: widget.memorySummary,
                      memory: widget.memory,
                      tier: tier,
                      tokens: tokens,
                    ),
                  )
                : const SizedBox.shrink()
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutQuart,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.space5,
                        0,
                        AppSpacing.space5,
                        AppSpacing.space5,
                      ),
                      child: _AiInsightsBody(
                        connection: widget.connection,
                        insight: widget.insight,
                        memorySummary: widget.memorySummary,
                        memory: widget.memory,
                        tier: tier,
                        tokens: tokens,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// Internal body of the AI Insights card. Extracted so that both the
/// animated and non-animated builds in `_AiInsightsCardState.build` can
/// share the same subtree.
class _AiInsightsBody extends StatelessWidget {
  const _AiInsightsBody({
    required this.connection,
    required this.insight,
    required this.tier,
    required this.tokens,
    this.memorySummary,
    this.memory,
  });

  final Connection connection;
  final ContactInsight insight;
  final String? memorySummary;
  final MemoryDocument? memory;
  final BondTier tier;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final topics = topicsForContact(connection, memory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommendation callout
        Container(
          padding: EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: tokens.recommendationSurface,
            border: Border.all(
              color: tokens.recommendationBorder,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: _recommendationIconColor,
                size: 22,
              ),
              SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommendation',
                      style: AppTypography.h2(
                        color: _recommendationTitleColor,
                      ),
                    ),
                    SizedBox(height: AppSpacing.space1),
                    Text(
                      _bondEncouragement(tier),
                      style: AppTypography.body(
                        color: _recommendationBodyColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.space5),
        // Person Summary
        Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 20,
              color: tokens.primary,
            ),
            SizedBox(width: AppSpacing.space2),
            Flexible(
              child: Text(
                'Person Summary',
                style: AppTypography.h2(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.space2),
        Text(
          (memorySummary != null && memorySummary!.trim().isNotEmpty)
              ? memorySummary!
              : '',
          style: AppTypography.body(color: tokens.inkMuted),
        ),
        SizedBox(height: AppSpacing.space5),
        // Conversation Topics
        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color: tokens.secondary,
            ),
            SizedBox(width: AppSpacing.space2),
            Flexible(
              child: Text(
                'Conversation Topics',
                style: AppTypography.h2(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.space3),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            for (final topic in topics)
              _TopicPill(
                topic: topic,
                onTap: () => _showTopicSuggestionsSheet(
                  context,
                  connection.category,
                  topic,
                  connection.name,
                ),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.space3),
        Text(
          'Click any topic to see AI suggestions.',
          style: AppTypography.caption(color: tokens.inkSubtle),
        ),
      ],
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.topic, required this.onTap});
  final String topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          // Cap pill width so very long topic labels truncate instead of
          // pushing the row off-screen.
          constraints: const BoxConstraints(maxWidth: 180),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.space3,
            vertical: AppSpacing.space2,
          ),
          decoration: BoxDecoration(
            color: tokens.topicAccent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            topic,
            style: AppTypography.body(color: tokens.primaryOn)
                .copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Opens a read-only bottom sheet listing 3-5 conversation suggestions
/// for the given (category, topic, contactName) tuple.
void _showTopicSuggestionsSheet(
  BuildContext context,
  String category,
  String topic,
  String contactName,
) {
  final tokens = context.tokens;
  final suggestions = suggestionsForTopic(category, topic, contactName);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: tokens.surfaceRaised,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
    ),
    builder: (context) {
      final sheetTokens = context.tokens;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space5,
            AppSpacing.space3,
            AppSpacing.space5,
            AppSpacing.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetTokens.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.space4),
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: sheetTokens.secondary,
                  ),
                  SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      topic,
                      style: AppTypography.h2(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.space4),
              for (final suggestion in suggestions)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.space3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: sheetTokens.inkMuted,
                      ),
                      SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: AppTypography.body(),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Pill-shaped, gradient floating action button used for "Update with AI"
/// on the contact profile screen (Pass 2 #035). Uses `tokens.aiGradient`
/// from #033, with an InkWell + Container shape so the gradient renders
/// (Flutter's FloatingActionButton.extended only accepts a single Color).
class AiActionFab extends StatelessWidget {
  const AiActionFab({super.key, required this.onTap, this.label = 'Update with AI'});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Material > Ink (gradient surface) > InkWell (above the gradient,
    // so the tap splash renders on top of the gradient instead of
    // being hidden by an opaque Container above it).
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: tokens.aiGradient,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppTokens.elevation2(dark),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.space5,
              vertical: AppSpacing.space3,
            ),
            child: ConstrainedBox(
              // Keeps total touch target >= 48pt (vertical padding 12 * 2 = 24,
              // so the row content needs at least 24 to reach 48).
              constraints: const BoxConstraints(minHeight: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: tokens.primaryOn, size: 20),
                  SizedBox(width: AppSpacing.space2),
                  Text(
                    label,
                    style: AppTypography.bodyLg(color: tokens.primaryOn)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
