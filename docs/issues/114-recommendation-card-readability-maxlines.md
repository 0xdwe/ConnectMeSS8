# #114 — Card Readability: Increase Recommendation Reason maxLines

**Parent PRD:** `docs/prd/2026-06-14-recommendation-completion-prd.md`

---

## What to build

Increase `recommendation.reason` text line cap from 2 to 3 lines in `RecommendationCard`. Topic-driven recommendations (e.g. "Mike has Paris trip on their mind") currently truncate at 2 lines with no way to see the full message. At 3 lines, virtually all real-world recommendations fit without truncation. No other layout changes — card height grows naturally from content.

## Acceptance criteria

- [ ] `recommendation.reason` `maxLines` is 3 (was 2)
- [ ] Existing widget tests updated to assert `maxLines: 3`
- [ ] No other widget test regressions
- [ ] `dart analyze` clean
- [ ] `flutter test test/widgets/` green (targeted)

## Blocked by

None — can start immediately.
