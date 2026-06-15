# Review — TEST COVERAGE for recommendation completion feature

**Reviewed:** `test/state/recommendation_engine_test.dart`, `test/state/recommendations_provider_test.dart`, `test/widgets/recommendation_card_test.dart`, `test/state/ai/llm_ai_update_test.dart`
**Date:** 2026-06-14

---

## Correct

### All targeted test suites pass cleanly

- `flutter test test/state/recommendation_engine_test.dart` — **37 passed, 0 failed**
- `flutter test test/state/recommendations_provider_test.dart` — **13 passed, 0 failed**
- `flutter test test/widgets/recommendation_card_test.dart` — **17 passed, 0 failed**
- `flutter test test/state/ai/llm_ai_update_test.dart` — **42 passed, 0 failed**
- `flutter test test/state/` (full sweep) — **493 passed, 0 skipped, 0 failed**

### Engine: completion detection tests are well-structured (7 tests)

`test/state/recommendation_engine_test.dart`, lines ~550–740 in the `rankRecommendations — completion detection (#115)` group:

1. **completed card emitted when contact dropped off and has new aiSuggested interaction after cache time** — Happy path: Alice in previousList, not in new top-3, has a post-cache `InteractionSource.aiSuggested` interaction → completed card emitted at index 0. Verifies `reason`, `insight`, `isCompleted`, `completedAt`. (line ~556)

2. **completed card NOT emitted for manual source interaction** — Same setup but `InteractionSource.manual` → no completed card. Correctly gates on `aiSuggested` only. (line ~590)

3. **completed card NOT emitted when contact stays in new list** — Alice stays in top-3; no completed card emitted. Verifies guard: `newContactIds.contains(prev.contactId)` short-circuits. (line ~617)

4. **at most 1 completed card per recomputation** — Two contacts both drop off and both have aiSuggested interactions. Only first (Alice) gets completed; Bob gets skipped because the completed-card branch `return`s after inserting one. (line ~646)

5. **completed card NOT emitted without previousList (backward compat)** — `previousList` is null/default → `isCompleted` stays false for all cards. (line ~686)

6. **completed card NOT emitted when interaction date is before cache time** — Interaction date predates `previousCacheTime` → no completion. Correctly tests the `ix.date.isAfter(previousCacheTime)` guard. (line ~704)

7. **completed card NOT emitted when no interactions exist for the dropped contact** — Alice drops off the list entirely (top-3 is empty), but no interactions exist → no completed card. (line ~730)

### Widget: completed card tests verify core behavior (2 tests)

`test/widgets/recommendation_card_test.dart`, lines ~387–417:

1. **completed card shows Done badge** — Verifies `Done` text, `✓ Reached out to Mike`, and `Just updated with AI` all appear. (line ~387)

2. **completed card is still tappable** — `onTap` callback fires on completed card tap. (line ~405)

### Classifier TDD tests: all 6 pass with `onClassifierPassed`

`test/state/ai/llm_ai_update_test.dart`, lines ~600–800 in the `LlmAiUpdate relevance pre-classifier TDD` group:

1. `failOnRelevanceCheck = true throws AiUpdateRejected` — Passes.
2. `classifier pass path proceeds to main Gemini call and triggers onClassifierPassed` — Passes (calls `geminiGenerateContent` 2 times, `classifierPassedCalled` is `true`).
3. `classifier fail path throws AiUpdateRejected and does not call main Gemini` — Passes (`callCount == 1`, `classifierPassedCalled` is `false`).
4. `classifier timeout (5s) fails open, calling main Gemini` — Passes (6s delay triggers timeout; main Gemini still called; `classifierPassedCalled` is `false`).
5. `classifier exception fails open, calling main Gemini` — Passes (exception triggers fail-open; main Gemini called; `classifierPassedCalled` is `false`).
6. `classifier cancellation throws AiUpdateCancelled` — Passes (cancel token wins the race).

---

## Blocker

*None.* All test suites pass cleanly. No test failures were found.

---

## Gaps (Notes)

### Gap 1: Engine — duplicate contact in previousList

`test/state/recommendation_engine_test.dart`, completion detection group

**Missing test:** A contact appearing **twice** in `previousList` (same contactId at two different slot positions).

