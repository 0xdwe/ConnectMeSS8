import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../theme/app_theme.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: const Color(0xFFF5F6F7), child: child);
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.onProfileTap});
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.fromLTRB(32, 22, 22, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔗', style: TextStyle(fontSize: 38)),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Connect Me',
              style: TextStyle(
                color: AppTheme.moss,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          InkWell(
            key: const Key('profile-button'),
            borderRadius: BorderRadius.circular(40),
            onTap: onProfileTap,
            child: const CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFE0F0F0),
              child: Text('👤', style: TextStyle(fontSize: 32)),
            ),
          ),
        ],
      ),
    );
  }
}

class TealPageHeader extends StatelessWidget {
  const TealPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.backLabel,
  });
  final String title;
  final String? subtitle;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.moss,
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 34),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: Navigator.of(context).pop,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, color: Colors.white, size: 34),
                  const SizedBox(width: 12),
                  Text(
                    backLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
              color: const Color(0xFFE6E9ED),
            ),
          ),
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: stroke,
              color: AppTheme.moss,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(fontSize: size * .28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class BigScoreCircle extends StatelessWidget {
  const BigScoreCircle({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        children: [
          const Text(
            'Connection Score',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          ScoreRing(score: score, size: 150, stroke: 14),
          const SizedBox(height: 10),
          const Text(
            'Average personal bond score',
            style: TextStyle(color: Colors.black54),
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
    this.padding = const EdgeInsets.all(24),
    this.border,
  });
  final Widget child;
  final EdgeInsets padding;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: border,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
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
    return CardBox(
      padding: const EdgeInsets.all(24),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFE0F0F0),
              child: Text(
                connection.avatar,
                style: const TextStyle(fontSize: 30),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.name,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    connection.email,
                    style: const TextStyle(
                      fontSize: 21,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      connection.category,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF1F1F1),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
            ScoreRing(score: connection.bondScore, size: 72, stroke: 7),
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
    this.highlight = false,
  });
  final Connection connection;
  final Recommendation recommendation;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final high = recommendation.priority.startsWith('high');
    final low = recommendation.priority.startsWith('low');
    final color = high
        ? AppTheme.clay
        : low
        ? AppTheme.moss
        : const Color(0xFFB26B42);
    return CardBox(
      border: highlight ? Border.all(color: AppTheme.moss, width: 1.5) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFE0F0F0),
            child: Text(
              connection.avatar,
              style: const TextStyle(fontSize: 30),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.error_outline, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recommendation.reason,
                        style: const TextStyle(
                          fontSize: 22,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFBF8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '💬  "${recommendation.insight}"',
                    style: const TextStyle(
                      color: AppTheme.moss,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  children: [
                    Chip(label: Text(connection.category)),
                    Chip(
                      label: Text(recommendation.priority),
                      backgroundColor: color,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      side: BorderSide.none,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              ScoreRing(score: connection.bondScore),
              const SizedBox(height: 8),
              const Text(
                'Score',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeatmapCard extends StatelessWidget {
  const HeatmapCard({super.key, required this.connections});
  final List<Connection> connections;

  static const colors = {
    'Family': Color(0xFFA855F7),
    'Friends': Color(0xFF22C55E),
    'High School': Color(0xFFF97316),
    'College': Color(0xFF3B82F6),
    'Work': AppTheme.moss,
  };

  @override
  Widget build(BuildContext context) {
    final categories = ['Family', 'Friends', 'High School', 'College', 'Work'];
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: AppTheme.moss),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connection Heatmap by Category',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Your social activity patterns over months',
            style: TextStyle(
              fontSize: 22,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          for (final category in categories)
            _HeatmapRow(
              category: category,
              count: connections.where((c) => c.category == category).length,
              color: colors[category]!,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 9, backgroundColor: color),
              const SizedBox(width: 14),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '  ($count contact)',
                style: const TextStyle(fontSize: 20, color: Color(0xFF667085)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(12, (i) {
              final active = (i * 19 + category.length * 7) % 100;
              return Expanded(
                child: Container(
                  height: 56,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .35 + (active % 60) / 100),
                    borderRadius: BorderRadius.circular(10),
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
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
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
    required this.contact,
    this.onDelete,
  });
  final PlannerEvent event;
  final Connection contact;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => CardBox(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        event.title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        DateFormat('yyyy-MM-dd').format(event.date),
        style: const TextStyle(
          fontSize: 22,
          color: Color(0xFF4B5563),
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(contact.avatar, style: const TextStyle(fontSize: 28)),
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

class RecommendedActionCard extends StatelessWidget {
  const RecommendedActionCard({super.key, required this.insight});
  final ContactInsight insight;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.all(0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9583),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Recommended Action!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can gain ${insight.potentialScoreGain}% Connection Score',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              insight.recommendedAction,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
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
    return CardBox(
      border: Border.all(color: const Color(0xFFFFE45C), width: 1.5),
      child: InkWell(
        key: const Key('ai-insight-card'),
        onTap: () => setState(() => expanded = !expanded),
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFF9A5A00)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Insight',
                    style: TextStyle(
                      color: Color(0xFF7A3F00),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(Icons.expand_more, color: Color(0xFF9A5A00)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.insight.summary,
              style: const TextStyle(
                color: Color(0xFF8A4B00),
                fontSize: 20,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 14),
              Text(
                widget.insight.why,
                key: const Key('ai-insight-why'),
                style: const TextStyle(
                  color: Color(0xFF6B3A00),
                  fontSize: 16,
                  height: 1.35,
                ),
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
              const SizedBox(width: 16),
              Expanded(
                child: _Fact(
                  label: 'Known Since',
                  value: '${insight.knownSinceYears} years',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF4B5563),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Last contact: ${DateFormat('yyyy-MM-dd').format(connection.lastContact)}',
                  style: const TextStyle(
                    fontSize: 19,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w700,
                  ),
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          color: Color(0xFF4B5563),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(
          fontSize: 23,
          color: Colors.black,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class CommunicationChannelsCard extends StatelessWidget {
  const CommunicationChannelsCard({super.key, required this.channels});
  final List<String> channels;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppTheme.moss),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Top Communication Channels',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final channel in channels)
                Chip(
                  label: Text(
                    channel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  backgroundColor: AppTheme.moss,
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
          const Text(
            'Interaction Frequency (12 months)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(12, (index) {
              final alpha = 0.35 + (values[index] / maxValue) * 0.55;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      key: Key('frequency-bar-$index'),
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.moss.withValues(alpha: alpha),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w700,
                      ),
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
  Widget build(BuildContext context) => CardBox(
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 42, color: AppTheme.moss),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class GradientScaffold extends AppSurface {
  const GradientScaffold({super.key, required super.child});
}
