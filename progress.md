# Progress

## Current status

**Pass 1 (home/people UI consistency)** — shipped, including review fixes.
**Pass 2 (contact profile redesign)** — shipped, including review fixes.
**Pass 3 (per-contact memory files with agentic AI)** — PRD captured; not started.
**Test baseline (#032)** — still 12 failures pending. Pass 2 ships under the relaxed bar (`flutter analyze` clean, no new failures vs baseline 12).

## Issue status

### Done

- **#001–#025** — older waves (auth, design tokens, BondRing, Wave-1/2/3 UI work). Pre-existing in repo.
- **#026** — Query provider performance optimization (commit `7dddd7a`).
- **#027** — `BondRing` `showAvatar` parameter.
- **#028** — `ConnectionScoreHero` horizontal layout, `display`-size score.
- **#029** — `RecommendationCard` drops bottom action buttons.
- **#030** — `ContactListCard` density + numeric ring.
- **#031** — People tab search/sort typography normalized.
- **#033** — Pass 2 tokens (`aiGradient`, `recommendationSurface`/`Border`, `topicAccent`) + redesigned header card with embedded Edit pill.
- **#034** — AI Insights collapsible card with Recommendation callout, Person Summary, Conversation Topics pills, tap-to-suggestions sheet.
- **#035** — Gradient AI action FAB replaces inline button.
- **#036** — Dense single-card History list with inline AI badge.

### Superseded (no longer pickable)

- **#017** — Older "contact profile redesign: cut redundant cards" framing. Pass 2 (#033–#036) supersedes the framing and the deliverable. The remaining behavior #017 promised is captured by Pass 2 commits and the dead-code cleanup in `4f8a736`.

### Open and pickable

- **#032** — Test suite baseline failures (typography hang + ~12 widget failures). Reduces CI signal value until fixed; documented as a separate maintenance issue. Independently scoped, no feature blockers depend on it.
- **Pass 3 (per-contact memory files)** — PRD lives at `docs/prd/2026-05-16-per-contact-memory-files-prd.md`. Issues not yet sliced.

## Pass 2 review-fix commits

After the Pass 2 feature commits, a parallel review surfaced one blocker plus five fix-now items. All applied as separate commits:

- `f5155d1` Header Edit pill no longer overlaps name (Stack→Row refactor + 320pt regression test).
- `55d833b` ListView bottom padding clears the gradient FAB (uses existing `pageBottomPadding`).
- `2843abf` `AiActionFab` Ink decoration so tap splash renders above the gradient + 2× `Colors.white` → `tokens.primaryOn`.
- `4f8a736` Delete dead `InsightCard`/`_InsightCardState`/`RelationshipFactsCard`/`_Fact` and the `findsNothing` regression guards on those literals.
- `b3fc3a6` `_TopicPill` `Colors.white` → `tokens.primaryOn` (last raw white literal in touched files).
- `709db7e` Self-contradicting empty-history test (asserted `findsNothing` then immediately scrolled to find content inside the same card).

## Verification

- `flutter analyze` clean (1 pre-existing info lint at `ai_update_screen.dart:88`, out of scope).
- `flutter test` (full sweep): 133 passed, 12 failed. Failure count exactly matches the #032 baseline — no new failures introduced by Pass 1, Pass 2, or the review fixes.

## Notes for the next session

- Pass 3 needs slicing into vertical issues from the PRD (`MemoryDocument` parser → `MemoryStore` → `MockMemoryUpdater` → Riverpod providers + topic swap on contact profile). Recommended order: parser/store/mock first, then provider integration, then swap the Pass 2 topics widget data source.
- API key UX, real LLM provider, and Firebase backend are explicitly post-Pass-3.
- #032 is the right next mechanical pickup if Pass 3 can wait — fixing the typography hang is small and unblocks strict-bar verification for everything that follows.
