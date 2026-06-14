import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/social_models.dart';
import '../state/memory/memory_providers.dart';
import '../state/query_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';

@visibleForTesting
String recommendationContactRoute(Recommendation recommendation) {
  final topic = recommendation.topic;
  final reason = recommendation.reason;
  final insight = recommendation.insight;
  final action = recommendation.action;
  final params = <String, String>{};
  if (topic != null && topic.trim().isNotEmpty) {
    params['topic'] = topic;
  }
  if (reason.trim().isNotEmpty) params['reason'] = reason;
  if (insight.trim().isNotEmpty) params['insight'] = insight;
  if (action != null && action.trim().isNotEmpty) {
    params['action'] = action;
  }
  return Uri(
    path: '/contact/${recommendation.contactId}',
    queryParameters: params.isEmpty ? null : params,
  ).toString();
}

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final recommendations = ref.watch(recommendationsProvider);
    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text('Outreach Recommendations', style: AppTypography.h2()),
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.space6),
        children: [
          recommendations.when(
            loading: () => const _RecommendationLoadingPlaceholders(
              key: Key('recommendations-screen-loading'),
              count: 3,
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) => Column(
              children: [
                for (final recommendation in items)
                  Builder(
                    builder: (context) {
                      final contact = ref.watch(
                        contactByIdProvider(recommendation.contactId),
                      );
                      if (contact == null) return const SizedBox.shrink();
                      return RecommendationCard(
                        key: Key(
                          'recommendation-card-${recommendation.contactId}',
                        ),
                        connection: contact,
                        recommendation: recommendation,
                        onTap: () => context.push(
                          recommendationContactRoute(recommendation),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
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
            key: Key('recommendations-screen-loading-placeholder-$i'),
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
