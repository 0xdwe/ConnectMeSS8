import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../state/query_providers.dart';
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
    final tokens = context.tokens;
    final allEvents = ref.watch(
      appControllerProvider.select((state) => state.events),
    );

    // Filter events based on selected day (always on or after selected date)
    final filteredEvents = allEvents.where((event) {
      final eventDateMidnight = DateTime(event.date.year, event.date.month, event.date.day);
      final selectedMidnight = DateTime(selected.year, selected.month, selected.day);
      return eventDateMidnight.isAtSameMomentAs(selectedMidnight) ||
          eventDateMidnight.isAfter(selectedMidnight);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    // Group events by day
    final groupedEvents = <DateTime, List<PlannerEvent>>{};
    for (final event in filteredEvents) {
      final dateMidnight = DateTime(event.date.year, event.date.month, event.date.day);
      groupedEvents.putIfAbsent(dateMidnight, () => []).add(event);
    }
    final sortedDates = groupedEvents.keys.toList()..sort();

    return Container(
      key: const Key('planner-tab'),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space5,
          AppSpacing.space6,
          AppSpacing.space5,
          AppSpacing.pageBottomPadding,
        ),
        children: [
          // Redesigned Top Bar Header
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
                icon: Icon(Icons.chevron_left, color: tokens.primary, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat.yMMMM().format(month),
                style: AppTypography.h1(color: tokens.ink),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
                icon: Icon(Icons.chevron_right, color: tokens.primary, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              // Search Action Button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.search,
                    color: tokens.primary,
                    size: 20,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const _PlannerSearchDialog(),
                    );
                  },
                ),
              ),
              SizedBox(width: AppSpacing.space2),
              // Add Action Button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.add, color: tokens.primaryOn, size: 20),
                  onPressed: () => showAddEventModal(context, initialDate: selected),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space4),

          // Calendar Card Container
          CardBox(
            padding: const EdgeInsets.all(20),
            child: _CalendarGrid(
              month: month,
              selected: selected,
              events: allEvents,
              onSelect: (day) => setState(() {
                selected = day;
                // Sync month if they select prev/next month day
                if (day.month != month.month) {
                  month = DateTime(day.year, day.month);
                }
              }),
            ),
          ),
          SizedBox(height: AppSpacing.space4),

          // Upcoming Events Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Events',
                style: AppTypography.h1(),
              ),
              Icon(Icons.calendar_month, color: tokens.primary, size: 22),
            ],
          ),
          SizedBox(height: AppSpacing.space3),

          // Event List
          if (allEvents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.space8),
                child: Text(
                  'Quiet week ahead.',
                  style: AppTypography.bodyLg(color: tokens.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (filteredEvents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.space8),
                child: Text(
                  'No events found matching filters.',
                  style: AppTypography.body(color: tokens.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            for (final date in sortedDates) ...[
              _DateGroupHeader(
                date: date,
                eventCount: groupedEvents[date]?.length ?? 0,
              ),
              SizedBox(height: AppSpacing.space2),
              for (final event in groupedEvents[date]!)
                _RedesignedEventCard(
                  key: ValueKey(event.id),
                  event: event,
                  onTap: () => _editEvent(context, event),
                  onDelete: () => _deleteWithUndo(context, event.id),
                ),
              SizedBox(height: AppSpacing.space4),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _editEvent(BuildContext context, PlannerEvent event) async {
    final deleted = await showAddEventModal(context, event: event);
    if (deleted != null && context.mounted) _showUndo(context, deleted);
  }

  Future<void> _deleteWithUndo(BuildContext context, String eventId) async {
    final deleted = await ref
        .read(appControllerProvider.notifier)
        .deleteEvent(eventId);
    if (deleted != null && context.mounted) _showUndo(context, deleted);
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

class _PlannerSearchDialog extends ConsumerStatefulWidget {
  const _PlannerSearchDialog();

  @override
  ConsumerState<_PlannerSearchDialog> createState() => _PlannerSearchDialogState();
}

class _PlannerSearchDialogState extends ConsumerState<_PlannerSearchDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final allEvents = ref.watch(
      appControllerProvider.select((state) => state.events),
    );
    final query = _searchController.text.trim().toLowerCase();

    // Filter events based on query matching title, note, or contact name
    final filteredEvents = allEvents.where((event) {
      if (query.isEmpty) return false;
      if (event.title.toLowerCase().contains(query) ||
          event.note.toLowerCase().contains(query)) {
        return true;
      }
      if (event.contactId != null) {
        final contact = ref.read(contactByIdProvider(event.contactId!));
        if (contact != null && contact.name.toLowerCase().contains(query)) {
          return true;
        }
      }
      return false;
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    return Dialog(
      backgroundColor: tokens.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Input Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.search, color: tokens.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: AppTypography.body(color: tokens.ink),
                      decoration: InputDecoration(
                        hintText: 'Search by event title or contact...',
                        hintStyle: AppTypography.body(color: tokens.inkSubtle),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: tokens.inkSubtle, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: tokens.border, height: 1),

            // Dialog Content Area
            Expanded(
              child: query.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: tokens.primaryTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.search, size: 36, color: tokens.primary),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Start typing to search events',
                            style: AppTypography.h2(color: tokens.ink).copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Search by title or contact name',
                            style: AppTypography.caption(color: tokens.inkMuted).copyWith(
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : filteredEvents.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No events found matching "${_searchController.text}"',
                              style: AppTypography.body(color: tokens.inkMuted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          shrinkWrap: true,
                          itemCount: filteredEvents.length,
                          itemBuilder: (context, index) {
                            final event = filteredEvents[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _RedesignedEventCard(
                                key: ValueKey(event.id),
                                event: event,
                                onTap: () {
                                  Navigator.pop(context);
                                  _editEvent(context, event);
                                },
                                onDelete: () {
                                  Navigator.pop(context);
                                  _deleteWithUndo(context, event.id);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEvent(BuildContext context, PlannerEvent event) async {
    final deleted = await showAddEventModal(context, event: event);
    if (deleted != null && context.mounted) {
      _showUndo(context, deleted);
    }
  }

  Future<void> _deleteWithUndo(BuildContext context, String eventId) async {
    final deleted = await ref
        .read(appControllerProvider.notifier)
        .deleteEvent(eventId);
    if (deleted != null && context.mounted) {
      _showUndo(context, deleted);
    }
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
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final List<PlannerEvent> events;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Calculate grid dates (42 days continuous grid)
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final offset = firstOfMonth.weekday % 7;
    final firstGridDate = firstOfMonth.subtract(Duration(days: offset));
    final gridDates = List.generate(42, (index) => firstGridDate.add(Duration(days: index)));

    return Column(
      children: [
        // SUN - SAT Weekdays Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.caption(color: tokens.inkMuted).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.05,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            crossAxisSpacing: 4,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final day = gridDates[index];
            final isCurrentMonth = day.month == month.month;
            final isSelected = DateUtils.isSameDay(day, selected);
            final isToday = DateUtils.isSameDay(day, DateTime.now());

            final eventsOnDay = events
                .where((event) => DateUtils.isSameDay(event.date, day))
                .toList();
            final hasEvent = eventsOnDay.isNotEmpty;

            // Highlight & text color selection
            Color? backgroundColor;
            Color textColor;
            Border? border;

            if (isSelected) {
              backgroundColor = tokens.primary;
              textColor = tokens.primaryOn;
            } else if (isToday) {
              backgroundColor = tokens.primary.withOpacity(0.08);
              textColor = tokens.primary;
              border = Border.all(color: tokens.primary, width: 1.5);
            } else {
              backgroundColor = Colors.transparent;
              textColor = isCurrentMonth
                  ? tokens.ink
                  : tokens.inkSubtle.withOpacity(0.5);
            }

            return InkWell(
              onTap: () => onSelect(day),
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
                      style: AppTypography.body(color: textColor).copyWith(
                        fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Centered event dot
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: hasEvent
                            ? (isSelected ? tokens.primaryOn : tokens.primary)
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
      ],
    );
  }
}

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({
    required this.date,
    required this.eventCount,
  });

  final DateTime date;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final midnight = DateTime(date.year, date.month, date.day);

    String label = '';
    Color labelColor = tokens.inkMuted;

    if (midnight.isAtSameMomentAs(today)) {
      label = 'TODAY';
      labelColor = tokens.primary;
    } else if (midnight.isAtSameMomentAs(tomorrow)) {
      label = 'TOMORROW';
      labelColor = tokens.primary;
    } else {
      label = DateFormat('EEEE, MMMM d').format(date).toUpperCase();
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.space2, horizontal: AppSpacing.space1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption(color: labelColor).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.05,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$eventCount event${eventCount > 1 ? 's' : ''}',
              style: AppTypography.caption(color: tokens.primary).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedesignedEventCard extends ConsumerWidget {
  const _RedesignedEventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  final PlannerEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final contact = event.contactId != null
        ? ref.watch(contactByIdProvider(event.contactId!))
        : null;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border, width: 1),
        boxShadow: AppTokens.elevation1(Theme.of(context).brightness == Brightness.dark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leading Soft Purple Square Icon Container
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tokens.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: _getEventIcon(event),
                    ),
                    const SizedBox(width: 12),
                    // Title and Time Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: AppTypography.h2(color: tokens.ink).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                color: tokens.inkMuted,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTimeRange(event),
                                style: AppTypography.caption(color: tokens.inkMuted).copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Trailing Action Button if NO associated contact
                    if (contact == null)
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: tokens.inkMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onTap,
                      ),
                  ],
                ),
                // Divider and Footer if contact is associated
                if (contact != null) ...[
                  Container(
                    height: 1,
                    color: tokens.border,
                    margin: EdgeInsets.symmetric(vertical: AppSpacing.space3),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: tokens.primaryTint,
                            child: Text(
                              contact.avatar,
                              style: AppTypography.glyph(12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'with ${contact.name}',
                            style: AppTypography.caption(color: tokens.inkMuted).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: tokens.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getEventIcon(PlannerEvent event) {
    final title = event.title.toLowerCase();
    final category = event.category.toLowerCase();

    String emoji = '📅'; // Default calendar emoji

    if (title.contains('coffee') || title.contains('cafe')) {
      emoji = '☕';
    } else if (title.contains('meeting') || title.contains('sync') || title.contains('team')) {
      emoji = '👥';
    } else if (title.contains('lunch') || title.contains('dinner') || title.contains('food') || title.contains('restaurant')) {
      emoji = '🍽️';
    } else if (category == 'work') {
      emoji = '💼';
    } else if (category == 'family') {
      emoji = '🏠';
    } else if (category == 'friends') {
      emoji = '🤝';
    } else if (title.contains('call') || title.contains('phone')) {
      emoji = '📞';
    } else if (title.contains('party') || title.contains('celebrate')) {
      emoji = '🎉';
    }

    return Center(
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }

  String _formatTimeRange(PlannerEvent event) {
    if (event.isAllDay) return 'All day';
    return '${_formatMinutes(event.startTimeMinutes)} - ${_formatMinutes(event.endTimeMinutes)}';
  }

  String _formatMinutes(int? minutes) {
    if (minutes == null) return '';
    final hour24 = minutes ~/ 60;
    final min = minutes % 60;
    final amPm = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minStr = min.toString().padLeft(2, '0');
    return '$hour12:$minStr $amPm';
  }
}

