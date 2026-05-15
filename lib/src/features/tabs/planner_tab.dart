import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
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
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 126),
      children: [
        SwitchListTile(
          value: state.googleCalendarLinked,
          onChanged: ref
              .read(appControllerProvider.notifier)
              .toggleGoogleCalendar,
          title: const Text(
            'Google Calendar connected',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Mock sync boundary. OAuth later.'),
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
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
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
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right, size: 38),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
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
            final hasEvent = events.any(
              (event) => DateUtils.isSameDay(event.date, day),
            );
            final isSelected = DateUtils.isSameDay(day, selected);
            return InkWell(
              onTap: () => onSelect(day),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.moss : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasEvent)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: CircleAvatar(
                          radius: 3,
                          backgroundColor: isSelected
                              ? Colors.white
                              : AppTheme.moss,
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
