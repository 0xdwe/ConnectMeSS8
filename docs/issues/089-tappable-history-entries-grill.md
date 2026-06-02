# 089 — Grill tappable history entries

## Parent

Pass 4.3 LLM AI Update PRD: `docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md`

## What to build

Run a design grill for making memory/history entries tappable so the user can inspect the supporting interaction or detail behind a history bullet. Today `MemoryDocument.history` is markdown narrative while `CrmInteraction` is the atomic timeline event; the relationship between them is implicit. This issue decides whether, how, and where to link those concepts. It produces a PRD / follow-up implementation issues; it does not require product code.

## Acceptance criteria

- [ ] Decide whether history bullets should link to `CrmInteraction.id`, a derived detail view, or remain plain narrative.
- [ ] Decide whether the UI opens a modal, detail screen, or timeline section.
- [ ] Decide whether old history bullets need backfill or whether linking starts only for new AI Updates.
- [ ] Decide how manual interactions and AI-suggested interactions appear in the same history/detail model.
- [ ] Preserve domain distinction: `CrmInteraction` is the atomic timeline event; `MemoryDocument` is LLM-generated narrative.
- [ ] Write a PRD or issue set capturing the approved design.

## Blocked by

None - can start immediately.
