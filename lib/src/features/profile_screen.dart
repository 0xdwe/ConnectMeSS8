import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';
import 'modals/edit_user_profile_modal.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(appControllerProvider);
    final user = state.user;
    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text('Profile', style: AppTypography.h2()),
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
        actions: [
          IconButton(
            onPressed: () => showEditUserProfileModal(context),
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(26),
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 66,
                  backgroundColor: tokens.primaryTint,
                  child: Text(
                    user.avatar,
                    style: AppTypography.glyph(54),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  user.name,
                  style: AppTypography.display(),
                ),
                const SizedBox(height: 12),
                Text(
                  user.email,
                  style: AppTypography.h2(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CardBox(
                  child: Column(
                    children: [
                      Text(
                        '${state.averageConnectionScore}',
                        style: AppTypography.glyph(
                          46,
                          color: tokens.primary,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Connection Score',
                        style: AppTypography.h2(color: tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: CardBox(
                  child: Column(
                    children: [
                      Text(
                        '${state.connections.length}',
                        style: AppTypography.glyph(
                          46,
                          color: tokens.secondary,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Total Connections',
                        style: AppTypography.h2(color: tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          HeatmapCard(connections: state.connections),
        ],
      ),
    );
  }
}
