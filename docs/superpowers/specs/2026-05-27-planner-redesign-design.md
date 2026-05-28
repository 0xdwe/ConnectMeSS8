# Design Spec: Planner Redesign (UI Matching)

**Date:** 2026-05-27  
**Status:** Approved  
**Author:** Antigravity  

This design spec details the premium visual redesign of the Planner screen to match the user's mockup.

---

## 1. Top Bar Header

A row positioned at the top of the Planner tab that replaces the old large header:
- **Left Navigation:** A row containing:
  - `<` IconButton to go to the previous month.
  - Bold, premium month/year text (e.g. `April 2026`) in `AppTypography.h1()` / `tokens.ink` style.
  - `>` IconButton to go to the next month.
- **Right Action Buttons:** Two circular buttons:
  - **Search Button:** A circular container filled with `tokens.primary.withOpacity(0.12)` containing a search (magnifying glass) icon. Toggles an inline search bar below it.
  - **Add Button:** A circular container filled with `tokens.primary` containing a white `+` icon. Opens the standard `showAddEventModal`.
- **Inline Search Bar:** A text field container (`AppRadius.md`) that slides down when search is active, letting the user type queries to filter the event list instantly.

---

## 2. Calendar View Card

A container designed to look exactly like the mockup:
- **Card Container:** A rounded white box (`AppRadius.lg`, 18px), elevated using `AppTokens.elevation1()` for a modern, clean shadow.
- **Weekday Header:** A row/grid containing all-caps weekday headings: `SUN`, `MON`, `TUE`, `WED`, `THU`, `FRI`, `SAT` in `AppTypography.caption()` with color `tokens.inkMuted`.
- **42-Day Grid:**
  - Calculates the correct grid dates by finding the offset for the first day of the month and filling previous/next month days.
  - **Current Month Days:** Dark ink text (`tokens.ink`), bold/semi-bold.
  - **Selected Day:** Highlighted with a solid dark blue circle (e.g., `tokens.primary` or dark blue like `Color(0xFF2725C3)`) and white text.
  - **Previous/Next Month Days:** Greyed-out/muted text (e.g., `Color(0xFFD0CDE3)` or `tokens.inkSubtle`) to match the mockup's visual hierarchy.
  - **Event Dots:** If a day has any events, a tiny blue dot is rendered directly below the date number.

---

## 3. Upcoming Events & Premium Cards

Replaces the simple `ListTile` event rows with premium, highly structured cards:
- **Section Title:** "Upcoming Events" rendered in `AppTypography.h1()`, with a secondary calendar icon on the far right.
- **Grouping Headers:** Events grouped by day (e.g., "TOMORROW", "THURSDAY, APRIL 30") in all-caps, with a right-aligned badge pill showing the event count (e.g., "1 event") in `tokens.primaryTint` and text `tokens.primary`.
- **Premium Event Card:**
  - White surface background, rounded corners (`AppRadius.lg`), subtle border or shadow.
  - **Leading Container:** A soft-purple square (`tokens.primaryTint`, `AppRadius.md`) containing a context-aware emoji or icon (e.g., `☕` for coffee, `👥` for meetings/groups, `💼` for work, or `📅` default).
  - **Middle Content:** Event Title in `AppTypography.h2()` (semi-bold), and event time with a clock icon and subtitle in `AppTypography.caption()` / `tokens.inkMuted`.
  - **Footer Row (If Contact exists):**
    - A thin divider line separating content from the footer.
    - Footer row containing the contact's avatar, "with [Contact Name]" text, and a right chevron `>` icon in `tokens.primary`.
  - **Trailing Action (If no Contact exists):**
    - A trailing horizontal ellipsis `...` or delete/edit button on the right side.

---

## 4. Verification & Testing

- **Widget Tests:** Verify the `planner-tab` key is moved to a parent container so that `widget_test.dart` finds the `Scrollable` descendant properly and passes successfully.
- **Headless State Tests:** Ensure all existing 232 unit tests remain fully green.
