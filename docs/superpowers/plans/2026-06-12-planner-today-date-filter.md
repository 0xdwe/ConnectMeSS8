# Planner Today and Date Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open Plan on the current date, filter explicit date selections to one day, provide a visible Today reset, and identify selected past dates neutrally.

**Architecture:** Keep the behavior local to `PlannerTab`. Add an injectable clock callback to make date-sensitive widget tests deterministic, and track whether the selected date came from the default state or an explicit calendar tap. Reuse the existing event grouping and calendar components.

**Tech Stack:** Flutter, Riverpod, `intl`, Flutter widget tests

---

### Task 1: Lock the planner date modes with widget tests

**Files:**
- Modify: `test/features/planner_calendar_test.dart`

- [ ] **Step 1: Add a deterministic planner test harness**

Create a helper that pumps `PlannerTab(now: () => fixedNow)` inside the app theme and signed-in in-memory store overrides. Seed event dates around `fixedNow` so tests do not depend on the real clock.

- [ ] **Step 2: Add failing default-state coverage**

Assert that a fixed June 12, 2026 clock displays `June 2026`, `Today & Upcoming`, and both a today event and a future event.

- [ ] **Step 3: Add failing explicit-selection coverage**

Tap a future date and assert that the heading changes to the formatted date, only that date’s event remains, and unrelated future events disappear.

- [ ] **Step 4: Add failing Today-reset coverage**

After selecting another date, tap the `Today` button and assert that the calendar and event list return to `Today & Upcoming`.

- [ ] **Step 5: Add failing past-date and empty-state coverage**

Select a past date and assert that `Past date` appears. Select a date without events and assert `No events planned for this date.`

- [ ] **Step 6: Run the focused tests and confirm RED**

Run:

```powershell
flutter test test/features/planner_calendar_test.dart
```

Expected: the new tests fail because Plan is still initialized to April 2026, has no Today reset, and filters selected dates as selected-and-later.

### Task 2: Implement current-date initialization and explicit date filtering

**Files:**
- Modify: `lib/src/features/tabs/planner_tab.dart`

- [ ] **Step 1: Add an injectable clock and initialize local date state**

Add an optional `DateTime Function()? now` to `PlannerTab`. In `initState`, normalize the clock value with `DateUtils.dateOnly`, then initialize both the visible month and selected date from it.

- [ ] **Step 2: Track default versus explicit selection mode**

Add a boolean such as `_hasExplicitDateSelection`. Default it to `false`, set it to `true` on a calendar tap, and reset it to `false` through the Today button.

- [ ] **Step 3: Apply the two filtering modes**

When `_hasExplicitDateSelection` is false, include events on or after today. When true, include only events where `DateUtils.isSameDay(event.date, selected)`.

- [ ] **Step 4: Add the Today button and contextual event heading**

Place a compact text button in the existing calendar header. Its handler recalculates today, updates month and selected date, and exits explicit selection mode. Render `Today & Upcoming` in default mode or `DateFormat('EEEE, MMMM d')` in explicit mode.

- [ ] **Step 5: Add neutral past-date treatment**

Pass a past-selection flag into `_CalendarGrid` so the selected past cell uses muted styling. Show a small `Past date` chip beside the explicit date heading.

- [ ] **Step 6: Add selected-date empty copy**

Use `No events planned for this date.` when an explicit date has no events. Preserve the broader default empty states for an empty planner or no upcoming events.

### Task 3: Verify and commit

**Files:**
- Modify: `lib/src/features/tabs/planner_tab.dart`
- Modify: `test/features/planner_calendar_test.dart`

- [ ] **Step 1: Format touched Dart files**

```powershell
dart format lib/src/features/tabs/planner_tab.dart test/features/planner_calendar_test.dart
```

- [ ] **Step 2: Run targeted analysis**

```powershell
dart analyze lib/src/features/tabs/planner_tab.dart test/features/planner_calendar_test.dart
```

Expected: no errors or warnings introduced by this change.

- [ ] **Step 3: Run planner tests**

```powershell
flutter test test/features/planner_calendar_test.dart
```

Expected: all planner calendar tests pass.

- [ ] **Step 4: Check the diff**

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors and only the planned files are modified.

- [ ] **Step 5: Commit the implementation**

```powershell
git add lib/src/features/tabs/planner_tab.dart test/features/planner_calendar_test.dart docs/superpowers/plans/2026-06-12-planner-today-date-filter.md
git commit -m "fix(planner): open on today and filter selected dates"
```
