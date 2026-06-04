# 097 — `LlmAiUpdate` prepares Topic Suggestions

## Parent

Topic Suggestions PRD: `docs/prd/2026-06-04-topic-suggestions-prd.md`

## What to build

Update the LLM prompt/schema/adapter so AI Update prepares Topic Suggestions for newly-added topics and existing topics touched by the latest update. Suggestions are persisted through the updated `MemoryDocument` from #096.

## Acceptance criteria

- [ ] LLM structured output includes topic-suggestion groups for new or touched topics.
- [ ] The prompt asks for at most three suggestions per topic and constrains kinds to `ask`, `share`, `plan`, `remember`.
- [ ] Suggestions are warm, specific, brief, and anti-shame compliant.
- [ ] `LlmAiUpdate` merges suggestion groups into the current `MemoryDocument` without rewriting untouched groups.
- [ ] `lastMentionedAt` updates for touched topics; `mentionCount` increments when the topic is touched again.
- [ ] Optional `expiresAt` is set only when the suggestion is time-sensitive.
- [ ] Malformed or out-of-range LLM suggestion fields are rejected or safely dropped according to the existing `AiUpdateFailure` pattern.
- [ ] `MockAiUpdate` either leaves Topic Suggestions empty or uses deterministic fixtures only where tests require them; do not expand the throwaway keyword extractor.
- [ ] Tests cover schema parsing, merge behavior, untouched preservation, metadata updates, anti-shame copy guardrails, and malformed response handling.

## Blocked by

#096 — Extend `MemoryDocument` with Topic Suggestions.
