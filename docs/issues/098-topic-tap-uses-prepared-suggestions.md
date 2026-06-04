# 098 — Topic taps use prepared Topic Suggestions

## Parent

Topic Suggestions PRD: `docs/prd/2026-06-04-topic-suggestions-prd.md`

## What to build

Update the contact-profile topic tap flow so it prefers prepared Topic Suggestions from `MemoryDocument` and falls back to deterministic template/hybrid suggestions when no prepared suggestions exist.

## Acceptance criteria

- [x] Tapping a topic with prepared non-expired Topic Suggestions shows those suggestions immediately; no LLM call runs on tap.
- [x] Tapping a topic without prepared suggestions falls back to existing deterministic suggestions.
- [x] Expired suggestions are hidden and fall back to deterministic suggestions.
- [x] Suggestion text remains anti-shame compliant and contains no numeric day-count nudges.
- [x] The UI preserves the current bottom-sheet/topic-pill interaction unless a small copy update is needed.
- [x] Existing topic-pill path is unchanged; new widget/state tests cover prepared, missing, and expired suggestion cases. Note: `test/features/conversation_topics_pills_test.dart` remains failing on Mock AI topic-pills fixture drift (`promotion` / `kindergarten` absent) and was assessed as unrelated to #098 because fallback logic is unchanged.

## Blocked by

#096 — Extend `MemoryDocument` with Topic Suggestions.
