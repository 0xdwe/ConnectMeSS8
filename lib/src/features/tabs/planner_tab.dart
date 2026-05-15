import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/crm_widgets.dart';
import '../modals/add_event_modal.dart';

class PlannerTab extends ConsumerStatefulWidget {
  const PlannerTab({super.key});

  @override
  ConsumerState<PlannerTab> createState() => _PlannerTabState();
}

class _PlannerTabState extends ConsumerState<PlannerTab> {
  DateTime month = DateTime(2026, 4);
  DateTime selected = DateTime(2026, 4, 27);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final selectedEvents = state.events
        .where((event) => DateUtils.isSameDay(event.date, selected))
        .toList();
    return ListView(
      key: const Key('planner-tab'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.pageBottomPadding,
      ),
      children: [
        SwitchListTile(
          value: state.googleCalendarLinked,
          onChanged: ref
              .read(appControllerProvider.notifier)
              .toggleGoogleCalendar,
          title: Text(
            'Google Calendar connected',
            style: AppTypography.bodyLg(),
          ),
          subtitle: Text(
            'Mock sync boundary. OAuth later.',
            style: AppTypography.body(),
          ),
        ),
        CardBox(
          child: _CalendarGrid(
            month: month,
            selected: selected,
            events: state.events,
            onPrev: () =>
                setState(() => month = DateTime(month.year, month.month - 1)),
            onNext: () =>
                setState(() => month = DateTime(month.year, month.month + 1)),
            onSelect: (day) => setState(() => selected = day),
          ),
        ),
        SectionTitle(
          'Upcoming Events',
          action: TextButton(
            onPressed: () => showAddEventModal(context, initialDate: selected),
            child: const Text('Create'),
          ),
        ),
        if (selectedEvents.isNotEmpty) ...[
          Text(
            'Selected day: ${DateFormat.yMMMd().format(selected)}',
            style: AppTypography.bodyLg(),
          ),
          SizedBox(height: AppSpacing.space2),
          for (final event in selectedEvents)
            EventTile(
              event: event,
              contact: _contactFor(state, event.contactId),
              onTap: () => _editEvent(context, event),
              onDelete: () => _deleteWithUndo(context, event.id),
            ),
        ],
        for (final event in [
          ...state.events,
        ]..sort((a, b) => a.date.compareTo(b.date)))
          EventTile(
            event: event,
            contact: _contactFor(state, event.contactId),
            onTap: () => _editEvent(context, event),
            onDelete: () => _deleteWithUndo(context, event.id),
          ),
      ],
    );
  }

  Connection? _contactFor(AppState state, String? contactId) {
    for (final connection in state.connections) {
      if (connection.id == contactId) return connection;
    }
    return null;
  }

  Future<void> _editEvent(BuildContext context, PlannerEvent event) async {
    final deleted = await showAddEventModal(context, event: event);
    if (deleted != null && context.mounted) _showUndo(context, deleted);
  }

  void _deleteWithUndo(BuildContext context, String eventId) {
    final deleted = ref
        .read(appControllerProvider.notifier)
        .deleteEvent(eventId);
    if (deleted != null) _showUndo(context, deleted);
  }

  void _showUndo(BuildContext context, PlannerEvent deleted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${deleted.title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(appControllerProvider.notifier).restoreEvent(deleted);
          },
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.selected,
    required this.events,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });
  final DateTime month;
  final DateTime selected;
  final List events;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final first = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = first.weekday % 7;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left, size: 38),
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat.yMMMM().format(month),
                  style: AppTypography.h1(),
                ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right, size: 38),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.space5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.caption(color: tokens.inkMuted),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: .95,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - offset + 1;
            if (dayNumber < 1 || dayNumber > days) {
              return const SizedBox.shrink();
            }
            final day = DateTime(month.year, month.month, dayNumber);
            final eventsOnDay = events
                .where((event) => DateUtils.isSameDay(event.date, day))
                .toList();
            final hasEvent = eventsOnDay.isNotEmpty;
            final isSelected = DateUtils.isSameDay(day, selected);
            final isToday = DateUtils.isSameDay(day, DateTime.now());
            
            // Determine styling based on state
            Color? backgroundColor;
            Color? borderColor;
            Color textColor;
            
            if (isToday) {
              // Today: filled primary circle with primaryOn text
              backgroundColor = tokens.primary;
              textColor = tokens.primaryOn;
            } else if (isSelected) {
              // Selected (not today): primaryTint background + 2px primary ring
              backgroundColor = tokens.primaryTint;
              borderColor = tokens.primary;
              textColor = tokens.ink;
            } else {
              // Default: transparent background, ink text
              backgroundColor = Colors.transparent;
              textColor = tokens.ink;
            }
            
            return InkWell(
              onTap: () => onSelect(day),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                margin: EdgeInsets.all(AppSpacing.space1),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: borderColor != null
                      ? Border.all(color: borderColor, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: AppTypography.bodyLg(
                        color: textColor,
                      ),
                    ),
                    if (hasEvent)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.space1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Show up to 3 dots for events
                            for (int i = 0; i < eventsOnDay.length && i < 3; i++)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 1.5),
                                child: CircleAvatar(
                                  radius: 2,
                                  backgroundColor: isToday
                                      ? tokens.primaryOn
                                      : tokens.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
