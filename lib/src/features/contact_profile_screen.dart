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
    final memorySummary = memoryAsync.when(
      data: (doc) => doc.summary.trim().isEmpty ? null : doc.summary,
      // Loading and error fall back to the legacy ContactInsight path
      // for now (#050 deletes the fallback once the memory data path
      // is proven). Returning null here triggers the fallback inside
      // AiInsightsCard.
      loading: () => null,
      error: (_, _) => null,
    );
    
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
          // Header section: BondRing left, name + Edit pill on the
          // first row, then category and facts strip below. Edit pill is
          // a structural sibling of the name Expanded — never overlays.
          Container(
            padding: EdgeInsets.all(AppSpacing.space5),
            decoration: BoxDecoration(
              color: tokens.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BondRing(connection: person, size: 96),
                SizedBox(width: AppSpacing.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 4,
                            backgroundColor:
                                categoryColor(person.category, tokens),
                          ),
                          SizedBox(width: AppSpacing.space2),
                          Text(
                            person.category,
                            style:
                                AppTypography.caption(color: tokens.inkMuted),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.space2),
                      Text(
                        '${insight.relationshipLabel} · known ${insight.knownSinceYears} years · last contact ${DateFormat.yMMMd().format(person.lastContact)}',
                        style: AppTypography.caption(color: tokens.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          ),
          // History section (Pass 2 #036): one CardBox holding either a
          // dense list of interactions separated by border dividers, or
          // a warm empty state when there is no history.
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
                      Text('History', style: AppTypography.h2()),
                      if (history.isNotEmpty) ...[
                        SizedBox(width: AppSpacing.space2),
                        Text(
                          '(${history.length})',
                          style: AppTypography.caption(
                              color: tokens.inkMuted),
                        ),
                      ],
                    ],
                  ),
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
                        children: [
                          Icon(
                            history[i].type.icon,
                            color: tokens.inkMuted,
                            size: 20,
                          ),
                          SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: Text(
                              history[i].title,
                              style: AppTypography.bodyLg(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: AppSpacing.space3),
                          Text(
                            DateFormat.yMMMd().format(history[i].date),
                            style: AppTypography.caption(
                                color: tokens.inkMuted),
                          ),
                          if (history[i].source ==
                              InteractionSource.aiSuggested) ...[
                            SizedBox(width: AppSpacing.space2),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.space2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.primaryTint,
                                borderRadius: BorderRadius.circular(
                                    AppRadius.sm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 11,
                                    color: tokens.primary,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'AI',
                                    style: AppTypography.caption(
                                            color: tokens.primary)
                                        .copyWith(
                                            fontSize: 10, height: 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
