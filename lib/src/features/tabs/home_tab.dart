import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../state/memory/memory_providers.dart';
import '../../state/query_providers.dart';
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
    final allRecs = ref.watch(recommendationsProvider);
    final recs = showAll ? allRecs : allRecs.take(2).toList();
    return ListView(
      key: const Key('home-tab'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space6,
        AppSpacing.space5,
        AppSpacing.pageBottomPadding + 40,
      ),
      children: [
        ConnectionScoreHero(score: state.averageConnectionScore),
        SizedBox(height: AppSpacing.space4),
        CardBox(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space3,
            AppSpacing.space3,
            AppSpacing.space2,
            AppSpacing.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: AppSpacing.space2),
                child: SectionTitle(
                  'Top Recommendations',
                  titleStyle: AppTypography.bodyLg().copyWith(fontWeight: FontWeight.w800),
                  action: Padding(
                    padding: EdgeInsets.only(left: AppSpacing.space3),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.space2,
                          vertical: AppSpacing.space1,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => context.push('/recommendations'),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(
                        'View All',
                        style: AppTypography.bodyLg().copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      iconAlignment: IconAlignment.end,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.space4),
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
                for (var i = 0; i < recs.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final contact = ref.watch(contactByIdProvider(recs[i].contactId));
                      if (contact == null) return const SizedBox.shrink();
                      return RecommendationCard(
                        key: Key('recommendation-card-${recs[i].contactId}'),
                        connection: contact,
                        recommendation: recs[i],
                        onTap: () => context.push('/contact/${recs[i].contactId}'),
                      );
                    },
                  ),
                  if (i < recs.length - 1) SizedBox(height: AppSpacing.space3),
                ],
                if (!showAll)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => showAll = true),
                      child: const Text('Expand recommendations'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
