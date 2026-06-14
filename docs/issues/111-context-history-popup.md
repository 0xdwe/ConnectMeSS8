# Context History Popup Modal

Labels: feature, ready-for-agent

## Parent

- PRD: N/A

## What to build

Add an open link button (`Icons.open_in_new`) inside the AI suggestion cards next to the "Context :" header. When pressed, it opens a blurred-background dialog displaying the contact's interaction history, memory bullets, and custom notes that match keywords from the suggestion's Topic. The dialog will display styled cards with source badges, dates, and the specific matching content, complete with a close button in the top right.

## Acceptance criteria

- [ ] Convert `_InlineTopicDetails` in `lib/src/widgets/crm_widgets.dart` to a `ConsumerWidget`.
- [ ] Define stop words and keyword extraction logic using the suggestion's Topic.
- [ ] Fetch the connection's interactions using `ref.watch(interactionsByContactProvider(connection.id))`.
- [ ] Implement search matching logic across all three sources:
  - `CrmInteraction`s: match title or note content.
  - `MemoryDocument.history`: match specific date-prefixed bullets.
  - `Connection.notes`: match specific custom note lines.
- [ ] Sort matched items by date descending (non-dated items like custom note lines placed at the end, sorted by match score).
- [ ] Add an `IconButton` with `Icons.open_in_new` next to the "Context :" text in the suggestion card, positioned neatly.
- [ ] Implement a general dialog overlay (`showGeneralDialog` with `BackdropFilter` and `ImageFilter.blur`) containing:
  - Blurred backdrop behind the dialog.
  - Close button in the top right of the dialog container.
  - Dialog title showing "Context History: [topic]".
  - A scrollable list of matching cards, each showing a source badge (e.g. "Check-in", "Memory", "Note"), date (if available), and the matching text/details.
  - Friendly empty state when no matches are found.
- [ ] Verify the popup UI rendering and keyword matching logic with unit or widget tests.

## Blocked by

- None
