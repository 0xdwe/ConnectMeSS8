# Refresh AI Insights Button

Labels: feature, ready-for-agent, pass-4.3-follow-up

## Parent

- PRD: `docs/prd/2026-06-13-memory-topic-backfill-prd.md`

## What to build

Implement a "Refresh" button with a refresh icon beside the "AI Insights" title in the card header. When clicked, it manually triggers the AI topic suggestion enrichment for this contact based on their current memory state and recent interactions, saving the updated memory back to Firestore.

## Acceptance criteria

- [ ] Add a refresh button with `Icons.refresh` beside the "AI Insights" title inside `AiInsightsCard` header row.
- [ ] Ensure tapping the refresh button does not toggle the expand/collapse state of the card.
- [ ] When the button is pressed, run `MemoryTopicEnricher.enrich()` using the `memoryTopicEnricherProvider`, active contact, memory, and recent 10 interactions.
- [ ] While the enrichment is in progress, disable the button and show a small `CircularProgressIndicator` instead of the refresh icon.
- [ ] Upon successful enrichment, save the updated `MemoryDocument` to the store and trigger notifier/epoch bumps.
- [ ] If enrichment fails, show a user-friendly `SnackBar` with the error message and restore the button state.
- [ ] Write targeted widget tests verifying the refresh button's presence, tap behavior, loading state, success path, and error handling.
- [ ] `git diff --check` passes.
- [ ] All targeted tests pass.

## Blocked by

- #105 Topic-scoped Conversation Topic panel
- #106 MemoryTopicEnricher single-contact enrichment
- #107 One-shot memory topic backfill runner and sentinel
