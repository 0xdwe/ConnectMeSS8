import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/notifications/notification_gateway.dart';
import '../../state/notifications/notification_preferences.dart';
import '../../state/notifications/notification_preferences_controller.dart';
import '../../state/notifications/notification_providers.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

Future<void> showNotificationsModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const NotificationsModal(),
  );
}

class NotificationsModal extends ConsumerStatefulWidget {
  const NotificationsModal({super.key});

  @override
  ConsumerState<NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends ConsumerState<NotificationsModal> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final preferences = ref.watch(notificationPreferencesProvider);
    final permission = ref.watch(notificationPermissionProvider);
    final controlsEnabled = preferences.enabled && !_saving;

    return SafeArea(
      top: false,
      child: SizedBox(
        key: const Key('notifications-modal'),
        height: MediaQuery.sizeOf(context).height * .9,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          child: Material(
            color: tokens.surfaceSunken,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    AppSpacing.space3,
                    AppSpacing.space3,
                    AppSpacing.space2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: AppTypography.glyph(
                            28,
                            color: tokens.ink,
                            weight: FontWeight.w700,
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
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.space4,
                      AppSpacing.space2,
                      AppSpacing.space4,
                      AppSpacing.space6,
                    ),
                    children: [
                      _SwitchRow(
                        key: const Key('notifications-master-switch'),
                        icon: Icons.notifications_active_outlined,
                        title: 'Allow notifications',
                        subtitle: 'Reminders and gentle check-ins',
                        value: preferences.enabled,
                        enabled: !_saving,
                        onChanged: _setMasterEnabled,
                      ),
                      if (preferences.enabled &&
                          permission == NotificationPermissionState.denied) ...[
                        SizedBox(height: AppSpacing.space3),
                        _PermissionWarning(
                          onOpenSettings: () => ref
                              .read(notificationPermissionProvider.notifier)
                              .openSystemSettings(),
                        ),
                      ],
                      SizedBox(height: AppSpacing.space5),
                      _SectionLabel(label: 'RELATIONSHIPS'),
                      SizedBox(height: AppSpacing.space2),
                      _SectionSurface(
                        children: [
                          _SwitchRow(
                            icon: Icons.favorite_border,
                            title: 'Suggested check-ins',
                            subtitle:
                                'A gentle nudge when someone may appreciate it',
                            value: preferences.suggestedCheckIns,
                            enabled: controlsEnabled,
                            onChanged: (value) => _save(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .setSuggestedCheckIns(value),
                            ),
                          ),
                          _Divider(),
                          _SwitchRow(
                            icon: Icons.cake_outlined,
                            title: 'Birthday reminders',
                            subtitle: 'At 9:00 AM on the birthday',
                            value: preferences.birthdayReminders,
                            enabled: controlsEnabled,
                            onChanged: (value) => _save(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .setBirthdayReminders(value),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.space5),
                      _SectionLabel(label: 'PLANNER'),
                      SizedBox(height: AppSpacing.space2),
                      _SectionSurface(
                        children: [
                          _SwitchRow(
                            icon: Icons.event_available_outlined,
                            title: 'Planner reminders',
                            subtitle: 'Before scheduled events',
                            value: preferences.plannerReminders,
                            enabled: controlsEnabled,
                            onChanged: (value) => _save(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .setPlannerReminders(value),
                            ),
                          ),
                          _Divider(),
                          _ReminderLeadRow(
                            value: preferences.defaultReminderMinutes,
                            enabled:
                                controlsEnabled && preferences.plannerReminders,
                            onChanged: (value) => _save(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .setDefaultReminderMinutes(value),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.space5),
                      _SectionLabel(label: 'DELIVERY'),
                      SizedBox(height: AppSpacing.space2),
                      _SectionSurface(
                        children: [
                          _SwitchRow(
                            icon: Icons.bedtime_outlined,
                            title: 'Quiet hours',
                            subtitle: preferences.quietHoursEnabled
                                ? _quietHoursLabel(preferences)
                                : 'Deliver notifications normally',
                            value: preferences.quietHoursEnabled,
                            enabled: controlsEnabled,
                            onChanged: (value) => _save(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .setQuietHoursEnabled(value),
                            ),
                          ),
                          if (preferences.quietHoursEnabled) ...[
                            _Divider(),
                            _QuietHoursRow(
                              preferences: preferences,
                              enabled: controlsEnabled,
                              onTap: () => _pickQuietHours(preferences),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setMasterEnabled(bool value) async {
    await _save(() async {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setEnabled(value);
      if (value) {
        await ref.read(notificationPermissionProvider.notifier).request();
      }
    });
  }

  Future<void> _pickQuietHours(NotificationPreferences preferences) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(preferences.quietStartMinutes),
      helpText: 'Quiet hours start',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _timeOfDay(preferences.quietEndMinutes),
      helpText: 'Quiet hours end',
    );
    if (end == null) return;
    await _save(
      () => ref
          .read(notificationPreferencesProvider.notifier)
          .setQuietHours(
            startMinutes: start.hour * 60 + start.minute,
            endMinutes: end.hour * 60 + end.minute,
          ),
    );
  }

  Future<void> _save(Future<void> Function() operation) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update notifications. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TimeOfDay _timeOfDay(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  String _quietHoursLabel(NotificationPreferences preferences) {
    final start = _timeOfDay(preferences.quietStartMinutes).format(context);
    final end = _timeOfDay(preferences.quietEndMinutes).format(context);
    return '$start to $end';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Text(
      label,
      style: AppTypography.caption(
        color: tokens.primary,
      ).copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final foreground = enabled ? tokens.ink : tokens.inkSubtle;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tokens.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tokens.primary, size: 21),
          ),
          SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    color: foreground,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppSpacing.space1),
                Text(
                  subtitle,
                  style: AppTypography.caption(
                    color: enabled ? tokens.inkMuted : tokens.inkSubtle,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.space2),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _ReminderLeadRow extends StatelessWidget {
  const _ReminderLeadRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  static const labels = <int, String>{
    15: '15 minutes',
    60: '1 hour',
    1440: '1 day',
    2880: '2 days',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_outlined,
            color: enabled ? tokens.primary : tokens.inkSubtle,
          ),
          SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text(
              'Default reminder',
              style: AppTypography.body(
                color: enabled ? tokens.ink : tokens.inkSubtle,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              onChanged: enabled
                  ? (next) {
                      if (next != null) onChanged(next);
                    }
                  : null,
              items: [
                for (final entry in labels.entries)
                  DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietHoursRow extends StatelessWidget {
  const _QuietHoursRow({
    required this.preferences,
    required this.enabled,
    required this.onTap,
  });

  final NotificationPreferences preferences;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final start = TimeOfDay(
      hour: preferences.quietStartMinutes ~/ 60,
      minute: preferences.quietStartMinutes % 60,
    ).format(context);
    final end = TimeOfDay(
      hour: preferences.quietEndMinutes ~/ 60,
      minute: preferences.quietEndMinutes % 60,
    ).format(context);
    return ListTile(
      enabled: enabled,
      leading: const Icon(Icons.access_time),
      title: const Text('Set quiet hours'),
      subtitle: Text('$start to $end'),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled ? onTap : null,
      textColor: tokens.ink,
      iconColor: tokens.primary,
    );
  }
}

class _PermissionWarning extends StatelessWidget {
  const _PermissionWarning({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: tokens.secondary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.secondary.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined, color: tokens.secondary),
          SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications are blocked on this device',
                  style: AppTypography.body(
                    color: tokens.ink,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppSpacing.space1),
                Text(
                  'Allow them in system settings to receive reminders.',
                  style: AppTypography.caption(color: tokens.inkMuted),
                ),
                TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(color: context.tokens.border, height: 1, indent: 68);
}
