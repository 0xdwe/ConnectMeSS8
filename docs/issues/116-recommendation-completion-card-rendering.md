# #116 — Recommendation Completion: Card Rendering

**Parent PRD:** `docs/prd/2026-06-14-recommendation-completion-prd.md`

---

## What to build

`RecommendationCard` renders a visually distinct **completed** state when `recommendation.isCompleted` is true.

### Active state (unchanged)

Existing rendering: avatar, name, reason, insight, action, priority badge, BondRing. No changes.

### Completed state

When `isCompleted` is true:
- **Badge area**: priority pill replaced with a checkmark icon (✓) with a subtle green/success tint background
- **Reason text**: shows "✓ Reached out to <connection.name>"
- **Insight text**: shows "Just updated with AI"
- **Card background**: slightly subdued (e.g. surface with reduced elevation or a lighter tint) to visually distinguish from active cards
- **BondRing**: still visible but rendered with muted/desaturated colors (optional — skip if over-engineering)
- **Tap behavior**: unchanged — still navigates to contact profile

## Acceptance criteria

- [ ] Completed card renders checkmark badge (not priority pill)
- [ ] Completed card shows "✓ Reached out to <Name>" as reason
- [ ] Completed card shows "Just updated with AI" as insight
- [ ] Completed card background is visually distinct from active cards
- [ ] Completed card is still tappable (navigates to contact profile)
- [ ] Active cards render unchanged (no regression)
- [ ] Widget tests cover both active and completed states
- [ ] `flutter test test/widgets/` green (targeted)
- [ ] `flutter test test/state/recommendation_engine_test.dart` green
- [ ] `dart analyze` clean

## Blocked by

- #115 — `Recommendation.isCompleted` and `completedAt` fields must exist, and the engine must emit completed cards.
