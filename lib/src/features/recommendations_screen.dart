import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
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
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text('Outreach Recommendations', style: AppTypography.h2()),
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
      ),
      body: ListView(padding: EdgeInsets.all(AppSpacing.space6), children: [
        for (var i = 0; i < state.recommendations.length; i++)
          Builder(
            builder: (context) {
              final contact = ref.watch(
                contactByIdProvider(state.recommendations[i].contactId),
              );
              if (contact == null) return const SizedBox.shrink();
              return RecommendationCard(
                key: Key(
                  'recommendation-card-${state.recommendations[i].contactId}',
                ),
                connection: contact,
                recommendation: state.recommendations[i],
                onTap: () =>
                    context.push('/contact/${state.recommendations[i].contactId}'),
              );
            },
          ),
      ]),
    );
  }
}
