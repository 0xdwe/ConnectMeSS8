import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../state/firebase_providers.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/crm_widgets.dart';
import '../edit_profile_screen.dart';
import '../modals/about_modal.dart';
import '../modals/manage_categories_modal.dart';
import '../modals/manage_event_types_modal.dart';
import '../modals/notifications_modal.dart';
import '../modals/theme_modal.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final themeMode = ref.watch(
      appControllerProvider.select((state) => state.themeMode),
    );

    String themeModeLabel;
    switch (themeMode) {
      case AppThemeMode.light:
        themeModeLabel = 'Light';
        break;
      case AppThemeMode.dark:
        themeModeLabel = 'Dark';
        break;
      case AppThemeMode.system:
        themeModeLabel = 'System';
        break;
    }

    return ListView(
      key: const Key('settings-tab'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space6,
        AppSpacing.space5,
        AppSpacing.pageBottomPadding,
      ),
      children: [
        // ─── ACCOUNT ─────────────────────────────────────
        _SectionHeader(label: 'ACCOUNT'),
        SizedBox(height: AppSpacing.space2),
        CardBox(
          padding: EdgeInsets.zero,
          border: Border.all(color: tokens.border, width: 1),
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.person_outline,
                iconColor: tokens.primary,
                label: 'Edit Profile',
                onTap: () => EditProfileScreen.navigateTo(context),
              ),
              Divider(color: tokens.border, height: 1, indent: 68),
              _SettingsRow(
                icon: Icons.notifications_none,
                iconColor: tokens.secondary,
                label: 'Notifications',
                onTap: () => showNotificationsModal(context),
              ),
              Divider(color: tokens.border, height: 1, indent: 68),
              _SettingsRow(
                icon: Icons.shield_outlined,
                iconColor: tokens.categoryWork,
                label: 'Privacy & Security',
                onTap: () => _info(context, 'Privacy controls placeholder'),
              ),
              Divider(color: tokens.border, height: 1, indent: 68),
              _SettingsRow(
                icon: Icons.delete_outline,
                iconColor: tokens.danger,
                label: 'Remove sample friends',
                onTap: () => _confirmRemoveSamples(context, ref),
              ),
            ],
          ),
        ),

        SizedBox(height: AppSpacing.space6),

        // ─── CUSTOMIZATION ───────────────────────────────
        _SectionHeader(label: 'CUSTOMIZATION'),
        SizedBox(height: AppSpacing.space2),
        CardBox(
          padding: EdgeInsets.zero,
          border: Border.all(color: tokens.border, width: 1),
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.palette_outlined,
                iconColor: tokens.primary,
                label: 'Theme',
                trailing: themeModeLabel,
                onTap: () => showThemeModal(context),
              ),
              Divider(color: tokens.border, height: 1, indent: 68),
              _SettingsRow(
                icon: Icons.sell_outlined,
                iconColor: tokens.primary,
                label: 'Manage Categories',
                onTap: () => showManageCategoriesModal(context),
              ),
              Divider(color: tokens.border, height: 1, indent: 68),
              _SettingsRow(
                icon: Icons.event_note_outlined,
                iconColor: tokens.primary,
                label: 'Manage Event Types',
                onTap: () => showManageEventTypesModal(context),
              ),
            ],
          ),
        ),

        SizedBox(height: AppSpacing.space6),

        // ─── ABOUT ───────────────────────────────────────
        _SectionHeader(label: 'ABOUT'),
        SizedBox(height: AppSpacing.space2),
        CardBox(
          padding: EdgeInsets.zero,
          border: Border.all(color: tokens.border, width: 1),
          child: _SettingsRow(
            icon: Icons.info_outline,
            iconColor: tokens.primary,
            label: 'About Connect Me',
            onTap: () => showAboutBottomSheet(context),
          ),
        ),

        SizedBox(height: AppSpacing.space8),

        // ─── SIGN OUT ────────────────────────────────────
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: tokens.danger,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: Icon(Icons.logout, size: 18, color: tokens.danger),
            onPressed: () async {
              try {
                await ref.read(firebaseAuthProvider).signOut();
              } catch (_) {}
              if (!context.mounted) return;
              ref.read(appControllerProvider.notifier).signOut();
              context.go('/auth');
            },
            label: Text(
              'Sign out',
              style: AppTypography.body(
                color: tokens.danger,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.space3),
        Center(
          child: Text(
            'Connect Me v3.0',
            textAlign: TextAlign.center,
            style: AppTypography.caption(color: tokens.inkMuted),
          ),
        ),
      ],
    );
  }

  void _info(BuildContext context, String message) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('OK'),
        ),
      ],
    ),
  );

  void _confirmRemoveSamples(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove sample friends?', style: AppTypography.h1()),
        content: Text(
          'Remove the 5 sample friends and their interactions?',
          style: AppTypography.body(),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref
                    .read(appControllerProvider.notifier)
                    .removeSampleConnections();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample friends removed')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not remove sample friends. Try again.',
                      ),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: tokens.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ─── Section header (e.g. "ACCOUNT", "CUSTOMIZATION", "ABOUT") ──────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: AppTypography.caption(color: tokens.primary).copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Settings row with colored icon circle, label, optional trailing ─────
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // Colored icon in a soft-tint circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Label
            Expanded(
              child: Text(
                label,
                style: AppTypography.body(
                  color: tokens.ink,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            // Optional trailing text (e.g. "Light" for theme)
            if (trailing != null) ...[
              Text(
                trailing!,
                style: AppTypography.caption(
                  color: tokens.inkMuted,
                ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              const SizedBox(width: 4),
            ],
            // Chevron
            Icon(Icons.chevron_right, color: tokens.inkSubtle, size: 20),
          ],
        ),
      ),
    );
  }
}
