import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../state/user_profile/user_profile_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/account_avatar.dart';
import '../../widgets/crm_widgets.dart';
import '../edit_profile_screen.dart';

class YouTab extends ConsumerWidget {
  const YouTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(appControllerProvider);
    final profile = ref.watch(accountProfileProvider);

    return ListView(
      key: const Key('you-tab'),
      padding: EdgeInsets.only(bottom: AppSpacing.pageBottomPadding),
      children: [
        _YouHero(
          profile: profile,
          onEditProfile: () => EditProfileScreen.navigateTo(context),
          onSettings: () => context.push('/settings'),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space4,
            AppSpacing.space5,
            AppSpacing.space4,
            0,
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final cards = [
                    _MetricCard(
                      icon: Icons.trending_up,
                      value: '${state.averageConnectionScore}',
                      label: 'Connection Score',
                      helper: "You're doing great!",
                      accent: tokens.primary,
                    ),
                    _MetricCard(
                      icon: Icons.groups_2_outlined,
                      value: '${state.connections.length}',
                      label: 'Total Connections',
                      helper: 'In your network',
                      accent: tokens.secondary,
                    ),
                  ];
                  if (compact) {
                    return Column(children: cards);
                  }
                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      SizedBox(width: AppSpacing.space4),
                      Expanded(child: cards[1]),
                    ],
                  );
                },
              ),
              SizedBox(height: AppSpacing.space3),
              HeatmapCard(
                connections: state.connections,
                interactions: state.interactions,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YouHero extends StatelessWidget {
  const _YouHero({
    required this.profile,
    required this.onEditProfile,
    required this.onSettings,
  });

  final AccountProfile? profile;
  final VoidCallback onEditProfile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        MediaQuery.paddingOf(context).top + AppSpacing.space3,
        AppSpacing.space5,
        AppSpacing.space6,
      ),
      decoration: BoxDecoration(
        gradient: tokens.cardGradient,
        border: Border(bottom: BorderSide(color: tokens.border)),
        boxShadow: AppTokens.elevation1(dark),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              _HeroIconButton(
                icon: Icons.settings_outlined,
                onPressed: onSettings,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space1),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.surfaceRaised.withValues(alpha: .9),
                    width: 3,
                  ),
                ),
                child: AccountAvatar(
                  profile: profile,
                  radius: 50,
                  glyphSize: 42,
                  backgroundColor: tokens.surfaceRaised,
                ),
              ),
              Positioned(
                right: -2,
                bottom: 4,
                child: Material(
                  color: tokens.surfaceRaised.withValues(alpha: .96),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEditProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: tokens.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space4),
          Text(
            profile?.name ?? 'Your profile',
            textAlign: TextAlign.center,
            style: AppTypography.h1(color: tokens.ink),
          ),
          SizedBox(height: AppSpacing.space1),
          Text(
            profile?.email ?? '',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLg(color: tokens.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.surfaceRaised.withValues(alpha: .72),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Settings',
        onPressed: onPressed,
        icon: Icon(icon, color: tokens.primary),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.helper,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final String helper;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CardBox(
      padding: EdgeInsets.all(AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              SizedBox(width: AppSpacing.space3),
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.glyph(
                    42,
                    color: accent,
                    weight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space4),
          Text(
            label,
            style: AppTypography.bodyLg(
              color: tokens.ink,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AppSpacing.space1),
          Text(helper, style: AppTypography.caption(color: tokens.inkMuted)),
        ],
      ),
    );
  }
}
