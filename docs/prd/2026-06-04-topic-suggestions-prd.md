# Topic Suggestions and Topic-Aware Recommendations PRD

Labels: prd, pass-4.3-follow-up

> Parent: #088 — Grill topic-based recommendations and topic-tap suggestions.
> Builds on: #087 memory-aware recommendations from `MemoryDocument.upcoming`, Pass 4.3 `LlmAiUpdate`, and the Relationship Maintenance policy shipped in #091–#094.

## Problem Statement

`MemoryDocument.topics` now holds useful Gemini-written tags such as “Paris trip” or “currency,” but the product still treats most topic taps as generic prompts. A user can preserve a specific memory topic and still see bland suggestions that do not reflect what the AI learned.

Home recommendations also have a specificity gap. Upcoming-driven cards can surface forward-looking events, and regular cards are ranked by Maintenance Need, but a high-quality topic currently cannot make an eligible recommendation feel more personal.

## Goals

- Make topic taps show prepared, contact-specific suggestions when AI Update has enough context.
- Let topic context improve Home recommendation copy without letting noisy topics create urgency by themselves.
- Preserve the existing split: `MemoryDocument.topics` are tags; `Topic Suggestions` are prepared action ideas; `Recommendation` is a Home card.
- Keep the app anti-shame: no guilt framing and no numeric day-count nudges.

## Non-goals

- No lazy LLM call when a topic is tapped.
- No message drafting, SMS/email integration, or “send” action.
- No one-time LLM backfill of old memories.
- No new Firestore sidecar collection for suggestions.

## Decisions

### Q1 — Scope

Build both topic-tap suggestions and topic-aware Home recommendation copy. Phase implementation so topic taps can ship before Home ranking changes.

### Q2 — Generation timing

`LlmAiUpdate` prepares Topic Suggestions during AI Update. Tapping a topic is instant and does not call Gemini. Deterministic template/hybrid suggestions remain as fallback when a memory has topics but no prepared suggestions.

### Q3 — Persistence location

Topic Suggestions live in the same `MemoryDocument` as a new markdown section, separate from `Topics`.

`Topics` remain short tags. `Topic Suggestions` store prepared action ideas grouped by topic, plus minimal metadata needed for freshness and ranking.

### Q4 — Suggestion shape

Each topic stores up to three suggestions. Each suggestion has:

- `kind`: `ask`, `share`, `plan`, or `remember`.
- `text`: one gentle action idea.

Suggested markdown shape:

```md
## Topic Suggestions

### Paris trip
lastMentionedAt: 2026-06-04
mentionCount: 2
expiresAt:
- ask: Ask how the Paris plans are coming together.
- share: Send a café or museum rec if you spot one.
- plan: Suggest a quick call before the trip.
```

The parser must stay total: malformed metadata or lines are ignored rather than throwing.

### Q5 — Refresh policy

On each AI Update, the LLM generates or refreshes Topic Suggestions for:

- newly-added topics, and
- existing topics clearly touched by the latest update.

Untouched topic suggestions remain unchanged until pruned or expired.

### Q6 — Quality controls

For each topic group, persist:

- `lastMentionedAt`
- `mentionCount`
- optional `expiresAt`

Topic taps are lenient: show prepared suggestions unless expired, falling back to deterministic suggestions when missing.

Home topic cards are stricter. A topic can influence Home if at least one is true:

- `mentionCount >= 2`
- `lastMentionedAt` is within 30 days
- the topic is tied to a non-expired `MemoryDocument.upcoming` entry

Expired suggestions never surface.

### Q7 — Home ranking

Upcoming-driven overlay cards remain first and de-dupe contacts.

Topic context enters the regular recommendation pool only when the contact is already eligible through Maintenance Need, or when the topic is explicitly tied to Upcoming context. Topic quality boosts specificity and ordering; it does not create relationship urgency on its own.

Regular ranking becomes:

1. Maintenance Need severity
2. topic quality boost when eligible
3. elapsed / adjusted-cadence ratio
4. deterministic contact-id tie-break

### Q8 — Home card behavior

A topic-aware card may include topic-specific title, why text, and a suggested action line.

Example:

- title: `Sarah has Paris on her mind`
- why: `A recent update mentioned Paris travel.`
- action: `Ask how the plans are coming together.`

Tapping the card opens the contact profile with the topic highlighted or opens the topic suggestions sheet. No drafting/sending action ships in this PRD.

### Q9 — Existing memories and backfill

No LLM backfill. Existing `MemoryDocument.topics` without a `Topic Suggestions` section use deterministic fallback suggestions. Reads do not write back to Firestore.

## Anti-shame copy guardrail

Allowed:

- `Ask how the Paris plans are coming together.`
- `Sarah mentioned Paris recently.`
- `Mike could use a warm check-in.`

Rejected:

- `You have not asked about Paris in 47 days.`
- `You are neglecting Sarah.`
- `Mike is drifting because you forgot to reach out.`

## Proposed issue sequence

1. #096 — Extend `MemoryDocument` with Topic Suggestions.
2. #097 — Have `LlmAiUpdate` prepare Topic Suggestions.
3. #098 — Use prepared Topic Suggestions on topic taps.
4. #099 — Add topic-aware Home recommendation copy and ranking boost.
