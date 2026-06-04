# 099 — Topic-aware Home recommendations

## Parent

Topic Suggestions PRD: `docs/prd/2026-06-04-topic-suggestions-prd.md`

## What to build

Let high-quality Topic Suggestions make eligible Home recommendation cards more specific, without letting topics create urgency by themselves.

## Acceptance criteria

- [x] Upcoming-driven MemoryDocument overlay cards still rank first and de-dupe contacts.
- [x] Topic context can influence a regular card only when the contact has `MaintenanceNeed.low` or stronger, or when the topic is tied to non-expired Upcoming context.
- [x] Topic quality gating requires `mentionCount >= 2`, or `lastMentionedAt` within 30 days, or an Upcoming tie.
- [x] Expired Topic Suggestions never surface.
- [x] Regular-card ranking preserves Maintenance Need severity as primary, then applies topic quality boost, then cadence ratio, then contact-id tie-break.
- [x] Topic-aware cards can include topic-specific title/why/action copy, e.g. `Ask how the Paris plans are coming together.`
- [x] Tapping a topic-aware card opens the contact profile with the relevant topic highlighted or opens the topic suggestions sheet; no message drafting/sending ships here.
- [x] Recommendation copy remains anti-shame compliant and contains no numeric day-count nudges.
- [x] Tests cover ranking order, no-topic-urgency-alone, quality gates, expiry, Upcoming precedence, de-dupe behavior, and copy guardrails.

## Blocked by

#096 — Extend `MemoryDocument` with Topic Suggestions.
#098 — Topic taps use prepared Topic Suggestions.