The production code iterates `previousList` with a plain `for` loop (engine line 105). If the same contactId appears at positions 0 and 2:
- If it's still in the new list, both positions are skipped (`continue` at line 108). No issue.
- If it's dropped and the first occurrence triggers the completed card, the `return` at line 148 exits the loop before reaching the second occurrence. No issue.
- BUT if the first occurrence of a duplicate does NOT qualify for a completed card (e.g. no aiSuggested interaction), the loop moves to the next slot. The second occurrence could then fire a completed card that the first would have consumed. The current code would emit a completed card for the **second** position, which may shift slot ordering in subtle ways.

The risk is low in practice (duplicate contactIds in `previousList` shouldn't happen under the current provider), but it's an untested edge case worth acknowledging.

### Gap 2: Engine — fallback `Connection` when contact not found

`lib/src/state/recommendation_engine.dart`, lines 119–130

The `connections.firstWhere(... orElse: ...)` at line 119 creates a **synthetic fallback Connection** when the dropped contact is no longer in the active `connections` list (e.g. the contact was deleted). This path has **zero test coverage**.

The fallback produces `contact.name = prev.contactId` (the raw ID string), so the completed card reason would read `✓ Reached out to a1b2c3d4...` — an opaque Firebase ID rather than a human-readable name. This is a minor UX degradation at worst (deleted contacts are rare), but the path should still be tested.

**Suggested test:**
```dart
test('completed card uses fallback Connection name when contact not found', () {
  // prev.contactId = 'deleted' with aiSuggested interaction
  // connections = [] (empty — contact was deleted)
  // Should emit completed card with name = 'deleted' (the ID fallback)
});
```

### Gap 3: Provider — no end-to-end Riverpod chain test for completed cards

`test/state/recommendations_provider_test.dart`

**Missing:** A test that exercises the full provider lifecycle: read initial recommendations → perform AI Update on a contact → read again → verify completed card appears in the result list.

The existing tests verify:
- Initial read emits a ranked list
- Cache invalidation via memory epoch bump
- AI update commit bumps memory epoch

But none of them verify that after an AI Update, the **completed card detection** works end-to-end. The test `AI update commit bumps memoryEpoch which invalidates recommendations cache` (line ~300) proves the cache is invalidated, but it does **not** assert that a completed card appears in the re-read result.

The provider test does wire up `MockAiUpdate` which produces `source: aiSuggested` interactions, so an end-to-end test is feasible:
1. Read `recommendationsProvider.future` → get initial list
2. Call `aiUpdateProvider.read().run()` + `commit()` on a top-ranked contact
3. Read `recommendationsProvider.future` again
4. Assert `after.any((r) => r.isCompleted)` and `completed.contactId == mike.id`

### Gap 4: Widget — completed card doesn't verify action text hiding

`test/widgets/recommendation_card_test.dart`, lines 387–417

The widget code at `crm_widgets.dart` line 488 gates the `action` text behind `if (!isCompleted)`:
```dart
if (recommendation.action case final action?)
  if (!isCompleted) ...[
```

The two completed card tests (lines 387, 405) verify:
- `Done` badge appears ✓
- Reason/insight text appears ✓
- Card is tappable ✓

But **neither test** creates a completed recommendation that **also has a non-null `action` field** to verify the action text is suppressed. The test at line 387 uses a bare `Recommendation(isCompleted: true)` with no `action` parameter, so the hide-guard is never exercised.

**Suggested test:**
```dart
testWidgets('completed card hides action text even when present', (tester) async {
  await tester.pumpWidget(buildTestCard(
    recommendation: const Recommendation(
      contactId: 'test-1',
      reason: '✓ Reached out to Mike',
      insight: 'Just updated with AI',
      priority: 'completed',
      isCompleted: true,
      action: 'Ask how the Paris plans are coming together.', // Should be hidden
    ),
  ));
  expect(find.text('Ask how the Paris plans are coming together.'), findsNothing);
});
```

---

## Summary

| Item | Status |
|------|--------|
| Engine completion tests (7) | ✅ Pass. Good coverage of happy path, source gating, stay-in-list, max-one-card, backward compat, stale-interaction, no-interaction |
| Engine: duplicate in previousList | ⚠️ Untested edge case |
| Engine: fallback Connection name | ⚠️ Untested path (`orElse` at engine line 119) |
| Provider: full Riverpod E2E chain | ⚠️ No end-to-end test for read→update→read→completed |
| Widget: completed card action hiding | ⚠️ Not verified that action text is hidden |
| Classifier TDD tests (6) | ✅ Pass. `onClassifierPassed` callback correctly exercised |
| All suites green | ✅ 493/493 passed in `test/state/` |
