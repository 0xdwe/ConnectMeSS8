import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
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
      padding: EdgeInsets.all(AppSpacing.space5),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: tokens.primaryTint,
              child: Text(
                connection.avatar,
                style: AppTypography.glyph(30),
              ),
            ),
            SizedBox(width: AppSpacing.space5),
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
                    style: AppTypography.bodyLg(color: tokens.inkMuted),
                  ),
                  SizedBox(height: AppSpacing.space2),
                  Chip(
                    label: Text(
                      connection.category,
                      style: AppTypography.body(),
                    ),
                    backgroundColor: tokens.surfaceSunken,
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
            BondRing(connection: connection, size: 72),
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
    
    return CardBox(
      onTap: onTap,
      padding: EdgeInsets.all(AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: BondRing + name + category dot
          Row(
            children: [
              BondRing(connection: connection, size: 56),
              SizedBox(width: AppSpacing.space4),
              Expanded(
                child: Text(
                  connection.name,
                  style: AppTypography.h2(color: tokens.ink),
                ),
              ),
              CircleAvatar(
                radius: 4,
                backgroundColor: categoryColor(connection.category, tokens),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space4),
          // Row 2: Conversational headline
          Text(
            recommendation.reason,
            style: AppTypography.bodyLg(color: tokens.ink),
          ),
          SizedBox(height: AppSpacing.space3),
          // Row 3: Insight text
          Text(
            recommendation.insight,
            style: AppTypography.body(color: tokens.inkMuted),
          ),
          SizedBox(height: AppSpacing.space4),
          // Row 4: Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    // TODO: Navigate to Update Connection flow
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.primary,
                    foregroundColor: tokens.primaryOn,
                  ),
                  child: const Text('Update Connection'),
                ),
              ),
              SizedBox(width: AppSpacing.space3),
              Expanded(
                child: TextButton(
                  onPressed: onTap,
                  child: const Text('Open profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.space1, AppSpacing.space4, AppSpacing.space1, AppSpacing.space2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.h1(),
              ),
            ),
            ?action,
          ],
        ),
      );
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

class RecommendedActionCard extends StatelessWidget {
  const RecommendedActionCard({super.key, required this.insight});
  final ContactInsight insight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CardBox(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSpacing.space5),
        decoration: BoxDecoration(
          color: tokens.secondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Recommended Action!',
              textAlign: TextAlign.center,
              style: AppTypography.h2(color: tokens.primaryOn),
            ),
            SizedBox(height: AppSpacing.space3),
            Text(
              'You can gain ${insight.potentialScoreGain}% Connection Score',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLg(color: tokens.primaryOn),
            ),
            SizedBox(height: AppSpacing.space2),
            Text(
              insight.recommendedAction,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLg(color: tokens.primaryOn),
            ),
          ],
        ),
      ),
    );
  }
}

class InsightCard extends StatefulWidget {
  const InsightCard({super.key, required this.insight});
  final ContactInsight insight;

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CardBox(
      border: Border.all(color: tokens.border, width: 1.5),
      child: InkWell(
        key: const Key('ai-insight-card'),
        onTap: () => setState(() => expanded = !expanded),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: tokens.primary),
                SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Text(
                    'AI Insight',
                    style: AppTypography.h2(color: tokens.ink),
                  ),
                ),
                Icon(Icons.expand_more, color: tokens.inkMuted),
              ],
            ),
            SizedBox(height: AppSpacing.space3),
            Text(
              widget.insight.summary,
              style: AppTypography.bodyLg(color: tokens.ink),
            ),
            if (expanded) ...[
              SizedBox(height: AppSpacing.space3),
              Text(
                widget.insight.why,
                key: const Key('ai-insight-why'),
                style: AppTypography.body(color: tokens.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RelationshipFactsCard extends StatelessWidget {
  const RelationshipFactsCard({
    super.key,
    required this.connection,
    required this.insight,
  });
  final Connection connection;
  final ContactInsight insight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Fact(
                  label: 'Relationship',
                  value: insight.relationshipLabel,
                ),
              ),
              SizedBox(width: AppSpacing.space4),
              Expanded(
                child: _Fact(
                  label: 'Known Since',
                  value: '${insight.knownSinceYears} years',
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.calendar_today_outlined, color: tokens.inkMuted),
              SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  'Last contact: ${DateFormat('yyyy-MM-dd').format(connection.lastContact)}',
                  style: AppTypography.bodyLg(color: tokens.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption(color: tokens.inkMuted),
        ),
        SizedBox(height: AppSpacing.space2),
        Text(
          value,
          style: AppTypography.h2(color: tokens.ink),
        ),
      ],
    );
  }
}

class CommunicationChannelsCard extends StatelessWidget {
  const CommunicationChannelsCard({super.key, required this.channels});
  final List<String> channels;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: tokens.primary),
              SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  'Top Communication Channels',
                  style: AppTypography.h2(),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space3),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final channel in channels)
                Chip(
                  label: Text(
                    channel,
                    style: AppTypography.body(color: tokens.primaryOn),
                  ),
                  backgroundColor: tokens.primary,
                  side: BorderSide.none,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class InteractionFrequencyCard extends StatelessWidget {
  const InteractionFrequencyCard({super.key, required this.frequencyByMonth});
  final List<int> frequencyByMonth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final values = frequencyByMonth.length >= 12
        ? frequencyByMonth.take(12).toList()
        : [
            ...frequencyByMonth,
            ...List<int>.filled(12 - frequencyByMonth.length, 0),
          ];
    final maxValue = values.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interaction Frequency (12 months)',
            style: AppTypography.h2(),
          ),
          SizedBox(height: AppSpacing.space4),
          Row(
            children: List.generate(12, (index) {
              final alpha = 0.35 + (values[index] / maxValue) * 0.55;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      key: Key('frequency-bar-$index'),
                      height: 32,
                      margin: EdgeInsets.symmetric(horizontal: AppSpacing.space1),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: alpha),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    SizedBox(height: AppSpacing.space2),
                    Text(
                      '${index + 1}',
                      style: AppTypography.caption(color: tokens.inkMuted),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
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
    final tier = BondTier.from(score);
    final trendLabel = score >= 70 ? 'trending up' : '';
    final semanticLabel = 'Connection score: $score, ${tier.label}${trendLabel.isNotEmpty ? ', $trendLabel' : ''}';
    
    return Semantics(
      label: semanticLabel,
      child: CardBox(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BondRing.fromScore(
              score: score,
              label: 'Overall connection health',
              size: 96,
            ),
            SizedBox(width: AppSpacing.space5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$score',
                        style: AppTypography.display(color: tokens.ink),
                      ),
                      SizedBox(width: AppSpacing.space2),
                      Text(
                        '· ${tier.label}',
                        style: AppTypography.h2(color: tokens.inkMuted),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.space2),
                  Text(
                    'Average across all connections',
                    style: AppTypography.bodyLg(color: tokens.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
