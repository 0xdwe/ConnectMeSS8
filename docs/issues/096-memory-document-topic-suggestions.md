# 096 — Extend `MemoryDocument` with Topic Suggestions

## Parent

Topic Suggestions PRD: `docs/prd/2026-06-04-topic-suggestions-prd.md`

## What to build

Extend the `MemoryDocument` model/parser/renderer with a new `Topic Suggestions` markdown section. Keep `topics` as simple tags, and add a separate structure for prepared action ideas grouped by topic.

## Acceptance criteria

- [ ] `MemoryDocument` exposes Topic Suggestions grouped by topic without changing the existing `topics: List<String>` contract.
- [ ] Each topic group stores `lastMentionedAt`, `mentionCount`, optional `expiresAt`, and up to three suggestions.
- [ ] Each suggestion stores `kind` (`ask`, `share`, `plan`, `remember`) and `text`.
- [ ] `MemoryDocument.render()` emits a deterministic `## Topic Suggestions` section after `## Topics` and before `## Upcoming`.
- [ ] `MemoryDocument.parse()` remains total: malformed metadata or suggestion lines are ignored, not thrown.
- [ ] Existing memories without the section parse as having no prepared Topic Suggestions.
- [ ] Existing 64KB cap behavior still trims oldest history first; Topic Suggestions do not bypass the cap.
- [ ] Unit tests cover round-trip render/parse, missing section, malformed section, cap behavior, and deterministic ordering.

## Blocked by

#088 — Topic suggestions design grill.
