# 096 — Extend `MemoryDocument` with Topic Suggestions

## Parent

Topic Suggestions PRD: `docs/prd/2026-06-04-topic-suggestions-prd.md`

## What to build

Extend the `MemoryDocument` model/parser/renderer with a new `Topic Suggestions` markdown section. Keep `topics` as simple tags, and add a separate structure for prepared action ideas grouped by topic.

## Acceptance criteria

- [x] `MemoryDocument` exposes Topic Suggestions grouped by topic without changing the existing `topics: List<String>` contract.
- [x] Each topic group stores `lastMentionedAt`, `mentionCount`, optional `expiresAt`, and up to three suggestions.
- [x] Each suggestion stores `kind` (`ask`, `share`, `plan`, `remember`) and `text`.
- [x] `MemoryDocument.render()` emits a deterministic `## Topic Suggestions` section after `## Topics` and before `## Upcoming`.
- [x] `MemoryDocument.parse()` remains total: malformed metadata or suggestion lines are ignored, not thrown.
- [x] Existing memories without the section parse as having no prepared Topic Suggestions.
- [x] Existing 64KB cap behavior still trims oldest history first; Topic Suggestions do not bypass the cap.
- [x] Unit tests cover round-trip render/parse, missing section, malformed section, cap behavior, and deterministic ordering.

## Blocked by

#088 — Topic suggestions design grill.
