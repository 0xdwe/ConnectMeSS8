import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/crm_widgets.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(appControllerProvider);
    final recs = showAll ? state.recommendations : state.recommendations.take(2).toList();
    return ListView(
      key: const Key('home-tab'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.pageBottomPadding,
      ),
      children: [
        ConnectionScoreHero(score: state.averageConnectionScore),
        SectionTitle('Today\'s Recommendation', action: TextButton(onPressed: () => context.push('/recommendations'), child: Text('View All ->', style: AppTypography.bodyLg().copyWith(fontWeight: FontWeight.w600)))),
        if (recs.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.space8),
              child: Text(
                'You\'re in touch with everyone right now.',
                style: AppTypography.bodyLg(color: tokens.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          for (var i = 0; i < recs.length; i++)
            RecommendationCard(
              key: Key('recommendation-card-${recs[i].contactId}'),
              connection: state.connections.firstWhere(
                (c) => c.id == recs[i].contactId,
              ),
              recommendation: recs[i],
              onTap: () => context.push('/contact/${recs[i].contactId}'),
            ),
          if (!showAll) Center(child: TextButton(onPressed: () => setState(() => showAll = true), child: const Text('Expand recommendations'))),
        ],
      ],
    );
  }
}
