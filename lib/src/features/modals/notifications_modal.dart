import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                            subtitle: 'Delivered at 9:00 AM',
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
                          _Divider(),
                          _ReminderTimingRow(
                            menuKey: const Key('birthday-reminder-menu'),
                            icon: Icons.notifications_none,
                            title: 'Remind me',
                            value: preferences.birthdayReminderMinutes,
                            presets: const <int, String>{
                              0: 'On the birthday',
                              1440: '1 day before',
                              10080: '1 week before',
                            },
                            enabled:
                                controlsEnabled &&
                                preferences.birthdayReminders,
                            onChanged: (value) => _save(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .setBirthdayReminderMinutes(value),
                            ),
                            onCustom: () => _pickCustomReminder(
                              title: 'Custom birthday reminder',
                              initialMinutes:
                                  preferences.birthdayReminderMinutes == 0
                                  ? 1440
                                  : preferences.birthdayReminderMinutes,
                              onSave: (value) => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .setBirthdayReminderMinutes(value),
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
                          _ReminderTimingRow(
                            menuKey: const Key('default-reminder-menu'),
                            icon: Icons.schedule_outlined,
                            title: 'Default reminder',
                            value: preferences.defaultReminderMinutes,
                            presets: const <int, String>{
                              15: '15 minutes before',
                              60: '1 hour before',
                              1440: '1 day before',
                              2880: '2 days before',
                            },
                            enabled:
                                controlsEnabled && preferences.plannerReminders,
                            onChanged: (value) => _save(
                              () => ref
                                  .read(
                                    notificationPreferencesProvider.notifier,
                                  )
                                  .setDefaultReminderMinutes(value),
                            ),
                            onCustom: () => _pickCustomReminder(
                              title: 'Custom planner reminder',
                              initialMinutes:
                                  preferences.defaultReminderMinutes,
                              onSave: (value) => ref
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
                            key: const Key('quiet-hours-switch'),
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
    final selection = await showDialog<_QuietHoursSelection>(
      context: context,
      builder: (context) => _QuietHoursDialog(
        initialStartMinutes: preferences.quietStartMinutes,
        initialEndMinutes: preferences.quietEndMinutes,
      ),
    );
    if (selection == null || !mounted) return;
    await _save(
      () => ref
          .read(notificationPreferencesProvider.notifier)
          .setQuietHours(
            startMinutes: selection.startMinutes,
            endMinutes: selection.endMinutes,
          ),
    );
  }

  Future<void> _pickCustomReminder({
    required String title,
    required int initialMinutes,
    required Future<void> Function(int value) onSave,
  }) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) =>
          _CustomReminderDialog(title: title, initialMinutes: initialMinutes),
    );
    if (minutes == null || !mounted) return;
    await _save(() => onSave(minutes));
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

class _ReminderTimingRow extends StatelessWidget {
  const _ReminderTimingRow({
    required this.menuKey,
    required this.icon,
    required this.title,
    required this.value,
    required this.presets,
    required this.enabled,
    required this.onChanged,
    required this.onCustom,
  });

  final Key menuKey;
  final IconData icon;
  final String title;
  final int value;
  final Map<int, String> presets;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = presets[value] ?? _formatReminderLead(value);
    return _ActionRow(
      icon: icon,
      title: title,
      subtitle: label,
      enabled: enabled,
      trailing: PopupMenuButton<int>(
        key: menuKey,
        enabled: enabled,
        tooltip: 'Choose reminder time',
        initialValue: presets.containsKey(value) ? value : null,
        onSelected: (selection) {
          if (selection == -1) {
            onCustom();
          } else {
            onChanged(selection);
          }
        },
        itemBuilder: (context) => [
          for (final entry in presets.entries)
            PopupMenuItem<int>(value: entry.key, child: Text(entry.value)),
          const PopupMenuDivider(),
          const PopupMenuItem<int>(value: -1, child: Text('Custom')),
        ],
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.space2,
            vertical: AppSpacing.space2,
          ),
          child: Icon(
            Icons.expand_more,
            color: enabled ? tokens.inkMuted : tokens.inkSubtle,
          ),
        ),
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
    return InkWell(
      key: const Key('quiet-hours-editor-row'),
      onTap: enabled ? onTap : null,
      child: _ActionRow(
        icon: Icons.access_time,
        title: 'Custom schedule',
        subtitle: '$start to $end',
        enabled: enabled,
        trailing: Icon(
          Icons.chevron_right,
          color: enabled ? tokens.primary : tokens.inkSubtle,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final Widget trailing;

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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tokens.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: enabled ? tokens.primary : tokens.inkSubtle,
              size: 21,
            ),
          ),
          SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    color: enabled ? tokens.ink : tokens.inkSubtle,
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
          trailing,
        ],
      ),
    );
  }
}

enum _ReminderUnit {
  minutes('Minutes', 1),
  hours('Hours', 60),
  days('Days', 24 * 60),
  weeks('Weeks', 7 * 24 * 60);

  const _ReminderUnit(this.label, this.multiplier);

  final String label;
  final int multiplier;
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog({
    required this.title,
    required this.initialMinutes,
  });

