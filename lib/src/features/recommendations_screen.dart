import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/memory/memory_providers.dart';
import '../state/query_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';

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
      body: ListView(padding: EdgeInsets.all(AppSpacing.space6), children: [
        for (final recommendation in recommendations)
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
                onTap: () =>
                    context.push('/contact/${recommendation.contactId}'),
              );
            },
          ),
      ]),
    );
  }
}
