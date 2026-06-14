# #118 — Dynamic Recommendation Banner in AiInsightsCard

**Parent PRD:** `docs/prd/2026-06-14-recommendation-completion-prd.md`

---

## What to build

The `AiInsightsCard` recommendation banner currently uses static URL query params (`recommendationReason`, `recommendationInsight`, `recommendationAction`) passed during navigation. This banner is a frozen snapshot — it never updates after the user does an AI Update, even though the recommendation was addressed.

Fix: make the banner dynamic. The `AiInsightsCard` reads the live `recommendationsProvider` to determine the current recommendation state for the displayed contact. The banner reflects the real-time state.

### Banner states

**Active recommendation**: the contact appears in the current recommendation list (not completed). Show the recommendation text: reason + insight + action. Same visual as today.

**Completed recommendation**: the contact has a completed recommendation (in the `recommendationsProvider` output with `isCompleted: true`, or detected via `lastAiUpdatedContactId`). Show checkmark + "✓ Reached out to <Name>" + "Just updated with AI". Mirrors the home card's completed styling.

**No recommendation**: the contact is not currently recommended and has no completed recommendation. **No banner at all** — the card body shows only the Person Summary and Conversation Topics (the pre-#PRD state).

### Implementation

`AiInsightsCard` (or its `_AiInsightsBody` child) reads `recommendationsProvider` and looks up the current contact's ID:

```dart
final recommendations = ref.watch(recommendationsProvider);
final recForThisContact = recommendations.valueOrNull
    ?.where((r) => r.contactId == widget.connection.id)
    .firstOrNull;
```

If `recForThisContact` is non-null:
- If `recForThisContact.isCompleted`: render completed banner
- Otherwise: render active banner with `recForThisContact.reason` / `insight` / `action`

If `recForThisContact` is null: no banner.

### Remove static URL param approach

The static `recommendationReason`/`recommendationInsight`/`recommendationAction` params on `ContactProfileScreen` and `AiInsightsCard` are no longer needed. Remove them and clean up the route query param construction in `home_tab.dart` and `recommendations_screen.dart`.

The `topic` query param is preserved — it still selects the initial topic in the Conversation Topics panel.

## Acceptance criteria

- [ ] `AiInsightsCard` reads `recommendationsProvider` to get live recommendation state
- [ ] Active recommendation: shows reason + insight + action with lightbulb icon
- [ ] Completed recommendation: shows "✓ Reached out to <Name>" + "Just updated with AI" with checkmark icon
- [ ] No recommendation: no banner at all
- [ ] Static `recommendationReason`/`recommendationInsight`/`recommendationAction` params removed from `ContactProfileScreen` and `AiInsightsCard`
- [ ] Route query params in `home_tab.dart` and `recommendations_screen.dart` no longer include reason/insight/action (topic only preserved)
- [ ] Existing widget tests updated (remove references to static params, add dynamic banner tests)
- [ ] `flutter test test/widgets/` green
- [ ] `flutter test test/state/` green
- [ ] `dart analyze` clean

## Blocked by

- #117 — `lastAiUpdatedContactId` must exist in `AppState` and be consumed by `recommendationsProvider` for the completed state to appear in the banner.
