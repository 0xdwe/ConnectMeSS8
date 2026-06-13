import 'dart:convert';

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

ImageProvider<Object>? connectionAvatarImage(String avatar) {
  final trimmed = avatar.trim();
  if (!trimmed.startsWith('data:image/')) return null;

  final parts = trimmed.split(',');
  if (parts.length != 2) return null;

  return MemoryImage(base64Decode(parts[1]));
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space5,
        AppSpacing.space5,
        AppSpacing.space4,
      ),
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

@Deprecated(
  'Use BondRing instead. ScoreRing will be removed in a future release.',
)
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

class ContactListCard extends StatefulWidget {
  const ContactListCard({
    super.key,
    required this.connection,
    required this.onTap,
  });

  final Connection connection;
  final VoidCallback onTap;

  @override
  State<ContactListCard> createState() => _ContactListCardState();
}

class _ContactListCardState extends State<ContactListCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, hovering ? -3.0 : 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hovering ? 0.10 : 0.04),
              blurRadius: hovering ? 18 : 8,
              offset: Offset(0, hovering ? 8 : 3),
            ),
          ],
        ),
        child: CardBox(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.space5,
            vertical: AppSpacing.space5,
          ),
          border: Border.all(
            color: hovering
                ? tokens.primary.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          onTap: widget.onTap,
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: tokens.primaryTint,
                backgroundImage: connectionAvatarImage(
                  widget.connection.avatar,
                ),
                child: connectionAvatarImage(widget.connection.avatar) == null
                    ? Text(
                        widget.connection.avatar,
                        style: AppTypography.glyph(26),
                      )
                    : null,
              ),
              SizedBox(width: AppSpacing.space5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.connection.name,
                      style: AppTypography.h2(),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.connection.email,
                      style: AppTypography.caption(color: tokens.inkMuted),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceSunken,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.connection.category,
                        style: AppTypography.caption(color: tokens.ink),
                      ),
                    ),
                  ],
                ),
              ),
              ConnectionScoreRing(score: widget.connection.bondScore, size: 58),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionScoreRing extends StatelessWidget {
  const ConnectionScoreRing({super.key, required this.score, this.size = 58});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF7C3AED);
    const green = Color(0xFF22C55E);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 4,
            color: const Color(0xFFEDE9FE),
          ),

          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
            color: purple,
          ),

          Text(
            '$score',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),

          Positioned(
            right: 3,
            bottom: 6,
            child: Text(
              '↗',
              style: TextStyle(
                color: green,
                fontSize: size * 0.22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
    final priorityColor = _recommendationPriorityColor(
      connection.bondScore,
      tokens,
    );

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
            backgroundImage: connectionAvatarImage(connection.avatar),
            child: connectionAvatarImage(connection.avatar) == null
                ? Text(
                    connection.avatar,
                    style: AppTypography.glyph(20, color: tokens.primary),
                  )
                : null,
          ),
          SizedBox(width: AppSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        connection.name,
                        style: AppTypography.h2(color: tokens.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: categoryColor(
                        connection.category,
                        tokens,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.space2),
                Text(
                  recommendation.reason,
                  style: AppTypography.bodyLg(color: tokens.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: AppSpacing.space2),
                Text(
                  recommendation.insight,
                  style: AppTypography.body(color: tokens.inkMuted),
                ),
                if (recommendation.action case final action?) ...[
                  SizedBox(height: AppSpacing.space2),
                  Text(
                    action,
                    style: AppTypography.body(color: tokens.primary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                  color: priorityColor.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  priority,
                  style: AppTypography.caption(color: priorityColor),
                ),
              ),
              SizedBox(height: AppSpacing.space3),
              BondRing(connection: connection, size: 56, showAvatar: false),
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
  return switch (category) {
    'Family' => tokens.categoryFamily,
    'Friends' => tokens.categoryFriends,
    'High School' => tokens.categoryHighSchool,
    'College' => tokens.categoryCollege,
    'Work' => tokens.categoryWork,
    _ => tokens.primary,
  };
}

class HeatmapCard extends StatelessWidget {
  const HeatmapCard({
    super.key,
    required this.connections,
    required this.interactions,
  });
  final List<Connection> connections;
  final List<CrmInteraction> interactions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const categories = [
      _HeatmapCategory(
        label: 'Family',
        icon: Icons.home_outlined,
        strength: 'Very Strong',
      ),
      _HeatmapCategory(
        label: 'Friends',
        icon: Icons.groups_2_outlined,
        strength: 'Strong',
      ),
      _HeatmapCategory(
        label: 'High School',
        icon: Icons.school_outlined,
        strength: 'Moderate',
      ),
      _HeatmapCategory(
        label: 'College',
        icon: Icons.work_outline,
        strength: 'Light',
      ),
      _HeatmapCategory(
        label: 'Work',
        icon: Icons.business_center_outlined,
        strength: 'Building',
      ),
    ];
    return CardBox(
      padding: EdgeInsets.all(AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.trending_up, color: tokens.primary),
              ),
              SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Heatmap by Category',
                      style: AppTypography.h2(),
                    ),
                    SizedBox(height: AppSpacing.space1),
                    Text(
                      'Your social activity over the last 12 months',
                      style: AppTypography.caption(color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space4),
          for (var i = 0; i < categories.length; i++) ...[
            _HeatmapRow(
              category: categories[i],
              count: connections
                  .where((c) => c.category == categories[i].label)
                  .length,
              color: categoryColor(categories[i].label, tokens),
              connections: connections,
              interactions: interactions,
              categoryLabel: categories[i].label,
            ),
            if (i != categories.length - 1)
              Divider(height: AppSpacing.space5, color: tokens.border),
          ],
        ],
      ),
    );
  }
}

class _HeatmapCategory {
  const _HeatmapCategory({
    required this.label,
    required this.icon,
    required this.strength,
  });

  final String label;
  final IconData icon;
  final String strength;
}

class _HeatmapRow extends StatelessWidget {
  const _HeatmapRow({
    required this.category,
    required this.count,
    required this.color,
    required this.connections,
    required this.interactions,
    required this.categoryLabel,
  });
  final _HeatmapCategory category;
  final int count;
  final Color color;
  final List<Connection> connections;
  final List<CrmInteraction> interactions;
  final String categoryLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(category.icon, color: color, size: 23),
        ),
        SizedBox(width: AppSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space1,
                children: [
                  Text(
                    category.label,
                    style: AppTypography.bodyLg(
                      color: tokens.ink,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '($count contact)',
                    style: AppTypography.caption(color: tokens.inkMuted),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      category.strength,
                      style: AppTypography.caption(
                        color: color,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.space3),
              Row(children: _buildMonthHeatmap(context)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMonthHeatmap(BuildContext context) {
    final tokens = context.tokens;
    final now = DateTime.now();

    // Build month buckets for the last 12 months (oldest first)
    final months = List<DateTime>.generate(12, (i) {
      final dt = DateTime(now.year, now.month - (11 - i), 1);
      return dt;
    });

    // Only count interactions for connections in this category.
    final categoryContactIds = this.connections
        .where((c) => c.category == categoryLabel)
        .map((c) => c.id)
        .toSet();

    final counts = Map<String, Set<String>>.fromEntries(
      months.map((m) => MapEntry(_monthKey(m), <String>{})),
    );

    for (final interaction in interactions) {
      if (!categoryContactIds.contains(interaction.contactId)) continue;
      final key = _monthKey(
        DateTime(interaction.date.year, interaction.date.month, 1),
      );
      if (counts.containsKey(key)) {
        counts[key]!.add(interaction.contactId);
      }
    }

    return months.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value;
      final count = counts[_monthKey(m)]?.length ?? 0;
      final activity = (i * 19 + category.label.length * 7) % 100;
      final muted = i > 8 && activity.isEven;

      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(
            left: i == 0 ? 0 : AppSpacing.space1,
            right: i == 11 ? 0 : AppSpacing.space1,
          ),
          child: Tooltip(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            textStyle: TextStyle(color: tokens.ink),
            message: '${DateFormat.MMM().format(m)}\n$count connections',
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: muted
                    ? tokens.surfaceSunken
                    : color.withValues(alpha: .35 + (activity % 55) / 100),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  String _monthKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
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

          final width = constraints.maxWidth;
          final isNarrow = width < _stackBelowWidth;
          final isLongTitle = title.length > _shortTitleMaxChars;

          if (isNarrow && isLongTitle) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [titleWidget, const SizedBox(height: 8), action!],
            );
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space5,
        vertical: AppSpacing.space4,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        title: Text(event.title, style: AppTypography.h2()),
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
    final tier = BondTier.from(score);
    final semanticLabel = 'Connection score: $score, ${tier.label}';

    return CardBox(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space5,
        vertical: AppSpacing.space6,
      ),
      child: Semantics(
        container: true,
        excludeSemantics:
            true, // Excludes inner BondRing semantics to avoid duplication
        label: semanticLabel,
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
              label: 'Bond score',
              size: 176,
              strokeWidth: 11,
            ),
            SizedBox(height: AppSpacing.space4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.space2,
              alignment: WrapAlignment.center,
              children: [
                Icon(Icons.trending_up, color: tokens.primary, size: 18),
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
  BondTier.close => 'Strong bond! Keep up the regular communication.',
  BondTier.steady => 'Steady ground — a quick check-in keeps it warm.',
  BondTier.drifting => 'It\'s been a while. A short hello goes a long way.',
};

// Recommendation callout interior text colors.
//
// These are intentionally hardcoded brown/gold. There is no semantic
// "on-recommendation" token in the system yet. If we keep this pattern
// long-term we should add tokens for these colors.
const Color _recommendationTitleColor = Color(0xFF7B4F12);
const Color _recommendationBodyColor = Color(0xFF6B4513);
const Color _recommendationIconColor = Color(0xFFB7791F);

class AiInsightsCard extends StatefulWidget {
  const AiInsightsCard({
    super.key,
    required this.connection,
    required this.insight,
    this.memorySummary,
    this.memory,
    this.initialSelectedTopic,
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

  /// Optional topic to select when opening from a topic-aware Home card.
  final String? initialSelectedTopic;

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
                    child: Text('AI Insights', style: AppTypography.h2()),
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
                      initialSelectedTopic: widget.initialSelectedTopic,
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
                        initialSelectedTopic: widget.initialSelectedTopic,
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
class _AiInsightsBody extends StatefulWidget {
  const _AiInsightsBody({
    required this.connection,
    required this.insight,
    required this.tier,
    required this.tokens,
    this.memorySummary,
    this.memory,
    this.initialSelectedTopic,
  });

  final Connection connection;
  final ContactInsight insight;
  final String? memorySummary;
  final MemoryDocument? memory;
  final String? initialSelectedTopic;
  final BondTier tier;
  final AppTokens tokens;

  @override
  State<_AiInsightsBody> createState() => _AiInsightsBodyState();
}

class _AiInsightsBodyState extends State<_AiInsightsBody> {
  late String? _selectedTopic = widget.initialSelectedTopic;

  @override
  Widget build(BuildContext context) {
    final topics = topicsForContact(widget.connection, widget.memory);
    final tokens = widget.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommendation callout
        Container(
          padding: EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: tokens.recommendationSurface,
            border: Border.all(color: tokens.recommendationBorder, width: 1.5),
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
                      style: AppTypography.h2(color: _recommendationTitleColor),
                    ),
                    SizedBox(height: AppSpacing.space1),
                    Text(
                      _bondEncouragement(widget.tier),
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
            Icon(Icons.person_outline, size: 20, color: tokens.primary),
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
          (widget.memorySummary != null &&
                  widget.memorySummary!.trim().isNotEmpty)
              ? widget.memorySummary!
              : '',
          style: AppTypography.body(color: tokens.inkMuted),
        ),
        SizedBox(height: AppSpacing.space5),
        // Conversation Topics
        Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 20, color: tokens.secondary),
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
                isSelected: _selectedTopic == topic,
                onTap: () {
                  setState(() {
                    _selectedTopic = _selectedTopic == topic ? null : topic;
                  });
                },
              ),
          ],
        ),
        SizedBox(height: AppSpacing.space3),
        Text(
          'Click any topic to see AI suggestions.',
          style: AppTypography.caption(color: tokens.inkSubtle),
        ),
        SizedBox(height: AppSpacing.space3),
        if (_selectedTopic != null)
          _InlineTopicDetails(
            topic: _selectedTopic!,
            category: widget.connection.category,
            contactName: widget.connection.name,
            contactId: widget.connection.id,
            memory: widget.memory,
          ),
      ],
    );
  }
}

class _InlineTopicDetails extends StatelessWidget {
  const _InlineTopicDetails({
    required this.topic,
    required this.category,
    required this.contactName,
    required this.contactId,
    required this.memory,
  });

  final String topic;
  final String category;
  final String contactName;
  final String contactId;
  final MemoryDocument? memory;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final suggestions = preferredSuggestionsForTopic(
      category: category,
      topic: topic,
      contactName: contactName,
      memory: memory,
    );
    final displaySuggestions = suggestions.isNotEmpty
        ? suggestions
        : const <TopicSuggestion>[
            TopicSuggestion(
              kind: TopicSuggestionKind.ask,
              text: 'Ask an open question about how they\'ve been',
            ),
          ];
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: AppSpacing.space3),
      padding: EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: tokens.recommendationSurface,
        border: Border.all(color: tokens.recommendationBorder, width: 1.2),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: tokens.secondary, size: 24),
              SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  topic,
                  style: AppTypography.h1().copyWith(
                    color: _recommendationTitleColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space4),
          for (final suggestion in displaySuggestions)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.space3),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.border.withOpacity(0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conversation Starter :',
                      style: AppTypography.h2(color: _recommendationTitleColor),
                    ),
                    SizedBox(height: AppSpacing.space1),
                    Text(
                      suggestion.text,
                      style: AppTypography.body(color: _recommendationBodyColor),
                    ),
                    SizedBox(height: AppSpacing.space3),
                    Text(
                      'Context :',
                      style: AppTypography.h2(color: _recommendationTitleColor),
                    ),
                    SizedBox(height: AppSpacing.space1),
                    Text(
                      suggestion.context ?? '',
                      style: AppTypography.body(color: _recommendationBodyColor),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({
    required this.topic,
    required this.onTap,
    this.isSelected = false,
  });
  final String topic;
  final VoidCallback onTap;
  final bool isSelected;

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
            color: isSelected ? const Color(0xFF9D6BFF) : tokens.topicAccent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF9D6BFF).withOpacity(0.22),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            topic,
            style: AppTypography.body(
              color: isSelected ? tokens.primaryOn : tokens.primaryOn,
            ).copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped, gradient floating action button used for "Update with AI"
/// on the contact profile screen (Pass 2 #035). Uses `tokens.aiGradient`
/// from #033, with an InkWell + Container shape so the gradient renders
/// (Flutter's FloatingActionButton.extended only accepts a single Color).
class AiActionFab extends StatelessWidget {
  const AiActionFab({
    super.key,
    required this.onTap,
    this.label = 'Update with AI',
  });
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
                    style: AppTypography.bodyLg(
                      color: tokens.primaryOn,
                    ).copyWith(fontWeight: FontWeight.w600),
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
