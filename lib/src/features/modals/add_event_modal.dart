import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/crm_widgets.dart';

String _contactAvatarGlyph(String avatar, String fullName) {
  final trimmed = avatar.trim();
  if (trimmed.isNotEmpty && !trimmed.startsWith('data:image/')) {
    return trimmed;
  }
  final words = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final initials = words.take(2).map((word) => word[0]).join();
  return initials.isNotEmpty ? initials : '?';
}

Future<PlannerEvent?> showAddEventModal(
  BuildContext context, {
  DateTime? initialDate,
  PlannerEvent? event,
}) {
  return showModalBottomSheet<PlannerEvent?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => AddEventModal(initialDate: initialDate, event: event),
  );
}

class AddEventModal extends ConsumerStatefulWidget {
  const AddEventModal({super.key, this.initialDate, this.event});
  final DateTime? initialDate;
  final PlannerEvent? event;

  @override
  ConsumerState<AddEventModal> createState() => _AddEventModalState();
}

class _AddEventModalState extends ConsumerState<AddEventModal> {
  static const _uuid = Uuid();

  late final title = TextEditingController(text: widget.event?.title ?? '');
  late final note = TextEditingController(text: widget.event?.note ?? '');
  late DateTime date =
      widget.event?.date ?? widget.initialDate ?? DateTime.now();
  late String? contactId = widget.event?.contactId;
  late String category =
      widget.event?.category ??
      ref.read(appControllerProvider).categories.first;
  late String eventType =
      widget.event?.eventType ??
      ref.read(appControllerProvider).eventTypes.first;
  late bool isAllDay = widget.event?.isAllDay ?? true;
  late TimeOfDay startTime = _timeFromMinutes(
    widget.event?.startTimeMinutes ?? 9 * 60,
  );
  late TimeOfDay endTime = _timeFromMinutes(
    widget.event?.endTimeMinutes ?? 10 * 60,
  );
  late bool isRecurring = widget.event?.isRecurring ?? false;
  late RecurrencePattern recurrencePattern =
      widget.event?.recurrencePattern ?? RecurrencePattern.weekly;

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  TimeOfDay _timeFromMinutes(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  int _minutesFromTime(TimeOfDay time) => time.hour * 60 + time.minute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(appControllerProvider);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.event == null ? 'Add Event' : 'Edit Event',
                    style: AppTypography.h1(
                      color: tokens.ink,
                    ).copyWith(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).maybePop();
                  },
                  icon: Icon(Icons.close, color: tokens.inkSubtle),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card 1: TITLE Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: tokens.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TITLE',
                    style: AppTypography.caption(color: tokens.inkSubtle)
                        .copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: title,
                    style: AppTypography.body(color: tokens.ink),
                    decoration: InputDecoration(
                      hintText: 'Event Title',
                      hintStyle: AppTypography.body(color: tokens.inkMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Date & Time Picker Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: tokens.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tokens.primaryTint,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          color: tokens.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDate(date),
                        style: AppTypography.body(
                          color: tokens.ink,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: tokens.primary,
                          foregroundColor: tokens.primaryOn,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: () async {
                          final picked = await showDialog<DateTime>(
                            context: context,
                            builder: (context) =>
                                _CustomDatePickerDialog(initialDate: date),
                          );
                          if (picked != null) setState(() => date = picked);
                        },
                        child: Text(
                          'Change',
                          style: TextStyle(
                            color: tokens.primaryOn,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isAllDay) ...[
                    Divider(color: tokens.border, height: 24, thickness: 1),
                    _EventTimeRow(
                      label: 'Start',
                      time: startTime,
                      onChanged: (value) => setState(() => startTime = value),
                    ),
                    const SizedBox(height: 12),
                    _EventTimeRow(
                      label: 'End',
                      time: endTime,
                      onChanged: (value) => setState(() => endTime = value),
                    ),
                  ],
                  Divider(color: tokens.border, height: 24, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Day',
                        style: AppTypography.body(
                          color: tokens.ink,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: isAllDay,
                        activeThumbColor: tokens.primary,
                        onChanged: (value) => setState(() => isAllDay = value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Selectors Card (Event Type, Link to Contact, Category)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: tokens.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: eventType,
                    style: AppTypography.body(color: tokens.ink),
                    decoration: InputDecoration(
                      labelText: 'EVENT TYPE',
                      labelStyle: AppTypography.caption(color: tokens.inkSubtle)
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    items: state.eventTypes
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => eventType = value ?? eventType),
                  ),
                  Divider(color: tokens.border, height: 24, thickness: 1),
                  DropdownButtonFormField<String?>(
                    initialValue: contactId,
                    isExpanded: true,
                    style: AppTypography.body(color: tokens.ink),
                    decoration: InputDecoration(
                      labelText: 'LINK TO CONTACT (OPTIONAL)',
                      labelStyle: AppTypography.caption(color: tokens.inkSubtle)
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No contact'),
                      ),
                      ...state.connections.map(
                        (person) => DropdownMenuItem<String?>(
                          value: person.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFFEDE9FE),
                                backgroundImage: connectionAvatarImage(
                                  person.avatar,
                                ),
                                child:
                                    connectionAvatarImage(person.avatar) == null
                                    ? Text(
                                        _contactAvatarGlyph(
                                          person.avatar,
                                          person.name,
                                        ),
                                        style: const TextStyle(fontSize: 11),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Flexible(child: Text(person.name)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      contactId = value;
                      Connection? contact;
                      for (final connection in state.connections) {
                        if (connection.id == value) contact = connection;
                      }
                      if (contact != null) category = contact.category;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: Repeat & Notes Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: tokens.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Repeat',
                        style: AppTypography.body(
                          color: tokens.ink,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: isRecurring,
                        activeThumbColor: tokens.primary,
                        onChanged: (value) =>
                            setState(() => isRecurring = value),
                      ),
                    ],
                  ),
                  if (isRecurring) ...[
                    Divider(color: tokens.border, height: 24, thickness: 1),
                    SegmentedButton<RecurrencePattern>(
                      segments: RecurrencePattern.values
                          .map(
                            (pattern) => ButtonSegment(
                              value: pattern,
                              label: Text(pattern.label),
                            ),
                          )
                          .toList(),
                      selected: {recurrencePattern},
                      onSelectionChanged: (value) {
                        setState(() => recurrencePattern = value.first);
                      },
                    ),
                  ],
                  Divider(color: tokens.border, height: 24, thickness: 1),
                  Text(
                    'NOTE',
                    style: AppTypography.caption(color: tokens.inkSubtle)
                        .copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: tokens.border),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: note,
                      maxLines: 3,
                      style: AppTypography.body(color: tokens.ink),
                      decoration: InputDecoration(
                        hintText: 'Add details here...',
                        hintStyle: AppTypography.body(color: tokens.inkMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: tokens.primaryOn,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: () async {
                  final cleanTitle = title.text.trim();
                  try {
                    await ref
                        .read(appControllerProvider.notifier)
                        .saveEvent(
                          PlannerEvent(
                            id: widget.event?.id ?? _uuid.v4(),
                            title: cleanTitle.isEmpty
                                ? 'New Event'
                                : cleanTitle,
                            contactId: contactId,
                            category: category,
                            date: date,
                            note: note.text.trim(),
                            eventType: eventType,
                            isAllDay: isAllDay,
                            startTimeMinutes: isAllDay
                                ? null
                                : _minutesFromTime(startTime),
                            endTimeMinutes: isAllDay
                                ? null
                                : _minutesFromTime(endTime),
                            isRecurring: isRecurring,
                            recurrencePattern: isRecurring
                                ? recurrencePattern
                                : null,
                          ),
                        );
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not save event. Try again.'),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Save Event',
                  style: TextStyle(
                    color: tokens.primaryOn,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (widget.event != null) ...[
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: tokens.danger,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                ),
                onPressed: () async {
                  try {
                    final deleted = await ref
                        .read(appControllerProvider.notifier)
                        .deleteEvent(widget.event!.id);
                    if (context.mounted) Navigator.pop(context, deleted);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not delete event. Try again.'),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Delete Event',
                  style: AppTypography.body(
                    color: tokens.danger,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _CustomDatePickerDialog extends ConsumerStatefulWidget {
  const _CustomDatePickerDialog({required this.initialDate});
  final DateTime initialDate;

  @override
  ConsumerState<_CustomDatePickerDialog> createState() =>
      _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState
    extends ConsumerState<_CustomDatePickerDialog> {
  late DateTime _selectedDate = widget.initialDate;
  late DateTime _currentMonth = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final allEvents = ref.watch(
      appControllerProvider.select((state) => state.events),
    );

    // 42-day continuous calendar grid logic
    final firstOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final offset = firstOfMonth.weekday % 7;
    final firstGridDate = firstOfMonth.subtract(Duration(days: offset));
    final gridDates = List.generate(
      42,
      (index) => firstGridDate.add(Duration(days: index)),
    );

    return Dialog(
      backgroundColor: tokens.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with month, year, and chevrons
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(_currentMonth),
                    style: AppTypography.h1(
                      color: tokens.ink,
                    ).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    });
                  },
                  icon: Icon(
                    Icons.chevron_left,
                    color: tokens.primary,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month + 1,
                      );
                    });
                  },
                  icon: Icon(
                    Icons.chevron_right,
                    color: tokens.primary,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Weekdays Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: AppTypography.caption(color: tokens.inkMuted)
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.05,
                              ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Calendar Grid (42 Days)
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final day = gridDates[index];
                  final isCurrentMonth = day.month == _currentMonth.month;
                  final isSelected = DateUtils.isSameDay(day, _selectedDate);
                  final isToday = DateUtils.isSameDay(day, DateTime.now());

                  final eventsOnDay = allEvents
                      .where((event) => DateUtils.isSameDay(event.date, day))
                      .toList();
                  final hasEvent = eventsOnDay.isNotEmpty;

                  Color? backgroundColor;
                  Color textColor;
                  Border? border;

                  if (isSelected) {
                    backgroundColor = tokens.primary;
                    textColor = tokens.primaryOn;
                  } else if (isToday) {
                    backgroundColor = tokens.primary.withValues(alpha: 0.08);
                    textColor = tokens.primary;
                    border = Border.all(color: tokens.primary, width: 1.5);
                  } else {
                    backgroundColor = Colors.transparent;
                    textColor = isCurrentMonth
                        ? tokens.ink
                        : tokens.inkSubtle.withValues(alpha: 0.5);
                  }

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = day;
                        // Keep month in sync if clicking prev/next month day
                        if (day.month != _currentMonth.month) {
                          _currentMonth = DateTime(day.year, day.month);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                        border: border,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: AppTypography.body(color: textColor)
                                .copyWith(
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 13,
                                ),
                          ),
                          const SizedBox(height: 1),
                          // Event indicator dot
                          Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: hasEvent
                                  ? (isSelected
                                        ? tokens.primaryOn
                                        : tokens.primary)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons Row (Cancel / OK)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: tokens.inkMuted,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.body(
                      color: tokens.inkMuted,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: tokens.primary,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                  ),
                  onPressed: () => Navigator.pop(context, _selectedDate),
                  child: Text(
                    'OK',
                    style: AppTypography.body(
                      color: tokens.primary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTimeRow extends StatelessWidget {
  const _EventTimeRow({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hour24 = time.hour;
    final minute = time.minute;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final minuteOptions = List<int>.generate(60, (index) => index);
    final keyPrefix = label.toLowerCase();

    return Row(
      children: [
        SizedBox(
          width: 44, // Align label width with QuietHoursDialog (44)
          child: Text(
            label,
            style: AppTypography.body(
              color: tokens.ink,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    key: Key('event-$keyPrefix-hour'),
                    value: hour12,
                    isDense: true,
                    style: AppTypography.body(color: tokens.ink),
                    dropdownColor: tokens.surfaceRaised,
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
                        _timeFor(hour12: value, minute: minute, period: period),
                      );
                    },
                  ),
                ),
                Text(':', style: AppTypography.body(color: tokens.ink)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: Key('event-$keyPrefix-minute'),
                    value: minute,
                    isDense: true,
                    style: AppTypography.body(color: tokens.ink),
                    dropdownColor: tokens.surfaceRaised,
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
                        _timeFor(hour12: hour12, minute: value, period: period),
                      );
                    },
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: Key('event-$keyPrefix-period'),
                    value: period,
                    isDense: true,
                    style: AppTypography.body(color: tokens.ink),
                    dropdownColor: tokens.surfaceRaised,
                    items: const [
                      DropdownMenuItem(value: 'AM', child: Text('AM')),
                      DropdownMenuItem(value: 'PM', child: Text('PM')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      onChanged(
                        _timeFor(hour12: hour12, minute: minute, period: value),
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

  TimeOfDay _timeFor({
    required int hour12,
    required int minute,
    required String period,
  }) {
    final isPm = period == 'PM';
    var hour24 = hour12 % 12;
    if (isPm) hour24 += 12;
    return TimeOfDay(hour: hour24, minute: minute);
  }
}
