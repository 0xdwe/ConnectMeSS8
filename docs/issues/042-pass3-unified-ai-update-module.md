# Pass 3: unified AiUpdate module replaces AiUpdateService and absorbs the three AppController AI methods

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (the Q1 architectural pivot)

## What to build

The v1→v2 seam pivot. Replaces v1's parallel `AiUpdateService` +
`MemoryUpdater` plan with a single `AiUpdate` module shaped around
the user-level operation ("Update with AI on Sarah") rather than the
internal split between categorizing an interaction and writing a
memory file.

New `AiUpdate` interface with one public method:
`run({contact, userInput, currentMemory, attachments}) → AiUpdateResult`,
where the result carries `interactions`, `memoryDocument`, and
`summary` together. `MockAiUpdate` is the Pass 3 adapter: it does
what `MockAiUpdateService.categorizeAndUpdate` did (creates one
`CrmInteraction` from string-matched type) AND appends a one-line
date-stamped bullet to `MemoryDocument.history`. One Mock today, one
future `LlmAiUpdate` reserved for Pass 4, one prompt to keep coherent.

Per Q3, only the AI seam carves out of `AppController`. The three AI
methods (`previewAiUpdate`, `commitAiUpdate`, `runAiUpdate`) move into
the new module; `AppController` shrinks by exactly those three.
`aiUpdateServiceProvider` is removed and replaced by
`aiUpdateProvider`. `AppController.deleteConnection` gains one line
to cascade the delete to `MemoryStore.delete(id)`.

What this slice deliberately does NOT do:
- No keyword topic extractor — that's #043.
- No all-or-nothing engine-level enforcement — that's #046.
- No "About <Name> ✨" preview delta UI — that's #045.

The slice is "memory grows narrative on each AI update."

## Acceptance criteria

- [ ] `AiUpdate` interface with
      `run({contact, userInput, currentMemory, attachments}) → AiUpdateResult`.
- [ ] `AiUpdateResult` carries `interactions`, `memoryDocument`, and
      `summary`. The result is **not yet persisted** — `run` produces
      the candidate result; a separate commit step is what writes to
      `MemoryStore` and appends interactions to state. This shape is
      what makes Q5 cancel-discards-both possible without rolling
      back any persistence.
- [ ] `MockAiUpdate` adapter producing the same interaction-creation
      behavior as the old service plus appending a date-stamped bullet
      to `MemoryDocument.history`.
- [ ] Old `AiUpdateService` interface and `MockAiUpdateService`
      deleted.
- [ ] `aiUpdateServiceProvider` deleted; `aiUpdateProvider` added,
      returning `MockAiUpdate` in production.
- [ ] The three `AppController` AI methods (`previewAiUpdate`,
      `commitAiUpdate`, `runAiUpdate`) removed from `AppController`.
      Their behavior lives behind `AiUpdate` callable through the new
      provider.
- [ ] `AppController.deleteConnection` cascades the delete to
      `MemoryStore.delete(id)`.
- [ ] AI Update screen wires through `aiUpdateProvider` and continues
      to function (preview + commit flow). The visible delta section
      is deferred to #045.
- [ ] Tests updated: existing `test/features/ai_update_preview_test.dart`
      and any `app_state_test.dart` cascade tests adjusted to the new
      shape; `MockAiUpdate.run` behavior tested in isolation; a second
      update on the same contact appends to history without
      overwriting.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #040 (needs `MemoryDocument` and provider plumbing)