  final String title;
  final int initialMinutes;

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  late final TextEditingController _amountController;
  late _ReminderUnit _unit;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _unit = _bestUnit(widget.initialMinutes);
    _amountController = TextEditingController(
      text: (widget.initialMinutes ~/ _unit.multiplier).toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      key: const Key('custom-reminder-dialog'),
      backgroundColor: tokens.surfaceRaised,
      title: Text(
        widget.title,
        style: AppTypography.glyph(
          22,
          color: tokens.ink,
          weight: FontWeight.w700,
        ),
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: const Key('custom-reminder-amount'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Amount',
                errorText: _errorText,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.space3),
          DropdownButton<_ReminderUnit>(
            key: const Key('custom-reminder-unit'),
            value: _unit,
            items: [
              for (final unit in _ReminderUnit.values)
                DropdownMenuItem<_ReminderUnit>(
                  value: unit,
                  child: Text(unit.label),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _unit = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final amount = int.tryParse(_amountController.text);
    final minutes = amount == null ? null : amount * _unit.multiplier;
    if (minutes == null ||
        !NotificationPreferences.isValidReminderMinutes(minutes)) {
      setState(() {
        _errorText = 'Choose a time from 1 minute to 1 year';
      });
      return;
    }
    Navigator.of(context).pop(minutes);
  }

  _ReminderUnit _bestUnit(int minutes) {
    for (final unit in _ReminderUnit.values.reversed) {
      if (minutes >= unit.multiplier && minutes % unit.multiplier == 0) {
        return unit;
      }
    }
    return _ReminderUnit.minutes;
  }
}

class _QuietHoursSelection {
  const _QuietHoursSelection({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;
}

class _QuietHoursDialog extends StatefulWidget {
  const _QuietHoursDialog({
    required this.initialStartMinutes,
    required this.initialEndMinutes,
  });

  final int initialStartMinutes;
  final int initialEndMinutes;

  @override
  State<_QuietHoursDialog> createState() => _QuietHoursDialogState();
}

class _QuietHoursDialogState extends State<_QuietHoursDialog> {
  late int _startMinutes;
  late int _endMinutes;

  @override
  void initState() {
    super.initState();
    _startMinutes = widget.initialStartMinutes;
    _endMinutes = widget.initialEndMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      key: const Key('quiet-hours-dialog'),
      backgroundColor: tokens.surfaceRaised,
      insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      title: Text(
        'Quiet hours',
        style: AppTypography.glyph(
          22,
          color: tokens.ink,
          weight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuietTimeRow(
              keyPrefix: 'quiet-hours-start',
              label: 'Start',
              minutes: _startMinutes,
              onChanged: (value) => setState(() => _startMinutes = value),
            ),
            SizedBox(height: AppSpacing.space4),
            _QuietTimeRow(
              keyPrefix: 'quiet-hours-end',
              label: 'End',
              minutes: _endMinutes,
              onChanged: (value) => setState(() => _endMinutes = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _QuietHoursSelection(
              startMinutes: _startMinutes,
              endMinutes: _endMinutes,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _QuietTimeRow extends StatelessWidget {
  const _QuietTimeRow({
    required this.keyPrefix,
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final minuteOptions = List<int>.generate(60, (index) => index);

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: AppTypography.body(
              color: tokens.ink,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: AppSpacing.space3),
        Expanded(
          child: Container(
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.space3),
            decoration: BoxDecoration(
              color: tokens.surfaceSunken,
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: Key('$keyPrefix-hour'),
                    value: hour12,
                    isDense: true,
                    items: [
                      for (var hour = 1; hour <= 12; hour++)
                        DropdownMenuItem<int>(
                          value: hour,
                          child: Text('$hour'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      onChanged(
                        _minutesFor(
                          hour12: value,
                          minute: minute,
                          period: period,
                        ),
                      );
                    },
                  ),
                ),
                Text(':', style: AppTypography.body(color: tokens.ink)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: Key('$keyPrefix-minute'),
                    value: minute,
                    isDense: true,
                    items: [
                      for (final value in minuteOptions)
                        DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString().padLeft(2, '0')),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      onChanged(
                        _minutesFor(
                          hour12: hour12,
                          minute: value,
                          period: period,
                        ),
                      );
                    },
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: Key('$keyPrefix-period'),
                    value: period,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'AM', child: Text('AM')),
                      DropdownMenuItem(value: 'PM', child: Text('PM')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      onChanged(
                        _minutesFor(
                          hour12: hour12,
                          minute: minute,
                          period: value,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _minutesFor({
    required int hour12,
    required int minute,
    required String period,
  }) {
    final hour24 = hour12 % 12 + (period == 'PM' ? 12 : 0);
    return hour24 * 60 + minute;
  }
}

String _formatReminderLead(int minutes) {
  if (minutes == 0) return 'On the birthday';
  if (minutes % (7 * 24 * 60) == 0) {
    final weeks = minutes ~/ (7 * 24 * 60);
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} before';
  }
  if (minutes % (24 * 60) == 0) {
    final days = minutes ~/ (24 * 60);
    return '$days ${days == 1 ? 'day' : 'days'} before';
  }
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} before';
  }
  return '$minutes minutes before';
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
