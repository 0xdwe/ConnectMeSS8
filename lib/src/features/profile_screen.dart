import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';

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
            onPressed: () => EditProfileScreen.navigateTo(context),
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.space6),
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.space6),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                UserAvatar(
                  user: user,
                  radius: 66,
                  glyphSize: 54,
                  backgroundColor: tokens.primaryTint,
                ),
                SizedBox(height: AppSpacing.space5),
                Text(
                  user.name,
                  style: AppTypography.display(),
                ),
                SizedBox(height: AppSpacing.space3),
                Text(
                  user.email,
                  style: AppTypography.h2(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.space5),
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
              SizedBox(width: AppSpacing.space5),
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
          SizedBox(height: AppSpacing.space5),
          HeatmapCard(connections: state.connections),
        ],
      ),
    );
  }
}
