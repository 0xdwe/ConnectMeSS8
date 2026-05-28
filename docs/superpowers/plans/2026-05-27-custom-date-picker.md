# Custom Date Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the standard Material DatePicker in `AddEventModal` with a custom dialog (`_CustomDatePickerDialog`) that matches the premium, 42-day continuous calendar grid and theme of the main Planner page.

**Architecture:** A custom stateful dialog (`_CustomDatePickerDialog`) is launched via `showDialog`. It localizes month/selection states, queries Riverpod for calendar event context, renders the custom weekday and 42-day date grids, and provides Cancel/OK button actions.

**Tech Stack:** Flutter, Riverpod, package:intl/intl.dart

---

### Task 1: Append _CustomDatePickerDialog Widget to add_event_modal.dart

**Files:**
- Modify: `lib/src/features/modals/add_event_modal.dart` (Append custom dialog widget class at the very bottom)

- [ ] **Step 1: Write the _CustomDatePickerDialog class definition**
  We will append the complete widget and state classes for `_CustomDatePickerDialog` at the bottom of the file. It will contain month-navigation chevrons, SUN-SAT weekday labels, a 42-day continuous grid with `tokens.primary` selected highlight, and event indicator dots underneath day numbers.

  ```dart
  class _CustomDatePickerDialog extends ConsumerStatefulWidget {
    const _CustomDatePickerDialog({required this.initialDate});
    final DateTime initialDate;

    @override
    ConsumerState<_CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();
  }

  class _CustomDatePickerDialogState extends ConsumerState<_CustomDatePickerDialog> {
    late DateTime _selectedDate = widget.initialDate;
    late DateTime _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);

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
      final gridDates = List.generate(42, (index) => firstGridDate.add(Duration(days: index)));

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
                      style: AppTypography.h1(color: tokens.ink).copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                      });
                    },
                    icon: Icon(Icons.chevron_left, color: tokens.primary, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                      });
                    },
                    icon: Icon(Icons.chevron_right, color: tokens.primary, size: 24),
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
                            style: AppTypography.caption(color: tokens.inkMuted).copyWith(
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

                    if (isSelected) {
                      backgroundColor = tokens.primary;
                      textColor = tokens.primaryOn;
                    } else {
                      backgroundColor = Colors.transparent;
                      textColor = isCurrentMonth
                          ? (isToday ? tokens.primary : tokens.ink)
                          : tokens.inkSubtle.withOpacity(0.5);
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
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: AppTypography.body(color: textColor).copyWith(
                                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w600,
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
              ),
              const SizedBox(height: 16),

              // Action Buttons Row (Cancel / OK)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTypography.body(color: tokens.inkMuted).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedDate),
                    child: Text(
                      'OK',
                      style: AppTypography.body(color: tokens.primary).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
  ```

- [ ] **Step 2: Save changes to the file**
  Save the completed file edits to `lib/src/features/modals/add_event_modal.dart`.

---

### Task 2: Replace showDatePicker call in _AddEventModalState

**Files:**
- Modify: `lib/src/features/modals/add_event_modal.dart:198-216`

- [ ] **Step 1: Replace standard showDatePicker with showDialog**
  Locate the standard `showDatePicker` invocation inside `_AddEventModalState`:
  ```dart
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => date = picked);
                        },
                        child: Text(
                          'Change',
                          style: TextStyle(
                            color: tokens.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
  ```

  Replace it with:
  ```dart
                      TextButton(
                        onPressed: () async {
                          final picked = await showDialog<DateTime>(
                            context: context,
                            builder: (context) => _CustomDatePickerDialog(initialDate: date),
                          );
                          if (picked != null) setState(() => date = picked);
                        },
                        child: Text(
                          'Change',
                          style: TextStyle(
                            color: tokens.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
  ```

- [ ] **Step 2: Save changes**
  Save the file.

---

### Task 3: Verify & Test Redesign

**Files:**
- Test: `test/widget_test.dart` (Ensure layout tests pass with zero regressions)

- [ ] **Step 1: Run unit and widget tests**
  Execute the Flutter test command:
  `Start-Process -FilePath "flutter" -ArgumentList "test test/widget_test.dart" -WorkingDirectory "c:\Users\sukse\ConnectMeSS8" -NoNewWindow -Wait`
  Verify that all 13 widget tests continue to pass completely.
