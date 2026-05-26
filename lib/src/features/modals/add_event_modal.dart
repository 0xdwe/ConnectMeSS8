import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

Future<PlannerEvent?> showAddEventModal(
  BuildContext context, {
  DateTime? initialDate,
  PlannerEvent? event,
}) {
  return showModalBottomSheet<PlannerEvent?>(
    context: context,
    isScrollControlled: true,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.event == null ? 'Add Event' : 'Edit Event',
                    style: AppTypography.h1(),
                  ),
                ),
                IconButton(
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Event Title'),
            ),
            SizedBox(height: AppSpacing.space2),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_formatDate(date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => date = picked);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All Day'),
              value: isAllDay,
              onChanged: (value) => setState(() => isAllDay = value),
            ),
            if (!isAllDay) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) setState(() => startTime = picked);
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text('Start ${startTime.format(context)}'),
                    ),
                  ),
                  SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) setState(() => endTime = picked);
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text('End ${endTime.format(context)}'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.space2),
            ],
            DropdownButtonFormField<String>(
              initialValue: eventType,
              decoration: const InputDecoration(labelText: 'Event Type'),
              items: state.eventTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => eventType = value ?? eventType),
            ),
            SizedBox(height: AppSpacing.space2),
            DropdownButtonFormField<String?>(
              initialValue: contactId,
              decoration: const InputDecoration(
                labelText: 'Link to Contact (Optional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No contact'),
                ),
                ...state.connections.map(
                  (person) => DropdownMenuItem<String?>(
                    value: person.id,
                    child: Text(person.name),
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
            SizedBox(height: AppSpacing.space2),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: state.categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => category = value ?? category),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repeat'),
              value: isRecurring,
              onChanged: (value) => setState(() => isRecurring = value),
            ),
            if (isRecurring) ...[
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
              SizedBox(height: AppSpacing.space2),
            ],
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            SizedBox(height: AppSpacing.space4),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: tokens.primary),
              onPressed: () async {
                final cleanTitle = title.text.trim();
                try {
                  await ref
                      .read(appControllerProvider.notifier)
                      .saveEvent(
                        PlannerEvent(
                          id: widget.event?.id ?? _uuid.v4(),
                          title: cleanTitle.isEmpty ? 'New Event' : cleanTitle,
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
                      const SnackBar(content: Text('Could not save event. Try again.')),
                    );
                  }
                }
              },
              child: const Text('Save Event'),
            ),
            if (widget.event != null) ...[
              SizedBox(height: AppSpacing.space2),
              TextButton.icon(
                onPressed: () async {
                  try {
                    final deleted = await ref
                        .read(appControllerProvider.notifier)
                        .deleteEvent(widget.event!.id);
                    if (context.mounted) Navigator.pop(context, deleted);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not delete event. Try again.')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Event'),
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
