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
  const PlannerTab({super.key, this.now});

  final DateTime Function()? now;

  @override
  ConsumerState<PlannerTab> createState() => _PlannerTabState();
}

class _PlannerTabState extends ConsumerState<PlannerTab> {
  late DateTime month;
  late DateTime selected;
  bool _hasExplicitDateSelection = false;

  DateTime _today() {
    final now = (widget.now ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final today = _today();
    month = DateTime(today.year, today.month);
    selected = today;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final today = _today();
    final now = (widget.now ?? DateTime.now)();
    final selectedIsPast =
        _hasExplicitDateSelection && selected.isBefore(today);
    final allEvents = ref.watch(
      appControllerProvider.select((state) => state.events),
    );
    final contacts = ref.watch(
      appControllerProvider.select((state) => state.connections),
    );
    final contactById = {for (final contact in contacts) contact.id: contact};
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    // Expand recurring events into individual occurrences for the display window.
    // "Today & upcoming" shows occurrences in [today, today+365d].
    // "Selected date" shows occurrences on exactly that day.
    final windowEnd = today.add(const Duration(days: 365));
    final filteredEvents = [
      for (final e in allEvents)
        ..._occurrencesInRange(
          e,
          _hasExplicitDateSelection ? selected : today,
          _hasExplicitDateSelection ? selected : windowEnd,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    final monthEvents = [
      for (final event in allEvents)
        ..._occurrencesInRange(event, monthStart, monthEnd),
    ];
    final nextEvent = _nextUpcomingEvent(filteredEvents, now);
    final nextEventContact = nextEvent?.contactId != null
        ? contactById[nextEvent!.contactId!]
        : null;

    // Group events by day
    final groupedEvents = <DateTime, List<PlannerEvent>>{};
    for (final event in filteredEvents) {
      final dateMidnight = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      groupedEvents.putIfAbsent(dateMidnight, () => []).add(event);
    }
    final sortedDates = groupedEvents.keys.toList()..sort();

    final selectedDayEvents = _hasExplicitDateSelection
        ? groupedEvents[DateTime(
                selected.year,
                selected.month,
                selected.day,
              )] ??
              <PlannerEvent>[]
        : <PlannerEvent>[];
    final selectedDayMidnight = DateTime(
      selected.year,
      selected.month,
      selected.day,
    );
    late final List<PlannerEvent> upcomingEvents;
    if (_hasExplicitDateSelection) {
      upcomingEvents = [
        for (final e in allEvents)
          ..._occurrencesInRange(
            e,
            selectedDayMidnight.add(const Duration(days: 1)),
            windowEnd,
          ),
      ]..sort((a, b) => a.date.compareTo(b.date));
    } else {
      upcomingEvents = filteredEvents;
    }
    final upcomingGroupedEvents = <DateTime, List<PlannerEvent>>{};
    for (final event in upcomingEvents) {
      final dateMidnight = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      upcomingGroupedEvents.putIfAbsent(dateMidnight, () => []).add(event);
    }
    final upcomingSortedDates = upcomingGroupedEvents.keys.toList()..sort();

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
          _PlanTogetherBanner(upcomingCount: monthEvents.length, month: month),
          SizedBox(height: AppSpacing.space4),

          CardBox(
            padding: EdgeInsets.all(AppSpacing.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    final monthControls = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => setState(
                            () => month = DateTime(month.year, month.month - 1),
                          ),
                          icon: Icon(
                            Icons.chevron_left,
                            color: tokens.primary,
                            size: 28,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            DateFormat.MMMM().format(month),
                            key: const Key('planner-month-label'),
                            style: AppTypography.h2(color: tokens.ink),
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setState(
                            () => month = DateTime(month.year, month.month + 1),
                          ),
                          icon: Icon(
                            Icons.chevron_right,
                            color: tokens.primary,
                            size: 28,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    );

                    final actionButtons = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tokens.primary.withValues(alpha: 0.12),
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
                                builder: (context) =>
                                    const _PlannerSearchDialog(),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: AppSpacing.space2),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tokens.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.add,
                              color: tokens.primaryOn,
                              size: 20,
                            ),
                            onPressed: () => showAddEventModal(
                              context,
                              initialDate: selected,
                            ),
                          ),
                        ),
                      ],
                    );

                    if (!compact) {
                      return Row(
                        children: [
                          monthControls,
                          const Spacer(),
                          actionButtons,
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: monthControls),
                        SizedBox(height: AppSpacing.space3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: actionButtons,
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: AppSpacing.space4),
                _CalendarGrid(
                  month: month,
                  selected: selected,
                  selectedIsPast: selectedIsPast,
                  events: allEvents,
                  contacts: contacts,
                  onSelect: (day) => setState(() {
                    selected = day;
                    _hasExplicitDateSelection = true;
                    if (day.year != month.year || day.month != month.month) {
                      month = DateTime(day.year, day.month);
                    }
                  }),
                ),
                SizedBox(height: AppSpacing.space3),
                // Wrap(
                //   spacing: AppSpacing.space4,
                //   runSpacing: AppSpacing.space2,
                //   children: const [
                //     _LegendDot(color: Color(0xFF4F46E5), label: 'Personal'),
                //     _LegendDot(color: Color(0xFF2563EB), label: 'Family'),
                //     _LegendDot(color: Colors.pink, label: 'Partner'),
                //     _LegendDot(color: Color(0xFF10B981), label: 'Friends'),
                //   ],
                // ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.space4),

          // Event Section Header
          Row(
            children: [
              Expanded(
                child: Text(
                  _hasExplicitDateSelection
                      ? DateFormat('EEEE, MMMM d').format(selected)
                      : 'Today & Upcoming',
                  key: const Key('planner-event-section-title'),
                  style: AppTypography.h1(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selectedIsPast) ...[
                SizedBox(width: AppSpacing.space2),
                Container(
                  key: const Key('planner-past-date-indicator'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSunken,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Text(
                    'Past date',
                    style: AppTypography.caption(
                      color: tokens.inkMuted,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              SizedBox(width: AppSpacing.space2),
              Icon(Icons.calendar_month, color: tokens.primary, size: 22),
            ],
          ),
          SizedBox(height: AppSpacing.space3),

          if (nextEvent != null) ...[
            _NextUpCard(
              event: nextEvent,
              contact: nextEventContact,
              onTap: () => _editEvent(context, nextEvent),
            ),
            SizedBox(height: AppSpacing.space4),
          ],

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
          else if (_hasExplicitDateSelection) ...[
            _SectionTitle(
              title: DateFormat('EEEE, MMMM d').format(selected),
              count: selectedDayEvents.length,
            ),
            SizedBox(height: AppSpacing.space2),
            if (selectedDayEvents.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
                child: Text(
                  'No events planned for this date.',
                  style: AppTypography.body(color: tokens.inkMuted),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              for (final event in selectedDayEvents)
                _RedesignedEventCard(
                  key: ValueKey('selected-${event.id}'),
                  event: event,
                  onTap: () => _editEvent(context, event),
                  onDelete: () => _deleteWithUndo(context, event.id),
                ),
            ],
            SizedBox(height: AppSpacing.space4),
            _SectionTitle(title: 'Upcoming', count: upcomingEvents.length),
            SizedBox(height: AppSpacing.space2),
            if (upcomingEvents.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
                child: Text(
                  'No upcoming events.',
                  style: AppTypography.body(color: tokens.inkMuted),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              for (final date in upcomingSortedDates) ...[
                _DateGroupHeader(
                  date: date,
                  eventCount: upcomingGroupedEvents[date]?.length ?? 0,
                ),
                SizedBox(height: AppSpacing.space2),
                for (final event in upcomingGroupedEvents[date]!)
                  _RedesignedEventCard(
                    key: ValueKey(
                      'upcoming-${event.id}-${event.date.toIso8601String()}',
                    ),
                    event: event,
                    onTap: () => _editEvent(context, event),
                    onDelete: () => _deleteWithUndo(context, event.id),
                  ),
                SizedBox(height: AppSpacing.space4),
              ],
            ],
          ] else if (filteredEvents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.space8),
                child: Text(
                  'No upcoming events.',
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
  ConsumerState<_PlannerSearchDialog> createState() =>
      _PlannerSearchDialogState();
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
                            child: Icon(
                              Icons.search,
                              size: 36,
                              color: tokens.primary,
                            ),
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
                            style: AppTypography.caption(
                              color: tokens.inkMuted,
                            ).copyWith(fontSize: 14),
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
    required this.selectedIsPast,
    required this.events,
    required this.contacts,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final bool selectedIsPast;
  final List<PlannerEvent> events;
  final List<Connection> contacts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final contactById = {for (final contact in contacts) contact.id: contact};

    // Calculate grid dates (42 days continuous grid)
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final offset = firstOfMonth.weekday % 7;
    final firstGridDate = firstOfMonth.subtract(Duration(days: offset));
    final gridDates = List.generate(
      42,
      (index) => firstGridDate.add(Duration(days: index)),
    );

    // Pre-expand recurring events for the whole grid range so dots appear
    // on every occurrence, not just the base date.
    final lastGridDate = firstGridDate.add(const Duration(days: 41));
    final expandedForGrid = [
      for (final e in events)
        ..._occurrencesInRange(e, firstGridDate, lastGridDate),
    ];

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
                      style: AppTypography.caption(color: tokens.inkMuted)
                          .copyWith(
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
            childAspectRatio: 0.95,
            crossAxisSpacing: 4,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final day = gridDates[index];
            final isCurrentMonth = day.month == month.month;
            final isSelected = DateUtils.isSameDay(day, selected);
            final isToday = DateUtils.isSameDay(day, DateTime.now());

            final eventsOnDay = expandedForGrid
                .where((event) => DateUtils.isSameDay(event.date, day))
                .toList();
            final hasEvent = eventsOnDay.isNotEmpty;
            final uniqueContacts = <Connection>[];
            for (final event in eventsOnDay) {
              final contactId = event.contactId;
              if (contactId == null) continue;
              final contact = contactById[contactId];
              if (contact == null) continue;
              if (!uniqueContacts.any((item) => item.id == contact.id)) {
                uniqueContacts.add(contact);
              }
            }
            final avatarCount = uniqueContacts.length > 3
                ? 3
                : uniqueContacts.length;
            final avatarStripWidth = avatarCount <= 1
                ? 12.0
                : 12.0 + ((avatarCount - 1) * 6.0);

            // Highlight & text color selection
            Color? backgroundColor;
            Color textColor;
            Border? border;

            if (isSelected) {
              if (selectedIsPast) {
                backgroundColor = tokens.surfaceSunken;
                textColor = tokens.inkMuted;
                border = Border.all(color: tokens.border, width: 1.5);
              } else {
                backgroundColor = tokens.primary;
                textColor = tokens.primaryOn;
              }
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
              onTap: () => onSelect(day),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  border: border,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: AppTypography.body(color: textColor).copyWith(
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontSize: 13,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    SizedBox(
                      height: 14,
                      child: uniqueContacts.isNotEmpty
                          ? Center(
                              child: SizedBox(
                                width: avatarStripWidth,
                                height: 12,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (var i = 0; i < avatarCount; i++)
                                      Positioned(
                                        left: i * 6,
                                        child: _CalendarDayAvatar(
                                          contact: uniqueContacts[i],
                                          size: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: hasEvent
                                    ? (isSelected
                                          ? (selectedIsPast
                                                ? tokens.inkMuted
                                                : tokens.primaryOn)
                                          : tokens.primary)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
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
  const _DateGroupHeader({required this.date, required this.eventCount});

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
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.space2,
        horizontal: AppSpacing.space1,
      ),
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
              style: AppTypography.caption(
                color: tokens.primary,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.h2(color: tokens.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.primaryTint,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count event${count == 1 ? '' : 's'}',
            style: AppTypography.caption(
              color: tokens.primary,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _PlanTogetherBanner extends StatelessWidget {
  const _PlanTogetherBanner({required this.upcomingCount, required this.month});

  final int upcomingCount;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: tokens.cardGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border),
        boxShadow: AppTokens.elevation1(dark),
      ),
      padding: EdgeInsets.all(AppSpacing.space4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: tokens.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Plan Together',
                      style: AppTypography.caption(
                        color: tokens.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.space2),
                Text(
                  '${DateFormat.MMMM().format(month)} at a glance',
                  style: AppTypography.h1(color: tokens.ink),
                ),
                SizedBox(height: AppSpacing.space2),
                Text(
                  'You have $upcomingCount upcoming plans this month. 💜',
                  style: AppTypography.body(color: tokens.inkMuted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            height: 110,
            child: LoopingMascotMotion(
              child: Image.asset(
                'assets/images/planner_mascot.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption(color: tokens.inkMuted)),
      ],
    );
  }
}

class _CalendarDayAvatar extends StatelessWidget {
  const _CalendarDayAvatar({required this.contact, required this.size});

  final Connection contact;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tokens.surface, width: 1.2),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: tokens.surface,
        backgroundImage: connectionAvatarImage(contact.avatar),
        child: connectionAvatarImage(contact.avatar) == null
            ? Text(contact.avatar, style: AppTypography.glyph(size * 0.7))
            : null,
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({
    required this.event,
    required this.contact,
    required this.onTap,
  });

  final PlannerEvent event;
  final Connection? contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final location = event.note.trim().isEmpty ? null : event.note.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.primary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: EdgeInsets.all(AppSpacing.space4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _plannerEventIconForType(event.eventType),
                color: Colors.white,
              ),
            ),
            SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Next up',
                        style: AppTypography.caption(color: Colors.white70),
                      ),
                    ],
                  ),
                  Text(
                    event.title,
                    style: AppTypography.h2(color: Colors.white),
                  ),
                  Text(
                    '${DateFormat.MMMd().format(event.date)} • ${_formatTimeRange(event)}',
                    style: AppTypography.caption(color: Colors.white70),
                  ),
                  if (location != null)
                    Text(
                      location,
                      style: AppTypography.caption(color: Colors.white70),
                    ),
                ],
              ),
            ),
            if (contact != null) ...[
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: connectionAvatarImage(contact!.avatar),
                child: connectionAvatarImage(contact!.avatar) == null
                    ? Text(contact!.avatar, style: AppTypography.glyph(20))
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            //const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
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
    final iconColor = _iconTintForEventType(event.eventType, tokens);
    final contactAvatarImage = contact == null
        ? null
        : connectionAvatarImage(contact.avatar);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border, width: 1),
        boxShadow: AppTokens.elevation1(
          Theme.of(context).brightness == Brightness.dark,
        ),
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
                        color: iconColor.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        _eventIconForType(event.eventType),
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title and Time Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: AppTypography.h2(color: tokens.ink)
                                      .copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.eventType,
                            style: AppTypography.caption(
                              color: tokens.inkMuted,
                            ).copyWith(fontWeight: FontWeight.w600),
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
                                style: AppTypography.caption(
                                  color: tokens.inkMuted,
                                ).copyWith(fontWeight: FontWeight.w500),
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
                            backgroundImage: contactAvatarImage,
                            child: contactAvatarImage == null
                                ? Text(
                                    contact.avatar,
                                    style: AppTypography.glyph(12),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'with ${contact.name}',
                            style: AppTypography.caption(
                              color: tokens.inkMuted,
                            ).copyWith(fontWeight: FontWeight.w600),
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

  IconData _eventIconForType(String eventType) {
    final value = eventType.toLowerCase().trim();
    if (value.contains('coffee') || value.contains('cafe')) {
      return Icons.local_cafe_outlined;
    }
    if (value.contains('meeting') ||
        value.contains('sync') ||
        value.contains('team')) {
      return Icons.groups_2_outlined;
    }
    if (value.contains('lunch') ||
        value.contains('dinner') ||
        value.contains('food') ||
        value.contains('restaurant')) {
      return Icons.restaurant_outlined;
    }
    if (value.contains('call') || value.contains('phone')) {
      return Icons.call_outlined;
    }
    if (value.contains('party') || value.contains('celebrate')) {
      return Icons.celebration_outlined;
    }
    if (value.contains('birth') || value.contains('anniversary')) {
      return Icons.cake_outlined;
    }
    if (value.contains('remind') || value.contains('alert')) {
      return Icons.notifications_none;
    }
    if (value.contains('workshop') ||
        value.contains('class') ||
        value.contains('study') ||
        value.contains('school')) {
      return Icons.menu_book_outlined;
    }
    if (value.contains('travel') ||
        value.contains('trip') ||
        value.contains('flight')) {
      return Icons.flight_takeoff_outlined;
    }
    if (value.contains('plan') || value.contains('schedule')) {
      return Icons.event_note_outlined;
    }
    if (value.contains('gift')) return Icons.card_giftcard_outlined;
    return Icons.event_outlined;
  }

  // ignore: unused_element
  Widget _getEventIcon(PlannerEvent event) {
    final emoji = _emojiForEventType(event.eventType);
    return Center(child: Text(emoji, style: const TextStyle(fontSize: 22)));
  }

  String _emojiForEventType(String eventType) {
    final value = eventType.toLowerCase().trim();
    if (value.contains('coffee') || value.contains('cafe')) return '☕';
    if (value.contains('meeting') ||
        value.contains('sync') ||
        value.contains('team')) {
      return '👥';
    }
    if (value.contains('lunch') ||
        value.contains('dinner') ||
        value.contains('food') ||
        value.contains('restaurant')) {
      return '🍽️';
    }
    if (value.contains('call') || value.contains('phone')) return '📞';
    if (value.contains('party') || value.contains('celebrate')) return '🎉';
    if (value.contains('birth') || value.contains('anniversary')) return '🎂';
    if (value.contains('remind') || value.contains('alert')) return '🔔';
    if (value.contains('workshop') ||
        value.contains('class') ||
        value.contains('study') ||
        value.contains('school')) {
      return '📚';
    }
    if (value.contains('travel') ||
        value.contains('trip') ||
        value.contains('flight')) {
      return '✈️';
    }
    if (value.contains('plan') || value.contains('schedule')) return '📅';
    if (value.contains('gift')) return '🎁';
    return '🗒️';
  }

  Color _iconTintForEventType(String eventType, AppTokens tokens) {
    final value = eventType.toLowerCase().trim();
    if (value.contains('coffee') || value.contains('cafe')) {
      return tokens.secondary;
    }
    if (value.contains('meeting') ||
        value.contains('sync') ||
        value.contains('team')) {
      return tokens.categoryWork;
    }
    if (value.contains('lunch') ||
        value.contains('dinner') ||
        value.contains('food') ||
        value.contains('restaurant')) {
      return tokens.secondary;
    }
    if (value.contains('call') || value.contains('phone')) {
      return tokens.success;
    }
    if (value.contains('party') ||
        value.contains('celebrate') ||
        value.contains('birth') ||
        value.contains('anniversary')) {
      return tokens.tertiary;
    }
    if (value.contains('remind') || value.contains('alert')) {
      return tokens.secondary;
    }
    if (value.contains('workshop') ||
        value.contains('class') ||
        value.contains('study') ||
        value.contains('school')) {
      return tokens.categoryCollege;
    }
    if (value.contains('travel') ||
        value.contains('trip') ||
        value.contains('flight')) {
      return tokens.categoryWork;
    }
    if (value.contains('gift')) {
      return tokens.tertiary;
    }
    if (value.contains('plan') || value.contains('schedule')) {
      return tokens.primary;
    }
    return tokens.primary;
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

IconData _plannerEventIconForType(String eventType) {
  final value = eventType.toLowerCase().trim();
  if (value.contains('coffee') || value.contains('cafe')) {
    return Icons.local_cafe_outlined;
  }
  if (value.contains('meeting') ||
      value.contains('sync') ||
      value.contains('team')) {
    return Icons.groups_2_outlined;
  }
  if (value.contains('lunch') ||
      value.contains('dinner') ||
      value.contains('food') ||
      value.contains('restaurant')) {
    return Icons.restaurant_outlined;
  }
  if (value.contains('call') || value.contains('phone')) {
    return Icons.call_outlined;
  }
  if (value.contains('party') || value.contains('celebrate')) {
    return Icons.celebration_outlined;
  }
  if (value.contains('birth') || value.contains('anniversary')) {
    return Icons.cake_outlined;
  }
  if (value.contains('remind') || value.contains('alert')) {
    return Icons.notifications_none;
  }
  if (value.contains('workshop') ||
      value.contains('class') ||
      value.contains('study') ||
      value.contains('school')) {
    return Icons.menu_book_outlined;
  }
  if (value.contains('travel') ||
      value.contains('trip') ||
      value.contains('flight')) {
    return Icons.flight_takeoff_outlined;
  }
  if (value.contains('plan') || value.contains('schedule')) {
    return Icons.event_note_outlined;
  }
  if (value.contains('gift')) return Icons.card_giftcard_outlined;
  return Icons.event_outlined;
}

PlannerEvent? _nextUpcomingEvent(List<PlannerEvent> events, DateTime now) {
  final ordered = [...events]
    ..sort((a, b) => _eventMoment(a).compareTo(_eventMoment(b)));
  for (final event in ordered) {
    if (!_isPastEvent(event, now)) return event;
  }
  return null;
}

DateTime _eventMoment(PlannerEvent event) {
  final startMinutes = event.startTimeMinutes;
  if (event.isAllDay || startMinutes == null) {
    return DateTime(event.date.year, event.date.month, event.date.day);
  }
  return DateTime(
    event.date.year,
    event.date.month,
    event.date.day,
    startMinutes ~/ 60,
    startMinutes % 60,
  );
}

bool _isPastEvent(PlannerEvent event, DateTime now) {
  return _eventMoment(event).isBefore(now);
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

// ─────────────────────────────────────────────────────────────────────────────
// Recurring-event expansion helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns all occurrences of [event] in the date range [from, to] inclusive.
///
/// For non-recurring events, returns the event itself if its date falls in the
/// range. For recurring events, walks forward from the base date generating
/// occurrence copies (same id, same data, different [date]) until [to] is
/// exceeded, capped at 500 iterations to prevent runaway loops.
List<PlannerEvent> _occurrencesInRange(
  PlannerEvent event,
  DateTime from,
  DateTime to, {
  int maxOccurrences = 500,
}) {
  final base = DateTime(event.date.year, event.date.month, event.date.day);
  final dayFrom = DateTime(from.year, from.month, from.day);
  final dayTo = DateTime(to.year, to.month, to.day);

  if (!event.isRecurring || event.recurrencePattern == null) {
    if (!base.isBefore(dayFrom) && !base.isAfter(dayTo)) return [event];
    return [];
  }

  final result = <PlannerEvent>[];
  var current = base;
  int count = 0;

  while (!current.isAfter(dayTo) && count < maxOccurrences) {
    if (!current.isBefore(dayFrom)) {
      result.add(event.copyWith(date: current));
    }
    current = _nextRecurringDate(current, event.recurrencePattern!, event.date);
    count++;
  }
  return result;
}

DateTime _nextRecurringDate(
  DateTime current,
  RecurrencePattern pattern,
  DateTime anchor,
) {
  return switch (pattern) {
    RecurrencePattern.daily => current.add(const Duration(days: 1)),
    RecurrencePattern.weekly => current.add(const Duration(days: 7)),
    RecurrencePattern.monthly => _clampedDate(
      current.year,
      current.month + 1,
      anchor.day,
    ),
    RecurrencePattern.yearly => _clampedDate(
      current.year + 1,
      anchor.month,
      anchor.day,
    ),
  };
}

DateTime _clampedDate(int year, int month, int day) {
  final normalized = DateTime(year, month);
  final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
  return DateTime(
    normalized.year,
    normalized.month,
    day > lastDay ? lastDay : day,
  );
}
