# 097 — `LlmAiUpdate` prepares Topic Suggestions

## Parent

Topic Suggestions PRD: `docs/prd/2026-06-04-topic-suggestions-prd.md`

## What to build

Update the LLM prompt/schema/adapter so AI Update prepares Topic Suggestions for newly-added topics and existing topics touched by the latest update. Suggestions are persisted through the updated `MemoryDocument` from #096.

## Acceptance criteria

- [x] LLM structured output includes topic-suggestion groups for new or touched topics.
- [x] The prompt asks for at most three suggestions per topic and constrains kinds to `ask`, `share`, `plan`, `remember`.
- [x] Suggestions are warm, specific, brief, and anti-shame compliant.
- [x] `LlmAiUpdate` merges suggestion groups into the current `MemoryDocument` without rewriting untouched groups.
- [x] `lastMentionedAt` updates for touched topics; `mentionCount` increments when the topic is touched again.
- [x] Optional `expiresAt` is set only when the suggestion is time-sensitive.
- [x] Malformed or out-of-range LLM suggestion fields are rejected or safely dropped according to the existing `AiUpdateFailure` pattern.
- [x] `MockAiUpdate` either leaves Topic Suggestions empty or uses deterministic fixtures only where tests require them; do not expand the throwaway keyword extractor.
- [x] Tests cover schema parsing, merge behavior, untouched preservation, metadata updates, anti-shame copy guardrails, and malformed response handling.

## Blocked by

#096 — Extend `MemoryDocument` with Topic Suggestions.
