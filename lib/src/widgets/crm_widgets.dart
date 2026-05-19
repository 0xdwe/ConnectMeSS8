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
            style: AppTypography.h1(),
            softWrap: true,
          );

          if (action == null) {
            return titleWidget;
          }

          final mustStack = constraints.maxWidth < _stackBelowWidth &&
              title.length > _shortTitleMaxChars;

          if (mustStack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget,
                SizedBox(height: AppSpacing.space2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: action!,
                ),
              ],
            );
          }

          return Row(
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
                      Flexible(
                        child: Text(
                          '· ${tier.label}',
                          style: AppTypography.h2(color: tokens.inkMuted),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// AI Insights card (Pass 2, issue #034)
//
// Three subsections:
//   1. Recommendation callout — bond-tier-derived encouragement
//   2. Person Summary         — ContactInsight.why
//   3. Conversation Topics    — category-keyed pill tags + tap-to-open
//                                bottom sheet of static suggestions
//
// The category-keyed topics helper and suggestions map are the
// Pass 3 swap point per docs/prd/2026-05-16-per-contact-memory-files-prd.md.
// When memory lands, `topicsForContact` and `suggestionsForTopic`
// redirect to memory-derived data.
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<String>> _topicDefaultsByCategory = {
  'Family':      ['Family updates', 'Shared memories', 'Daily life', 'Future plans'],
  'Friends':     ['Recent meetups', 'Inside jokes', 'Plans together', 'Life updates'],
  'College':     ['Old classes', 'Mutual friends', 'Career', 'Reunions'],
  'High School': ['Old times', 'Mutual friends', 'Where they are now', 'Reunions'],
  'Work':        ['Projects', 'Career', 'Industry news', 'Team updates'],
};

const List<String> _genericTopicDefaults = [
  'Recent updates',
  'Shared interests',
  'Life events',
  'Future plans',
];

/// Returns up to 4 topic strings for a contact, keyed by category.
/// Pass 3 swap point: this becomes a memory-derived read.
List<String> topicsForContact(Connection connection) {
  final list = _topicDefaultsByCategory[connection.category] ?? _genericTopicDefaults;
  return list.take(4).toList(growable: false);
}

const Map<String, Map<String, List<String>>> _topicSuggestions = {
  'Family': {
    'Family updates':  ['Ask how the family is doing', 'Share a recent family photo', 'Mention an upcoming family event'],
    'Shared memories': ['Recall a favorite holiday', 'Bring up a childhood story', 'Reference a shared inside joke'],
    'Daily life':      ['Ask about their week', 'Share something from your routine', 'Plan a regular check-in'],
    'Future plans':    ['Discuss travel ideas', 'Talk about upcoming milestones', 'Mention something you want to do together'],
  },
  'Friends': {
    'Recent meetups':  ['Reference the last hangout', 'Plan the next one', 'Share a photo from the last meet-up'],
    'Inside jokes':    ['Bring up a running joke', 'Send a meme that fits your vibe', 'Reminisce about a funny moment'],
    'Plans together':  ['Suggest a coffee or meal', 'Pitch a small adventure', 'Pick a date that works for both'],
    'Life updates':    ['Ask what\'s been new lately', 'Share something from your week', 'Catch up on the bigger picture'],
  },
  'College': {
    'Old classes':       ['Bring up a favorite class', 'Reference a tough exam you survived', 'Mention a professor you both had'],
    'Mutual friends':    ['Ask if they\'re still in touch with someone', 'Share an update about a mutual friend', 'Suggest a small reunion'],
    'Career':            ['Ask how work is going', 'Share a career update of your own', 'Talk about industry shifts'],
    'Reunions':          ['Float a meet-up idea', 'Mention an upcoming alumni event', 'Suggest a video call to catch up'],
  },
  'High School': {
    'Old times':              ['Reference a memorable moment', 'Share an old photo', 'Bring up a teacher you both remember'],
    'Mutual friends':         ['Ask about a shared friend', 'Suggest a group chat', 'Share what you\'ve heard from someone'],
    'Where they are now':     ['Ask what they\'re up to these days', 'Share what you\'re focused on', 'Compare notes on life stage'],
    'Reunions':               ['Mention an upcoming reunion', 'Pitch a small get-together', 'Suggest a quick video call'],
  },
  'Work': {
    'Projects':       ['Ask what they\'re working on', 'Share a recent project win', 'Trade notes on a tough problem'],
    'Career':         ['Ask about career goals', 'Share an opportunity you saw', 'Compare notes on growth'],
    'Industry news':  ['Reference a recent headline', 'Share an article you found useful', 'Ask their take on a trend'],
    'Team updates':   ['Ask how the team is doing', 'Share a team change of your own', 'Talk about working styles'],
  },
};

const List<String> _genericSuggestions = [
  'Ask an open question about how they\'ve been',
  'Share a recent update from your own life',
  'Suggest meeting up',
];

/// Returns 3-5 conversation-starter suggestions for a (category, topic) pair.
/// Pass 3 swap point: this becomes memory-derived.
List<String> suggestionsForTopic(String category, String topic) {
  return _topicSuggestions[category]?[topic] ?? _genericSuggestions;
}

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
  });
  final Connection connection;
  final ContactInsight insight;

  /// Person Summary text from `MemoryDocument.summary`. When null or
  /// empty, the card falls back to `insight.why` (#050 deletes the
  /// fallback once the data path is proven).
  final String? memorySummary;

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
  });

  final Connection connection;
  final ContactInsight insight;
  final String? memorySummary;
  final BondTier tier;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final topics = topicsForContact(connection);
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
              : insight.why,
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
/// for the given (category, topic) pair.
void _showTopicSuggestionsSheet(
  BuildContext context,
  String category,
  String topic,
) {
  final tokens = context.tokens;
  final suggestions = suggestionsForTopic(category, topic);
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
