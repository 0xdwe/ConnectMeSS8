# #078 LLM prompt schema, prompt builder, and prompt REPL

Labels: issue, needs-triage

**Status: partially shipped on `main` (commit `f91e133`, 2026-05-29).** Pure-Dart slice landed ahead of #077. Three sub-AC items deferred to #080 because they require the Firebase AI Logic SDK to be useful (see "Deferred" section).

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md

## What to build

Define the Pass 4.3 prompt surface: the system instructions, the user-message builder, the schema-constrained response shape, and a small CLI prompt REPL under `tool/`. This issue does not yet call Gemini from inside the app — it produces the artifacts the `LlmAiUpdate` adapter will consume in #080, and gives developers a way to iterate on the prompt without booting the full app.

The prompt encodes ConnectMe's voice rules from CONTEXT.md (warm, brief, observational, no numeric day counts, no invented details), the schema rubric for `bondScoreDelta` (0..5 with calibrated examples), and the empty-input fallback contract.

## Acceptance criteria

- [x] System prompt lives as a versioned `const String` (e.g. `kLlmAiUpdatePromptV1`) in a dedicated file under `lib/src/ai/`. — `lib/src/ai/llm_ai_update_prompt.dart`.
- [x] Prompt explicitly forbids numeric day counts and shame-coded copy, and forbids inventing details when neither text input nor image attachments support them.
- [x] Prompt encodes the `bondScoreDelta` rubric (0 trivial, 1–2 normal, 3–4 meaningful, 5 major life moment).
- [x] Prompt encodes empty-input fallback behavior (null summary, empty deltas, generic bullet, delta=0).
- [ ] `promptVersion` field is added to `AiUpdateResult` (or a metadata sub-object) so persisted interactions trace back to the prompt that produced them. — **Deferred to #080.** The hook exists on `LlmAiUpdateResponse` (optional `promptVersion`/`modelName` fields); the projection onto `AiUpdateResult` lands with `LlmAiUpdate.run` so we don't need to touch `MockAiUpdate.run` and `applyAiUpdateResult` for a value `MockAiUpdate` can't produce.
- [ ] Response schema (the JSON Schema passed via Gemini's `responseSchema`) is defined and unit-tested for required fields, enum values matching `InteractionType`, numeric bounds for `bondScoreDelta`, and ISO date format for the history bullet. — **Dart-side mirror shipped at `lib/src/ai/llm_ai_update_response.dart`** with strict `fromJson` validation (60+ test cases). The Gemini-facing JSON Schema instance is **deferred to #080** alongside the SDK call.
- [x] User-message builder takes Connection metadata, Bond Score + tier description, current MemoryDocument markdown, up to 5 most-recent CrmInteractions (most recent first), today's date, user input, image attachment metadata, and non-image attachment names. Order and section labels match PRD §Q5. — `lib/src/ai/llm_ai_update_user_message.dart`. Bond tier thresholds aligned to `BondTier.from` in `lib/src/widgets/bond_ring.dart` (≥80 close, ≥50 steady, <50 drifting) per reviewer feedback.
- [x] Builder is a pure function with unit tests covering: full input, empty user input, no attachments, mixed image/non-image attachments, capped 5 recent interactions.
- [ ] CLI prompt REPL at `tool/prompt_repl.dart` reads a small fixture (or stdin input) and prints the constructed user message + system prompt. It does NOT yet call Gemini in this issue (Gemini wiring lands in #080). — **Deferred to #080 (or a small standalone follow-up).** Ergonomics, not contract.
- [x] Tests live under `test/state/ai/` (worker chose `llm_ai_update_*_test.dart` naming over the spec's `prompt_builder_test.dart` / `response_schema_test.dart` for symmetry with the `lib/` filenames; reviewer endorsed).
- [x] No production behavior change; `MockAiUpdate` continues to power `aiUpdateProvider`.
- [x] `flutter test test/state/` baseline grows by the new prompt-builder/schema tests; no regressions. — **232+2 → 292+2 (60 new tests).**
- [x] `flutter analyze` clean for new files.

## Deferred (lands in #080)

1. `promptVersion` field on `AiUpdateResult` — value is meaningless until `LlmAiUpdate.run` produces it.
2. Concrete Gemini `responseSchema` JSON Schema instance — co-locate with the SDK call site.
3. `tool/prompt_repl.dart` CLI — ergonomics, not contract.

## Blocked by

#077 (originally). Pure-Dart artifacts shipped without that block via the deferral above.
