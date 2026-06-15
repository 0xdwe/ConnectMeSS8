# Recommendation Completion & Card Readability PRD

**Date:** 2026-06-14
**Status:** Grilled

---

## Problem Statement

When a user acts on a top recommendation (via AI Update), the recommendation silently vanishes from the home screen. There's no positive feedback — no "you did this, nice work" signal. The user sees a card, taps through to the contact, does an AI Update, and returns to find the card gone with no trace.

Additionally, recommendation cards with longer topic-driven text (e.g. "Mike has Paris trip on their mind") get cut off at 2 lines with no way to see the full message before navigating.

## Solution

### Completed recommendations

When a user completes an AI Update on a contact that was appearing as a top recommendation, the recommendation card transforms into a **completed card** for the remainder of the cache window. The card keeps its rank position, shows a checkmark with "✓ Reached out to <Name>" and the insight "Just updated with AI," uses a subdued visual treatment (muted tint, checkmark badge), and remains tappable to the contact profile.

Completed cards are in-memory only — they survive one cache recomputation window (up to 6 hours or until the next state change) and do not persist across app restarts.

### Card readability

The `recommendation.reason` text line cap increases from 2 to 3 lines. Most topic-driven recommendations fit comfortably in 3 lines; the card remains a preview that navigates to the contact profile for full context.

## User Stories

1. As a user who just did an AI Update on a recommended contact, I want to see that my action was acknowledged, so that I feel the app recognized my relationship maintenance effort.
2. As a user returning to the home screen after an AI Update, I want the completed card to stay in the same position the original recommendation held, so that I can see the transition from "you should do this" to "you did this."
3. As a user reading a completed card, I want to tap it and navigate to the contact's profile, so that I can review what the AI Update produced.
4. As a user who kills the app and relaunches it later, I want fresh recommendations without stale completed cards from the previous session.
5. As a user reading a topic-driven recommendation (e.g. "Mike has Paris trip on their mind"), I want to see the full reason text without truncation, so that I understand what the recommendation is about before tapping.
6. As a user with a short recommendation, I want the card height to stay compact, so that the home screen doesn't feel bloated.

## Implementation Decisions

### Recommendation completion detection

The `recommendationsProvider` (`lib/src/state/memory/memory_providers.dart`) already holds a `_RecommendationsCache` with the previous recommendation list, wall-clock `computedAt`, and dep identity slices. On recomputation, the provider passes the previous list to `rankRecommendations` as a new optional parameter `previousList`.

The engine compares the old and new lists: any contact that was in `previousList` but is NOT in the new ranked list and has a new `CrmInteraction` with `source == aiSuggested` whose `date` is strictly after `previousCache.computedAt` → produces a completed `Recommendation` instance with `isCompleted: true`.

Completed contacts keep their **original slot position** from the old list. If slot 1 was Mike and slot 2 was Sarah, and Mike is completed while Sarah still appears in the new list, the output becomes: [Mike (completed), Sarah (active), <next ranked>]. If a completed contact's slot position would exceed the 3-card cap, the card is dropped.

### `Recommendation` model extension

Two new optional fields on `Recommendation`:
- `isCompleted` (`bool`, defaults to `false`)
- `completedAt` (`DateTime?`, defaults to `null`)

Both fields are serialization-transparent (not persisted to Firestore). They exist only in the in-memory model.

### Card rendering

`RecommendationCard` renders two visual states:
- **Active**: unchanged from today's design
- **Completed**: checkmark icon (✓) replaces the priority badge; reason text shows "✓ Reached out to <contact.name>"; insight shows "Just updated with AI"; card background uses a subtly different tint (surface with reduced opacity); Bond Ring still visible but desaturated; still tappable → navigates to contact profile

### Text readability

`recommendation.reason` `maxLines` changes from `2` to `3`. No other layout changes. Card height grows naturally from the content; the row alignment stays centered.

### Cache window

Completed cards survive exactly one recomputation. When the cache invalidates (memory change or 6h elapsed), the next engine run receives a new `previousList` that no longer contains the completed contacts' old entries → no completed cards are produced. This is the "in-memory only" contract.

### Completed card count

At most one completed card per recomputation. If multiple contacts were acted upon in the same window, only the highest-ranked original slot produces a completed card (the others drop silently, per the existing vanish behavior). This prevents the top-3 from being dominated by completed cards.

## Testing Decisions

### What makes a good test

Tests exercise the pure function `rankRecommendations` with controlled inputs — never the Riverpod provider lifecycle. Each test: construct connections, interactions, memories, and a `previousList`; assert the output list contains expected cards at expected positions with correct `isCompleted` flags.

### Modules tested

1. **RecommendationEngine** (new unit tests in `test/state/recommendation_engine_test.dart`):
   - Completed card appears when contact was in previousList, dropped off, has new aiSuggested interaction after cache time
   - Completed card does NOT appear when interaction is manual source
   - Completed card does NOT appear when contact is still in the new list
   - Completed card keeps original slot position
   - At most 1 completed card per recomputation
   - Completed card does NOT appear without previousList

2. **RecommendationCard widget** (existing or new tests in `test/widgets/`):
   - Completed card renders checkmark and "Reached out to" copy
   - Completed card renders "Just updated with AI" insight
   - Completed card is tappable
   - Active cards unchanged (no regression)

3. **Readability** (existing tests):
   - `maxLines: 3` asserts in existing widget tests (update the expected value)

### Prior art

Existing `rankRecommendations` tests in `test/state/recommendation_engine_test.dart`. Follow the same fixture-construction pattern: `Connection(...)` / `CrmInteraction(...)` / `MemoryDocument(...)` seeded programmatically.

## Out of Scope

- Persisting completed recommendations to Firestore
- "Dismiss" action on completed cards
- Completed cards surviving app restart
- Topic-driven recommendation copy changes (the 3-line cap is a layout fix, not a copy rewrite)
- Changes to the Recommendations screen (only the Home tab card rendering)

## Further Notes

- The `_RecommendationsCacheHolder` already exists and is read during recomputation. No new provider is needed — the `recommendationsProvider` reads the holder, extracts the old list, and passes it to the engine.
- The engine function signature adds one optional parameter: `List<Recommendation>? previousList`.
- The `_recommendationPriority` label in completed cards is replaced by the checkmark — the priority badge slot is repurposed.
