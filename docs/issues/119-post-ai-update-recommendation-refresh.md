# #119 — Post-AI-Update Recommendation Refresh

**Parent PRD:** N/A (standalone polish)  
**Branch:** `feat/119-post-ai-update-recommendation-refresh`

---

## What to build

Two tightly-coupled changes that close the UX gap where the Recommendation callout inside `AiInsightsCard` stays stale after the user completes an "Update with AI" flow:

### 119-A — Auto-invalidate `recommendationsProvider` after AI Update commit

After `AiUpdate.commit()` succeeds in `AiUpdateScreen.save()`, the app
currently signals `pendingAiInsightsRefreshProvider` (which triggers the
topic-enricher refresh) but does **not** force `recommendationsProvider` to
recompute synchronously.

The existing `recommendationsCacheProvider` cache means the Recommendation
callout can stay frozen at whatever it said before the update for up to 6
hours, even though the user just logged an interaction.

**Fix:**

1. In `AppController.applyAiUpdateResult` (called from `LlmAiUpdate.commit` /
   `MockAiUpdate.commit`), after writing the interaction and memory, **clear
   `recommendationsCacheProvider.cache`** so the next read of
   `recommendationsProvider` skips the cache and recomputes with the fresh
   interaction list.  
   This is already partially done for `lastAiUpdatedContactId` (#117);
   we also need `holder.cache = null` to bust the freshness guard.

2. `recommendationsProvider` will then recompute on the next frame after
   `AiInsightsCard` rebuilds, picking up the new interaction from Firestore
   (fast path) or from the in-memory `AppState.interactions` (immediate).

### 119-B — Memory-grounded Recommendation copy after refresh

Currently when the recommendation refreshes the engine only knows how to
produce "Wondering how X has been?" or topic-based copy — it has no notion
of "relationship is healthy / up to date."

After an AI Update commit for contact C, if the engine computes
`MaintenanceNeed.none` for C (the interaction just logged satisfies the
cadence), the recommendation callout for C should shift to a positive,
affirming card rather than disappearing silently.

**New state: `MaintenanceNeed.none` → show "You're up to date" card**

Add logic inside `rankRecommendations` (or a new helper) so that when
`lastAiUpdatedContactId` is set and that contact evaluates to
`MaintenanceNeed.none`:

- Return a `Recommendation` with `isCompleted: true` and copy such as:
  - `reason`: `"You're in a good place with ${name}."`
  - `insight`: `"This relationship looks healthy — keep it up."`
  - `priority`: `'completed'`
  - `completedAt`: `now`

This card supersedes the existing "✓ Reached out to X" fast-path card (#117)
for the `none`-need case (the relationship genuinely doesn't need action,
not just that the top-3 slots are full).

The card lives in the same slot as the old recommendation so the AiInsightsCard
callout transitions smoothly from "check-in needed" → "you're up to date."

---

## Acceptance criteria

- [ ] After completing "Update with AI" for contact C, the Recommendation
      callout inside `AiInsightsCard` for C refreshes **without** the user
      manually pressing the refresh button.
- [ ] If C still has `MaintenanceNeed.high/medium/low` after the update,
      the callout shows the normal recommendation (unchanged behavior).
- [ ] If C now has `MaintenanceNeed.none` after the update, the callout
      shows an affirmative "You're in a good place with X" card with
      `isCompleted: true`.
- [ ] The manual refresh button still works independently (unchanged).
- [ ] `recommendationsCacheProvider.cache` is null after
      `AppController.applyAiUpdateResult` runs (verifiable in unit test).
- [ ] New unit tests in `test/state/recommendation_engine_test.dart` cover
      the `none`-need + `lastAiUpdatedContactId` → affirmative-card path.
- [ ] Targeted test run `flutter test test/state/recommendation_engine_test.dart`
      and `flutter test test/state/` GREEN.

---

## Blocked by

Nothing. Independent of #112/#113.

---

## Notes

- Do **not** add numeric day counts or guilt phrasing anywhere in the copy
  (anti-shame guardrail, AGENTS.md).
- The "you're up to date" card must set `isCompleted: true` so `AiInsightsCard`
  renders it with the green success styling already wired in #116.
- Cache clearing should be a single `holder.cache = null;` line in
  `AppController.applyAiUpdateResult`; no structural changes to the cache
  shape are needed.
- `pendingAiInsightsRefreshProvider` continues to drive the topic-enricher
  refresh; this issue only adds the recommendation cache bust on top of it.
