import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
import '../theme/app_tokens.dart';
import '../widgets/crm_widgets.dart';
import 'modals/edit_connection_modal.dart';

class ContactProfileScreen extends ConsumerWidget {
  const ContactProfileScreen({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(appControllerProvider);
    final person = state.connections.firstWhere(
      (connection) => connection.id == contactId,
    );
    final insight = state.contactInsightFor(contactId);
    final history = state.interactions
        .where((interaction) => interaction.contactId == contactId)
        .toList();
    return Scaffold(
      backgroundColor: tokens.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: tokens.primary,
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
                      IconButton.filledTonal(
                        tooltip: 'Edit',
                        onPressed: () =>
                            showEditConnectionModal(context, person),
                        icon: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: tokens.surfaceRaised,
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
                              style: TextStyle(
                                color: tokens.primaryOn,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              person.email,
                              style: TextStyle(
                                color: tokens.primaryOn,
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('update-with-ai-button'),
                      onPressed: () =>
                          context.push('/ai-update/${person.id}'),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Update with AI'),
                    ),
                  ),
                ),
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
                        subtitle: Text(
                          '${DateFormat.yMMMd().format(item.date)} • ${item.note}',
                        ),
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
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, color: tokens.primaryOn, size: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Back',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.primaryOn,
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
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: tokens.primary,
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
          Row(
            children: [
              Icon(Icons.trending_up, color: tokens.primaryOn),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Bond Score',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.primaryOn,
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
            style: TextStyle(
              color: tokens.primaryOn,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Strong connection!',
            style: TextStyle(
              color: tokens.primaryOn,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
