# Progress

## Current status

**Pass 1 (home/people UI consistency)** — shipped, including review fixes.
**Pass 2 (contact profile redesign)** — shipped, including review fixes.
**Pass 3 (per-contact memory files with agentic AI)** — PRD captured; not started.
**Test baseline (#032)** — fully closed. Typography hang fixed (Inter bundled). All residual failures resolved (parallel-review confirmed Pass 1 and Pass 2 regression-free; remaining failures were drift/fixture/pre-existing). Full sweep: **169 passed, 0 failed**.

## Issue status

### Done

- **#001–#025** — older waves (auth, design tokens, BondRing, Wave-1/2/3 UI work). Pre-existing in repo.
- **#026** — Query provider performance optimization (commit `7dddd7a`).
- **#027** — `BondRing` `showAvatar` parameter.
- **#028** — `ConnectionScoreHero` horizontal layout, `display`-size score.
- **#029** — `RecommendationCard` drops bottom action buttons.
- **#030** — `ContactListCard` density + numeric ring.
- **#031** — People tab search/sort typography normalized.
- **#032** — Test baseline closed. Inter bundled (`077ab33`); 8 follow-up fix commits resolved drift/fixture/pre-existing failures (`16bd3fc`, `e8481c3`, `5a6257c`, `c63c153`, `628a5ab`, `0db6cc2`, `0ca1c61`, `fff16ac`). Full sweep is now 169 passed, 0 failed.
- **#033** — Pass 2 tokens (`aiGradient`, `recommendationSurface`/`Border`, `topicAccent`) + redesigned header card with embedded Edit pill.
- **#034** — AI Insights collapsible card with Recommendation callout, Person Summary, Conversation Topics pills, tap-to-suggestions sheet.
- **#035** — Gradient AI action FAB replaces inline button.
- **#036** — Dense single-card History list with inline AI badge.

### Superseded (no longer pickable)

- **#017** — Older "contact profile redesign: cut redundant cards" framing. Pass 2 (#033–#036) supersedes the framing and the deliverable. The remaining behavior #017 promised is captured by Pass 2 commits and the dead-code cleanup in `4f8a736`.

### Open and pickable

- **#037** — Orphaned `ProfileScreen` and `HeatmapCard`. Surfaced by
  the parallel-review pass during #032 triage. The `/me` route still
  exists but no UI entry point reaches it. Pick one of two paths:
  delete the orphan code, or restore an entry point on the shell.
  Severity: nice-to-have. Not on the critical path.
- **Pass 3 (per-contact memory files)** — PRD lives at
  `docs/prd/2026-05-16-per-contact-memory-files-prd.md`. Issues not
  yet sliced.

## Pass 2 review-fix commits

After the Pass 2 feature commits, a parallel review surfaced one blocker plus five fix-now items. All applied as separate commits:

- `f5155d1` Header Edit pill no longer overlaps name (Stack→Row refactor + 320pt regression test).
- `55d833b` ListView bottom padding clears the gradient FAB (uses existing `pageBottomPadding`).
- `2843abf` `AiActionFab` Ink decoration so tap splash renders above the gradient + 2× `Colors.white` → `tokens.primaryOn`.
- `4f8a736` Delete dead `InsightCard`/`_InsightCardState`/`RelationshipFactsCard`/`_Fact` and the `findsNothing` regression guards on those literals.
- `b3fc3a6` `_TopicPill` `Colors.white` → `tokens.primaryOn` (last raw white literal in touched files).
- `709db7e` Self-contradicting empty-history test (asserted `findsNothing` then immediately scrolled to find content inside the same card).

## #032 residual-cleanup commits

A second parallel-review pass on 2026-05-18 (correctness + simplicity reviewers) confirmed Pass 1 and Pass 2 had zero real regressions in the failing test set. Every failure was drift/fixture/pre-existing. Eight commits closed the residual:

- `16bd3fc` `test(planner)`: helper now finds `'Plan'` (renamed in #016, helper missed). Unblocked all 5 Group C calendar tests.
- `e8481c3` `test(recommendation)`: assert Pass 2 AI Insights copy (`'AI Insights'`/`'Recommendation'`) instead of the old `'Recommended Action!'`/`'AI Insight'`.
- `5a6257c` `test(auth)`: drop stale `'Jamie Chen'` username assertion (#016 stopped surfacing username on shell chrome).
- `c63c153` `test(widget)`: remove dead `profile button opens heatmap profile` test; file `#037` follow-up for the orphaned `ProfileScreen`/`HeatmapCard`.
- `628a5ab` `test(widget)`: scope picker-modal finder via `find.descendant(of: UpdatePersonPickerModal)` to avoid duplicate `'Mike Chen'` match.
- `0db6cc2` `docs(032)`: rewrite residual section, document the parallel-review confirmation, preserve original 12-failure breakdown as history.
- `0ca1c61` `test(widget)`: expand surface size to 800×1200 for the Settings event-type test.
- `fff16ac` `fix(BondRing)`: remove `_isFirstBuild` flag that suppressed first-mount-after-score-change animation. Pre-existing bug from #021. Cosmetic polish.

## Test baseline progression

| Date | Sweep result | Notes |
|------|--------------|-------|
| Pre-Pass-1 | typography suite hangs >9 min, never completes | `GoogleFonts.pendingFonts()` blocks |
| Pass 1 + Pass 2 ships | 133 passed, 12 failed (typography excluded) | Relaxed bar accepted per #032 |
| `077ab33` (Inter bundled) | 158 passed, 12 failed (typography included, no longer hangs) | Hang fixed; same 12 fixture failures |
| `fff16ac` (#032 residual closed) | **169 passed, 0 failed** | Drift/fixture/pre-existing all resolved; baseline fully green |

## Verification

- `flutter analyze` clean (1 pre-existing info lint at `ai_update_screen.dart:88`, out of scope).
- `flutter test` (full sweep): **169 passed, 0 failed**.
- Typography test no longer hangs (23s vs >9 min indefinite).
- Parallel-review pass on 2026-05-18 confirmed Pass 1 and Pass 2 have zero real user-visible regressions.

## Notes for the next session

- Pass 3 is the natural next product-defining work. PRD is captured; needs grilling to slice into issues. Recommended order from the PRD: `MemoryDocument` parser → `MemoryStore` → `MockMemoryUpdater` → Riverpod providers + topic swap on the Pass 2 contact profile.
- API key UX, real LLM provider, and Firebase backend are explicitly post-Pass-3.
- #037 (orphaned `ProfileScreen`/`HeatmapCard`) is a nice-to-have cleanup that can be picked up alongside or after Pass 3.
