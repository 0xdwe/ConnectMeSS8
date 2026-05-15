import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
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
    final state = ref.watch(appControllerProvider);
    final person = state.connections.firstWhere(
      (connection) => connection.id == contactId,
      orElse: () => throw Exception('Contact not found'),
    );
    final insight = state.contactInsightFor(contactId);
    final history = state.interactions
        .where((interaction) => interaction.contactId == contactId)
        .toList();
    
    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text(person.name, style: AppTypography.h2()),
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => showEditConnectionModal(context, person),
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header section with BondRing, name, category, and insight summary
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                // Row 1: BondRing + Name + Category dot
                Row(
                  children: [
                    BondRing(connection: person, size: 96),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: AppTypography.display(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: categoryColor(person.category, tokens),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                person.category,
                                style: AppTypography.caption(color: tokens.inkMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Row 2: Insight summary (subtle, no yellow border)
                Text(
                  insight.summary,
                  style: AppTypography.body(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Primary action: Update with AI
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('update-with-ai-button'),
              onPressed: () => context.push('/ai-update/${person.id}'),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Update with AI'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.primary,
                foregroundColor: tokens.primaryOn,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Relationship facts card
          RelationshipFactsCard(connection: person, insight: insight),
          // History section
          if (history.isNotEmpty) ...[
            SectionTitle('History'),
            for (final item in history)
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(item.type.icon, color: tokens.inkMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: AppTypography.bodyLg(),
                                ),
                              ),
                              if (item.source == InteractionSource.aiSuggested) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.primaryTint,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 12, color: tokens.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'AI',
                                        style: AppTypography.caption(color: tokens.primary).copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat.yMMMd().format(item.date)} • ${item.type.label}',
                            style: AppTypography.caption(color: tokens.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            // Warm empty state when no history
            const SizedBox(height: 24),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  "${person.name.split(' ').first}'s new \u2014 you'll fill this in over time.",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLg(color: tokens.inkMuted),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
