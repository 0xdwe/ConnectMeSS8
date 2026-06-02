import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

Future<void> showThemeModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ThemeModal(),
  );
}

class ThemeModal extends ConsumerWidget {
  const ThemeModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final mode = ref.watch(
      appControllerProvider.select((state) => state.themeMode),
    );
    final controller = ref.read(appControllerProvider.notifier);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          child: Material(
            color: tokens.surfaceSunken,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space3,
                AppSpacing.space4,
                AppSpacing.space6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Theme',
                          style: AppTypography.glyph(
                            30,
                            color: tokens.ink,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: Navigator.of(context).pop,
                        icon: Icon(Icons.close, color: tokens.ink),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.space2),
                  Text(
                    'Match system follows your device. Light and dark are explicit.',
                    style: AppTypography.bodyLg(color: tokens.ink),
                  ),
                  SizedBox(height: AppSpacing.space5),
                  _ThemeOptionCard(
                    key: const Key('theme-mode-system'),
                    title: 'Match system',
                    subtitle: 'Syncs with your device settings',
                    icon: Icons.contrast_outlined,
                    iconColor: tokens.primary,
                    iconBackground: tokens.primaryTint,
                    selected: mode == AppThemeMode.system,
                    onTap: () => controller.setThemeMode(AppThemeMode.system),
                  ),
                  SizedBox(height: AppSpacing.space3),
                  _ThemeOptionCard(
                    key: const Key('theme-mode-light'),
                    title: 'Always light',
                    subtitle: 'Clean and bright visual style',
                    icon: Icons.wb_sunny_outlined,
                    iconColor: tokens.secondary,
                    iconBackground: tokens.secondary.withValues(alpha: .14),
                    selected: mode == AppThemeMode.light,
                    onTap: () => controller.setThemeMode(AppThemeMode.light),
                  ),
                  SizedBox(height: AppSpacing.space3),
                  _ThemeOptionCard(
                    key: const Key('theme-mode-dark'),
                    title: 'Always dark',
                    subtitle: 'Easy on the eyes in low light',
                    icon: Icons.dark_mode_outlined,
                    iconColor: tokens.primary,
                    iconBackground: tokens.primaryTint,
                    selected: mode == AppThemeMode.dark,
                    onTap: () => controller.setThemeMode(AppThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? tokens.primary.withValues(alpha: .36)
                  : tokens.border,
            ),
          ),
          child: Row(
            children: [
              _ThemeIcon(
                icon: icon,
                color: iconColor,
                background: iconBackground,
              ),
              SizedBox(width: AppSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyLg(
                        color: tokens.ink,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: AppSpacing.space1),
                    Text(
                      subtitle,
                      style: AppTypography.caption(color: tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.space3),
              _SelectionDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeIcon extends StatelessWidget {
  const _ThemeIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? tokens.primary : Colors.transparent,
        border: Border.all(
          color: selected ? tokens.primary : tokens.border,
          width: selected ? 0 : 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: tokens.primaryOn,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
