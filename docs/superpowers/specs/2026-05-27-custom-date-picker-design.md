# Custom Date Picker Dialog Design

Redesign the date picker dialog inside the Add/Edit Event modal to match the custom, premium design of the main Planner page calendar.

## Goals
- Replace the standard Material DatePicker popup with a custom dialog (`_CustomDatePickerDialog`).
- Match the visual appearance and color theme of the main Planner calendar tab.
- Replicate the 42-day continuous calendar grid logic and weekday headers.
- Show event indicator dots below the date numbers, providing day-level scheduling context.

## UI Components

### 1. Dialog Container & Layout
- A compact, responsive, centered floating `Dialog`.
- Rounded corners (`AppRadius.lg`), white/dark-mode responsive surface (`tokens.surface`), and soft premium shadow.
- Width: Compact sizing (approx. 320px).

### 2. Header & Month Navigation
- Bold month and year heading (e.g., "April 2026") styled with `AppTypography.h1`.
- Sleek chevron icons (`Icons.chevron_left` and `Icons.chevron_right` using `tokens.primary`) to navigate months.

### 3. Weekday Labels
- A row of weekdays header: `SUN`, `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT`.
- Small, uppercase, semi-bold font matching the main Planner calendar exactly.

### 4. 42-Day Continuous Calendar Grid
- Highlighted selected day in a solid purple circle (`tokens.primary`) with white text (`tokens.primaryOn`).
- Today highlighted with a purple text color (`tokens.primary`).
- Current month days highlighted with primary body text color (`tokens.ink`).
- Out-of-month days styled with faded text (`tokens.inkSubtle.withOpacity(0.5)`).
- Centered event dots underneath date numbers, fetched via Riverpod state (`appControllerProvider`).

### 5. Action Buttons (Cancel / OK)
- Row of Cancel and OK buttons.
- Cancel closes dialog without saving.
- OK closes dialog, passing back the temporary selected date.

## Code Impl Location
- `lib/src/features/modals/add_event_modal.dart` (Self-contained in the file to maintain clean structure).
