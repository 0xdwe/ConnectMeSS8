import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../state/memory/memory_providers.dart';
import '../../state/query_providers.dart';
import '../modals/update_person_picker_modal.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/crm_widgets.dart';

@visibleForTesting
String contactRouteForRecommendation(Recommendation recommendation) =>
    _contactRouteForRecommendation(recommendation);

String _contactRouteForRecommendation(Recommendation recommendation) {
  final topic = recommendation.topic;
  final params = <String, String>{};
  if (topic != null && topic.trim().isNotEmpty) {
    params['topic'] = topic;
  }
  return Uri(
    path: '/contact/${recommendation.contactId}',
    queryParameters: params.isEmpty ? null : params,
  ).toString();
}

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final recommendations = ref.watch(recommendationsProvider);
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
        DailyNudgeCard(
          onTap: () {
            showUpdatePersonPickerModal(context);
          },
        ),
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
                  titleStyle: AppTypography.bodyLg().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
              recommendations.when(
                loading: () => const _RecommendationLoadingPlaceholders(
                  key: Key('home-recommendations-loading'),
                  count: 2,
                ),
                error: (_, _) => _SampleRecommendations(),
                data: (allRecs) {
                  final recs = showAll ? allRecs : allRecs.take(2).toList();
                  if (recs.isEmpty) {
                    return _SampleRecommendations();
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < recs.length; i++) ...[
                        Builder(
                          builder: (context) {
                            final contact = ref.watch(
                              contactByIdProvider(recs[i].contactId),
                            );
                            if (contact == null) {
                              return const SizedBox.shrink();
                            }
                            return RecommendationCard(
                              key: Key(
                                'recommendation-card-${recs[i].contactId}',
                              ),
                              connection: contact,
                              recommendation: recs[i],
                              onTap: () => context.push(
                                _contactRouteForRecommendation(recs[i]),
                              ),
                            );
                          },
                        ),
                        if (i < recs.length - 1)
                          SizedBox(height: AppSpacing.space3),
                      ],
                      if (!showAll)
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() => showAll = true),
                            child: const Text('Expand recommendations'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SampleRecommendations extends StatelessWidget {
  const _SampleRecommendations();

  @override
  Widget build(BuildContext context) {
    final sampleConnections = [
      Connection(
        id: 'david',
        name: 'David Kim',
        email: 'david.k@email.com',
        category: 'Family',
        avatar: '👨‍👩‍👧',
        bondScore: 95,
        nextStep: 'Ask about family dinner plans',
        lastContact: DateTime.now().subtract(const Duration(days: 4)),
        notes: 'Family anchor. Likes weekend updates.',
        knownSince: DateTime(1998, 5, 1),
        preferredChannels: const ['Text', 'Phone', 'FaceTime'],
        isSample: true,
      ),
      Connection(
        id: 'emily',
        name: 'Emily Rodriguez',
        email: 'emily.r@email.com',
        category: 'Work',
        avatar: '👩‍💼',
        bondScore: 85,
        nextStep: 'Ask about first week in new role',
        lastContact: DateTime.now().subtract(const Duration(days: 5)),
        notes: 'First week at new role. Keep momentum going.',
        knownSince: DateTime(2023, 9, 1),
        preferredChannels: const ['Slack', 'Email', 'Text'],
        isSample: true,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < sampleConnections.length; i++) ...[
          RecommendationCard(
            connection: sampleConnections[i],
            recommendation: Recommendation(
              contactId: sampleConnections[i].id,
              reason: 'Curious how ${sampleConnections[i].name} is doing?',
              insight: 'Last chat was a few weeks ago.',
              priority: 'medium priority',
            ),
          ),
          if (i < sampleConnections.length - 1)
            SizedBox(height: AppSpacing.space3),
        ],
      ],
    );
  }
}

class _RecommendationLoadingPlaceholders extends StatelessWidget {
  const _RecommendationLoadingPlaceholders({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(
            key: Key('recommendation-loading-placeholder-$i'),
            height: 88,
            decoration: BoxDecoration(
              color: tokens.surfaceSunken,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.space4),
                child: Text(
                  'Loading recommendations…',
                  style: AppTypography.body(color: tokens.inkMuted),
                ),
              ),
            ),
          ),
          if (i < count - 1) SizedBox(height: AppSpacing.space3),
        ],
      ],
    );
  }
}
