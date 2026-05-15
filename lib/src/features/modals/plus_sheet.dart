import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import 'add_connection_modal.dart';
import 'add_event_modal.dart';
import 'update_person_picker_modal.dart';

Future<void> showPlusSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _PlusSheet(),
  );
}

class _PlusSheet extends StatelessWidget {
  const _PlusSheet();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: AppSpacing.space5),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlusSheetAction(
              icon: Icons.person_add_alt_1_outlined,
              iconColor: tokens.inkMuted,
              label: 'Add Connection',
              onTap: () {
                Navigator.pop(context);
                showAddConnectionModal(context);
              },
            ),
            _PlusSheetAction(
              icon: Icons.auto_awesome,
              iconColor: tokens.primary,
              backgroundColor: tokens.primaryTint,
              label: 'Update Connection',
              caption: 'Paste a chat, AI will categorize.',
              onTap: () {
                Navigator.pop(context);
                showUpdatePersonPickerModal(context);
              },
            ),
            _PlusSheetAction(
              icon: Icons.event_outlined,
              iconColor: tokens.inkMuted,
              label: 'Plan Event',
              onTap: () {
                Navigator.pop(context);
                showAddEventModal(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusSheetAction extends StatelessWidget {
  const _PlusSheetAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final String label;
  final String? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.space5),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyLg(color: tokens.ink),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      style: AppTypography.caption(color: tokens.inkMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
