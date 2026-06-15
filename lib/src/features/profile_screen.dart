import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../state/user_profile/user_profile_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';
import '../widgets/account_avatar.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(appControllerProvider);
    final profile = ref.watch(accountProfileProvider);
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
      body: AppSurface(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.space6),
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.space6),
              decoration: BoxDecoration(
                gradient: tokens.cardGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: tokens.border),
                boxShadow: AppTokens.elevation1(dark),
              ),
              child: Column(
                children: [
                  AccountAvatar(
                    profile: profile,
                    radius: 66,
                    glyphSize: 54,
                    backgroundColor: tokens.surfaceRaised,
                  ),
                  SizedBox(height: AppSpacing.space5),
                  Text(
                    profile?.name ?? 'Your profile',
                    style: AppTypography.display(color: tokens.ink),
                  ),
                  SizedBox(height: AppSpacing.space3),
                  Text(
                    profile?.email ?? '',
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
            HeatmapCard(
              connections: state.connections,
              interactions: state.interactions,
            ),
          ],
        ),
      ),
    );
  }
}
