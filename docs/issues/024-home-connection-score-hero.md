# Home Connection Score Hero

Labels: enhancement, ready-for-agent, wave-3

> *Created 2026-05-15 per user request.*

## AI Triage Brief

**Category**: enhancement. Restores a Connection Score hero card on the Home tab, calculated as the average bond score across all connections.

**State**: ready-for-agent. Replaces the simple "Hi, Alex." greeting added in issue #012 with a visual hero that shows the user's overall relationship health.

**Context**:
- Issue #012 removed `BigScoreCircle` from `home_tab.dart` and replaced it with a plain text greeting.
- User wants the Connection Score back as a meaningful metric: average of all `connection.bondScore` values.
- The score should use the new `BondRing` component (from #012) instead of the old `BigScoreCircle`.
- This is a **hero moment** on Home — the first thing users see when they open the app.

**Codebase notes**:
- `AppState.averageConnectionScore` already exists and calculates the average bond score across all connections (verified in `lib/src/state/app_state.dart`).
- `home_tab.dart` currently renders a simple greeting: `Text('Hi, Alex.', style: AppTypography.bodyLg())` (added in commit 1a1cd08).
- `BondRing` component exists in `lib/src/widgets/bond_ring.dart` but expects a `Connection` object. For the average score, we need a variant that accepts a raw score.

**Implementation notes for the agent**:
- Add a new widget `ConnectionScoreHero` to `lib/src/widgets/crm_widgets.dart` (or a new file if preferred).
- Anatomy:
  - Large `BondRing` (size: 120 or 150) showing the average score.
  - Since `BondRing` expects a `Connection`, either:
    - **Option A**: Add a `BondRing.fromScore({required int score, required String label})` named constructor that renders the ring without needing a full `Connection` object. The label becomes the semantic name ("Overall connection health").
    - **Option B**: Create a synthetic `Connection` object with the average score and a placeholder name like "Overall".
    - **Recommendation**: Option A is cleaner. Add the named constructor to `BondRing`.
  - Below the ring: label "Connection Score" in `AppTypography.h2()`.
  - Below the label: caption "Average across all connections" in `AppTypography.caption(color: tokens.inkMuted)`.
  - Wrap in a `CardBox` (existing widget in `crm_widgets.dart`) for visual consistency with other Home cards.
- Update `home_tab.dart`:
  - Remove the `Text('Hi, Alex.', style: AppTypography.bodyLg())` line.
  - Add `ConnectionScoreHero(score: state.averageConnectionScore)` at the top of the ListView children.
- Semantic label: "Connection score: 73, close, trending up" (or similar). Use the same tier/trend logic as individual bond rings.
- Touch target: the ring itself doesn't need to be tappable for the hero (unlike individual contact rings). If you want tap-to-reveal behavior (show the numeric score), add it as optional. Otherwise, always show the score beneath the ring.
- **Do NOT** add the fill animation in this PR. That's issue #021.
- **Do NOT** change the recommendation cards or other Home content. This PR only adds the hero card.

## What to build

A `ConnectionScoreHero` widget that shows the user's average bond score as a large `BondRing` with a label and caption, replacing the plain greeting on Home.

## Acceptance criteria

- [ ] `BondRing.fromScore({required int score, required String label})` named constructor exists (or equivalent approach that doesn't require a full `Connection` object).
- [ ] `ConnectionScoreHero` widget exists in `lib/src/widgets/crm_widgets.dart` (or new file).
- [ ] Hero shows a 120-150pt `BondRing` with the average score, tier color, and optional trend arrow.
- [ ] Label "Connection Score" in `h2`, caption "Average across all connections" in `caption` / `inkMuted`.
- [ ] Wrapped in `CardBox` for visual consistency.
- [ ] `home_tab.dart` renders `ConnectionScoreHero(score: state.averageConnectionScore)` at the top of the ListView.
- [ ] Semantic label: "Connection score: <score>, <tier>, <trend>".
- [ ] Existing widget tests pass. New test: `ConnectionScoreHero` renders with correct tier color for score 90 / 60 / 30.
- [ ] `flutter analyze` clean.

## Blocked by

- #012 (BondRing component): needs `BondRing` and `BondTier` logic.

## Wave

Wave 3 (visual surfaces). Should be implemented after #012 (BondRing) but can be done in parallel with #015-#019.
