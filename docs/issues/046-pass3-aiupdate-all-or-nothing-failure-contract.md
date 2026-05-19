# Pass 3: AiUpdate.run is all-or-nothing — neither memory nor interactions persist on failure

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q4 — failure contract)

## What to build

The Q4 contract enforced at the engine level. `AiUpdate.run` becomes
atomic: if any step fails (future LLM call, memory parse, memory
write, interaction append), nothing persists and the user sees an
error to retry. This *replaces* the v1 PRD's "memory failures don't
block interactions" rule.

In the Mock path, failures are essentially impossible by construction;
the contract is enforced via test injection and earns its keep when
Pass 4's real LLM lands. The atomic temp-file-then-rename in
`FileMemoryStore` (#041) is what makes the contract real on disk: if
the rename fails, `MemoryStore.save` throws, the engine catches it,
abandons the interaction commit, and surfaces the error.

Failure surface to the user is a snackbar or inline error on the AI
Update screen. Both `memoryProvider` and
`interactionsByContactProvider` return exactly their pre-run values.

## Acceptance criteria

- [ ] `AiUpdate.run` atomic semantics: on any internal failure,
      `MemoryStore.save` is not called OR is rolled back, and the
      interaction list is not appended.
- [ ] User-visible error path: a failed run surfaces an error
      (snackbar or inline) and leaves both memory and interactions
      exactly as they were before the run.
- [ ] `MockAiUpdate` test-injection mode (e.g., a test-only
      constructor flag or a wrapped failing collaborator) that forces
      a failure mid-run.
- [ ] Unit test: inject a failure via the test mode, assert
      `memoryProvider` returns the pre-run document and
      `interactionsByContactProvider` returns the pre-run list.
- [ ] Integration test: a forced failure during preview→commit on the
      AI Update screen leaves the contact profile unchanged.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #042 (needs the unified `AiUpdate` interface to enforce the
  contract on)
