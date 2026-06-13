# Event Time Picker Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replaces the dial time picker with inline dropdown menus for setting start and end event times, styling it identically to the "Quiet Hours" dialog in ConnectMe.

**Architecture:** Use an inline widget `_EventTimeRow` in `lib/src/features/modals/add_event_modal.dart` to render dropdown selections for hour, minute, and AM/PM when "All Day" is switched off. State is updated using a callback and managed as `TimeOfDay`.

**Tech Stack:** Flutter, Riverpod, Material Design.

---

### Task 1: Add a failing test for Event Time Picker Dropdown

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing widget test**

Add the following widget test to the end of `test/widget_test.dart` (before the final closing brace):

```dart
  testWidgets('AddEventModal toggles All Day and updates time dropdowns', (WidgetTester tester) async {
    final connectionsStore = InMemoryConnectionStore();
    final eventsStore = InMemoryEventStore();
    final interactionStore = InMemoryInteractionStore();
    final userDocStore = InMemoryUserDocStore();
    final batchedWrites = InMemoryBatchedWrites();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStatusProvider.overrideWith(
            (ref) => const AuthStatus.signedIn(
              user: AppUser(
                uid: 'demo-uid',
                isAnonymous: false,
                email: 'demo@example.com',
                displayName: 'Demo',
              ),
            ),
          ),
          eventStoreProvider.overrideWithValue(eventsStore),
          connectionStoreProvider.overrideWithValue(connectionsStore),
          interactionStoreProvider.overrideWithValue(interactionStore),
          userDocStoreProvider.overrideWithValue(userDocStore),
          batchedWritesProvider.overrideWithValue(batchedWrites),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: AddEventModal(initialDate: DateTime(2026, 4, 27)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle All Day switch off to display time rows
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    // Verify Start and End time dropdown widgets are present
    expect(find.byKey(const Key('event-start-hour')), findsOneWidget);
    expect(find.byKey(const Key('event-start-minute')), findsOneWidget);
    expect(find.byKey(const Key('event-start-period')), findsOneWidget);
    expect(find.byKey(const Key('event-end-hour')), findsOneWidget);
    expect(find.byKey(const Key('event-end-minute')), findsOneWidget);
    expect(find.byKey(const Key('event-end-period')), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: Compilation failure because `_EventTimeRow` is not defined in `add_event_modal.dart` (referred to on lines 220-230).

- [ ] **Step 3: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: add widget test for event time picker dropdowns"
```

---

### Task 2: Implement `_EventTimeRow` in `add_event_modal.dart`

**Files:**
- Modify: `lib/src/features/modals/add_event_modal.dart`

- [ ] **Step 1: Implement `_EventTimeRow` widget**

Append the implementation of `_EventTimeRow` to the bottom of `lib/src/features/modals/add_event_modal.dart`:

```dart
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
                        _timeFor(
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
                        _timeFor(
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
                        _timeFor(
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
```

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze`
Expected: No errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/src/features/modals/add_event_modal.dart
git commit -m "feat(event-ui): implement inline dropdown time picker _EventTimeRow"
```
