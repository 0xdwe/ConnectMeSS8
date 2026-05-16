import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../state/app_state.dart';
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
        padding: EdgeInsets.all(AppSpacing.space4),
        children: [
          // Header section with BondRing, name, category, and insight summary
          Container(
            padding: EdgeInsets.all(AppSpacing.space5),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                // Row 1: BondRing + Name + Category dot
                Row(
                  children: [
                    BondRing(connection: person, size: 96),
                    SizedBox(width: AppSpacing.space5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: AppTypography.display(),
                          ),
                          SizedBox(height: AppSpacing.space2),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: categoryColor(person.category, tokens),
                              ),
                              SizedBox(width: AppSpacing.space2),
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
                SizedBox(height: AppSpacing.space4),
                // Row 2: Insight summary (subtle, no yellow border)
                Text(
                  insight.summary,
                  style: AppTypography.body(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.space4),
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
          SizedBox(height: AppSpacing.space4),
          // Relationship facts card
          RelationshipFactsCard(connection: person, insight: insight),
          // History section
          if (history.isNotEmpty) ...[
            SectionTitle('History'),
            for (final item in history)
              CardBox(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space3),
                child: Row(
                  children: [
                    Icon(item.type.icon, color: tokens.inkMuted),
                    SizedBox(width: AppSpacing.space3),
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
                                SizedBox(width: AppSpacing.space2),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.space1, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.primaryTint,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 12, color: tokens.primary),
                                      SizedBox(width: AppSpacing.space1),
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
                          SizedBox(height: AppSpacing.space1),
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
            SizedBox(height: AppSpacing.space5),
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
            SizedBox(height: AppSpacing.space5),
          ],
        ],
      ),
    );
  }
}
