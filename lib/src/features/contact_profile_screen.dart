import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_widgets.dart';
import 'modals/edit_connection_modal.dart';

class ContactProfileScreen extends ConsumerWidget {
  const ContactProfileScreen({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final person = state.connections.firstWhere(
      (connection) => connection.id == contactId,
    );
    final insight = state.contactInsightFor(contactId);
    final history = state.interactions
        .where((interaction) => interaction.contactId == contactId)
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppTheme.moss,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _HeaderBackButton(onTap: Navigator.of(context).pop),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            onPressed: () =>
                                showEditConnectionModal(context, person),
                            icon: const Icon(Icons.edit),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () =>
                                context.push('/ai-update/${person.id}'),
                            icon: const Icon(Icons.auto_awesome),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white,
                        child: Text(
                          person.avatar,
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              person.email,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 430;
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BondScorePanel(score: person.bondScore),
                          RecommendedActionCard(insight: insight),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _BondScorePanel(score: person.bondScore),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RecommendedActionCard(insight: insight),
                        ),
                      ],
                    );
                  },
                ),
                InsightCard(insight: insight),
                RelationshipFactsCard(connection: person, insight: insight),
                CommunicationChannelsCard(channels: insight.preferredChannels),
                InteractionFrequencyCard(
                  frequencyByMonth: insight.frequencyByMonth,
                ),
                if (history.isNotEmpty) ...[
                  SectionTitle('History'),
                  for (final item in history)
                    CardBox(
                      child: ListTile(
                        leading: Icon(item.type.icon),
                        title: Text(item.title),
                        subtitle: Text(item.note),
                      ),
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

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, color: Colors.white, size: 32),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Back',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BondScorePanel extends StatelessWidget {
  const _BondScorePanel({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.moss,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Colors.white),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Bond Score',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Strong connection!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
