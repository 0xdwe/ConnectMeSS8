import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../widgets/crm_widgets.dart';

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      body: Column(children: [
        const TealPageHeader(title: 'Outreach Recommendations', subtitle: 'AI-suggested contacts to reconnect with', backLabel: 'Back to Home'),
        Expanded(child: ListView(padding: const EdgeInsets.all(26), children: [
          for (var i = 0; i < state.recommendations.length; i++) RecommendationCard(key: Key('recommendation-card-${state.recommendations[i].contactId}'), connection: state.connections.firstWhere((c) => c.id == state.recommendations[i].contactId), recommendation: state.recommendations[i], highlight: i == 1, onTap: () => context.push('/contact/${state.recommendations[i].contactId}')),
        ])),
      ]),
    );
  }
}
