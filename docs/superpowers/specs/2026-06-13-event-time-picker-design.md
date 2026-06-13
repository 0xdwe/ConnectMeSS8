# Event Time Picker Dropdown UI Refinement

## Status
Approved

## Problem
In the event modal (both Add Event and Edit Event states), the default clock dial time picker (`showTimePicker`) was slow to interact with and did not match the aesthetic and convenience of the inline dropdown selectors used in the notifications "Quiet Hours" dialog.

## Solution
Replace the default dial clock picker in `lib/src/features/modals/add_event_modal.dart` with a custom inline `_EventTimeRow` widget that provides three dropdowns for Hour, Minute, and Period (AM/PM), arranged inside a styled container matching the ConnectMe design system.

## Proposed Changes

### `lib/src/features/modals/add_event_modal.dart`
- Remove the old buttons that invoke `showTimePicker`.
- Insert two inline `_EventTimeRow` widgets for Start and End times when the "All Day" toggle is disabled.
- Add the `_EventTimeRow` widget at the end of the file. It will handle the extraction of values from a `TimeOfDay` object, display the dropdown options, and callback with an updated `TimeOfDay` when any dropdown changes.

### Custom UI Component: `_EventTimeRow`
- Left Label: Bold "Start" or "End" label with a fixed width of `44` to match the quiet hours picker exactly.
- Outer Box: Height of `52`, padded horizontally, filled with `tokens.surfaceSunken`, bordered by `tokens.border`, with small rounded corners (`AppRadius.sm`).
- Selectors:
  - **Hour Dropdown**: Values `1` to `12`.
  - **Separator**: `:` text.
  - **Minute Dropdown**: Values `00` to `59`.
  - **Period Dropdown**: `AM` or `PM`.
- Styling:
  - Dropdown values and dialog matching standard theme colors using `tokens.ink` and `tokens.surfaceRaised`.
  - Test keys to target elements:
    - Hour dropdown: `Key('${keyPrefix}-hour')`
    - Minute dropdown: `Key('${keyPrefix}-minute')`
    - Period dropdown: `Key('${keyPrefix}-period')`

## Verification Plan
- Verify that changes compile and that the widget build operates correctly under the emulator or via widget tests.
- Run `flutter analyze` and `flutter test test/widget_test.dart` to verify no regressions.
