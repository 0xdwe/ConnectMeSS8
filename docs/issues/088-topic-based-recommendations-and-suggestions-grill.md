# 088 — Grill topic-based recommendations and topic-tap suggestions

## Parent

Pass 4.3 LLM AI Update PRD: `docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md`

## What to build

Run a design grill for how Gemini-written `MemoryDocument.topics` should power user-facing recommendations and topic-tap suggestions. The current topic tap behavior falls back to static templates, so useful Gemini topics such as "Paris trip" or "currency" can still produce generic suggestions. This issue produces a PRD / follow-up implementation issues; it does not require product code.

## Acceptance criteria

- [x] Decide whether topic suggestions are generated eagerly during AI Update, lazily on tap, or via a template + memory hybrid. Decided: prepared eagerly during AI Update; deterministic template/hybrid fallback when missing.
- [x] Decide whether generated suggestions are persisted, cached, or ephemeral. Decided: persisted in a new `MemoryDocument` `Topic Suggestions` section.
- [x] Decide how topic quality is controlled so stale/noisy topics do not spam recommendations. Decided: per-topic `lastMentionedAt`, `mentionCount`, optional `expiresAt`; Home uses stricter gates than topic taps.
- [x] Decide ranking/priority rules between upcoming-driven cards, recency cards, and topic-driven cards. Decided: Upcoming overlay first; regular cards remain Maintenance Need-primary with topic quality boost.
- [x] Preserve the anti-shame voice: no numeric day counts or guilt phrasing.
- [x] Write a PRD or issue set capturing the approved design. See `docs/prd/2026-06-04-topic-suggestions-prd.md` and #096–#099.

## Blocked by

#087 — Memory-aware recommendations from `MemoryDocument.upcoming`.
