# #080 LlmAiUpdate adapter behind the AiUpdate seam

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md

## What to build

Implement `LlmAiUpdate`, the production adapter for the `AiUpdate` seam, using the Firebase AI Logic SDK handle from #077, the prompt artifacts from #078, and the attachment preparer from #079. This issue lands the adapter, its failure-path tests via injection knobs, and its `_SignedOutAiUpdate` sentinel — but does NOT yet hard-cut production. Production `aiUpdateProvider` still binds `MockAiUpdate` until #081 lands the modal loading/cancel UX.

The adapter satisfies the existing `AiUpdate` interface from Pass 3 §Q1: `run` is purely constructive (no I/O after the LLM call returns; no state mutation), `commit` keeps the Pass 3 §Q4 all-or-nothing contract unchanged. Cancellation is a new sibling exception, `AiUpdateCancelled`.

## Acceptance criteria

- [ ] `LlmAiUpdate` lives at `lib/src/ai/llm_ai_update.dart`, implementing `AiUpdate`.
- [ ] Constructor takes: `firebaseAi`, `memoryStore`, `appController`, `model` (default: current-gen Flash-Lite from #076), `timeout` (default 20s), `promptVersion`, optional injection knobs.
- [ ] `run` builds the user message via the #078 builder, prepares attachments via the #079 preparer, calls Gemini with `responseSchema` (schema-constrained structured output), parses the response into an `AiUpdateResult`, and returns it. No I/O on memory or app state.
- [ ] Single retry with backoff for transient errors: overload (503), timeout, malformed JSON despite schema, schema mismatch, network drop. After retry exhaustion, throws `AiUpdateFailure` with retry-friendly copy.
- [ ] No retry for permanent errors: App Check rejection, quota exceeded, content-policy refusal. Each surfaces as a distinct user-facing message; content-policy is actionable ("rephrase or remove an attachment").
- [ ] Cancellation path: `run` accepts cancellation (via `CancelableOperation` or token parameter — worker chooses), aborts the in-flight Gemini request, and throws `AiUpdateCancelled`. `AiUpdateCancelled` is a sibling exception of `AiUpdateFailure`.
- [ ] `bondScoreDelta` clamped client-side to 0..5 regardless of model output.
- [ ] `commit` reuses the Pass 3 §Q4 / #046 contract verbatim — memory write, then state apply, with rollback on state-apply failure.
- [ ] Test-injection knobs on `LlmAiUpdate` mirror the `MockAiUpdate` pattern: `failOnNetwork`, `failOnQuota`, `failOnContentPolicy`, `cancelMidRun`, plus the existing `failOnSave` / `failOnApply` for the commit path.
- [ ] Headless tests under `test/state/ai/llm_ai_update_test.dart` cover: every injection knob, schema clamp on `bondScoreDelta`, prompt-version metadata round-trip, retry-once behavior, no-retry-on-permanent behavior, cancellation behavior, `_SignedOutAiUpdate` sentinel throws on `run` and `commit`.
- [ ] Tests do NOT call real Gemini — they use injection knobs only. Live Gemini formatting tests are deferred to #082.
- [ ] `aiUpdateProvider` gains a signed-out sentinel `_SignedOutAiUpdate` that throws `AiUpdateFailure('Please sign in to use AI Update.')` from any call.
- [ ] Production `aiUpdateProvider` still binds `MockAiUpdate` for signed-in users at the end of this issue. The hard cutover lands in #081.
- [ ] In-memory `AiUpdateLogRing` provider holds the last 10 LLM calls (full content) for debug-only dogfooding. Cleared on app restart. Not persisted to Firestore.
- [ ] Debug-mode instrumentation logs prompt version, model, request/response token counts (when available), latency, retry count, and terminal exception class via `debugPrint`. No prompt or response content in production logs.
- [ ] `flutter analyze` clean for new files.
- [ ] `flutter test test/state/` baseline grows; no regressions.

## Blocked by

#078, #079
