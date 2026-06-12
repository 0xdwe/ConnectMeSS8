# Planner Today and Date Filter Design

## Goal

Make the Plan tab open in the user's current month and give date selection a
clear, predictable effect on the event list.

## Behavior

### Default state

- On first opening the Plan tab, the calendar displays the current month and
  highlights today.
- The event section title is `Today & Upcoming`.
- The list includes events dated today or later, grouped by date.

### Explicit date selection

- Tapping any calendar day activates a date filter.
- The calendar moves to that day’s month when an adjacent-month cell is tapped.
- The event section title becomes the selected date, formatted as
  `EEEE, MMMM d`.
- The list includes only events on the selected date.
- Tapping today’s calendar cell is still an explicit filter and therefore shows
  only today’s events.
- A selected date with no events shows `No events planned for this date.`

### Returning to today

- A visible `Today` button appears in the calendar header.
- Tapping it returns the calendar to the current month, selects today, and exits
  the explicit date filter.
- The event list returns to `Today & Upcoming`.
- The current date is recalculated when the button is tapped so a long-running
  app can cross midnight correctly.

### Past-date context

- Past dates remain selectable.
- An explicitly selected past date uses neutral selected-day styling instead of
  the primary active color.
- The event section displays a subtle `Past date` status chip.
- Copy remains factual and neutral.

### Month navigation

- Previous/next month controls only change the visible calendar month.
- They do not alter the selected date or event-list mode.
- The `Today` button is the explicit reset path.

## Implementation

`PlannerTab` keeps three pieces of local UI state:

- visible month
- selected day
- whether the user has explicitly selected a day

Date comparisons normalize values to local midnight. Filtering remains local to
the tab and does not change `PlannerEvent`, `AppController`, or persistence.

## Verification

Targeted widget tests cover:

- current month and today on initial entry
- default today-and-upcoming mode
- explicit date selection showing only that date
- `Today` restoring default mode
- selected past-date indicator and neutral styling
- selected-date empty state

Run the planner widget test file and touched-file Dart analysis. Do not run the
full Flutter test sweep.
