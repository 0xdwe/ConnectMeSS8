# 088 — Grill topic-based recommendations and topic-tap suggestions

## Parent

Pass 4.3 LLM AI Update PRD: `docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md`

## What to build

Run a design grill for how Gemini-written `MemoryDocument.topics` should power user-facing recommendations and topic-tap suggestions. The current topic tap behavior falls back to static templates, so useful Gemini topics such as "Paris trip" or "currency" can still produce generic suggestions. This issue produces a PRD / follow-up implementation issues; it does not require product code.

## Acceptance criteria

- [ ] Decide whether topic suggestions are generated eagerly during AI Update, lazily on tap, or via a template + memory hybrid.
- [ ] Decide whether generated suggestions are persisted, cached, or ephemeral.
- [ ] Decide how topic quality is controlled so stale/noisy topics do not spam recommendations.
- [ ] Decide ranking/priority rules between upcoming-driven cards, recency cards, and topic-driven cards.
- [ ] Preserve the anti-shame voice: no numeric day counts or guilt phrasing.
- [ ] Write a PRD or issue set capturing the approved design.

## Blocked by

#087 — Memory-aware recommendations from `MemoryDocument.upcoming`.
