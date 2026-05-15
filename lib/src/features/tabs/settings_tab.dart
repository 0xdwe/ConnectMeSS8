import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/crm_widgets.dart';
import '../modals/edit_user_profile_modal.dart';
import '../modals/manage_categories_modal.dart';
import '../modals/manage_event_types_modal.dart';
import '../modals/theme_modal.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final headerStyle = AppTypography.h2(color: tokens.inkMuted);
    return ListView(
      key: const Key('settings-tab'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.pageBottomPadding,
      ),
      children: [
        Text('Account', style: headerStyle),
        SizedBox(height: AppSpacing.space3),
        CardBox(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Row(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                onTap: () => showEditUserProfileModal(context),
              ),
              _Row(
                icon: Icons.notifications_none,
                label: 'Notifications',
                onTap: () => _info(context, 'Notifications mock settings'),
              ),
              _Row(
                icon: Icons.shield_outlined,
                label: 'Privacy & Security',
                onTap: () => _info(context, 'Privacy controls placeholder'),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.space5),
        Text('Customization', style: headerStyle),
        SizedBox(height: AppSpacing.space3),
        CardBox(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Row(
                icon: Icons.palette_outlined,
                label: 'Theme',
                onTap: () => showThemeModal(context),
              ),
              _Row(
                icon: Icons.sell_outlined,
                label: 'Manage Categories',
                onTap: () => showManageCategoriesModal(context),
              ),
              _Row(
                icon: Icons.event_note_outlined,
                label: 'Manage Event Types',
                onTap: () => showManageEventTypesModal(context),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.space5),
        Text('About', style: headerStyle),
        SizedBox(height: AppSpacing.space3),
        CardBox(
          padding: EdgeInsets.zero,
          child: _Row(
            icon: Icons.info_outline,
            label: 'About Connect Me',
            onTap: () =>
                _info(context, 'Connect Me v3.0\nMaking relationships matter'),
          ),
        ),
        SizedBox(height: AppSpacing.space8),
        Center(
          child: Text(
            'Connect Me v3.0\nMaking relationships matter',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLg(color: tokens.inkMuted),
          ),
        ),
        SizedBox(height: AppSpacing.space5),
        TextButton(
          onPressed: () {
            ref.read(appControllerProvider.notifier).signOut();
            context.go('/auth');
          },
          child: const Text('Sign out'),
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
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 32),
    title: Text(
      label,
      style: AppTypography.h2(),
    ),
    trailing: const Icon(Icons.chevron_right, size: 32),
    minVerticalPadding: 22,
    onTap: onTap,
  );
}
