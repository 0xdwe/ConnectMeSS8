# #112 — AI Update Input Relevance Classifier

**Parent PRD:** Bot Guardrails / RAG-style Content Filtering (grilled 2026-06-14)

---

## What to build

A lightweight Gemini-backed pre-classifier that runs inside `LlmAiUpdate.run()` **before** the main
Gemini AI-Update call. If the classifier judges the user's input as irrelevant to relationship
maintenance for the named contact, `run()` throws `AiUpdateRejected` without spending a main-model
token.

### Behaviour contract

1. **Trigger**: classifier fires after attachment preparation passes but before
   `_generateAndParseWithRetry`. Only text input + attached-image existence are sent; memory
   document is NOT included (keep prompt small).
2. **Context sent to classifier**:
   - Contact name and category (e.g. "David Kim — Family")
   - User's raw text input
   - Whether images are attached (bool), not the image bytes
3. **Classifier prompt**: single focused system prompt asking "Is this input relationship-relevant
   for this contact? Reply JSON `{isRelevant: bool, reason: string}`. `reason` must be warm,
   specific, non-shaming — no day counts, no blame."
4. **Structured output**: schema-constrained JSON `{isRelevant: bool, reason: string}`.
5. **Pass path**: `isRelevant == true` → classifier returns, main call proceeds normally.
6. **Fail path**: `isRelevant == false` → throw `AiUpdateRejected(reason: llmReason)`.
7. **Classifier timeout**: 5 seconds. On timeout or any exception from the classifier call,
   **fail open** (treat as pass) so the main call still fires. A failed classifier must never
   block a legitimate update.
8. **Cancellation**: classifier respects the same `cancelToken` as the rest of `run()`. If
   cancelled during classification, throw `AiUpdateCancelled`.

### Loading UX

The `AiUpdateScreen` loading view currently shows one message ("Reading what you've shared with
firstName…"). With the classifier, the screen shows two stages:

- Phase 1 (classifier in-flight): **"Checking your input…"**
- Phase 2 (main call in-flight, after classifier passed): **"Reading what you've shared with
  firstName…"** (existing copy)

`LlmAiUpdate.run()` exposes an optional `onClassifierPassed` callback that the screen wires to
update a local state string for the label. No provider changes needed.

### New exception class

```dart
/// Thrown by [AiUpdate.run] when the classifier judges the user's
/// input as irrelevant to relationship maintenance for the contact.
/// Distinct from [AiUpdateFailure] so [AiUpdateScreen] can route
/// it to a dialog instead of a snackbar.
class AiUpdateRejected implements Exception {
  const AiUpdateRejected({required this.reason});
  final String reason;
}
```

### Mock injection knob

`MockAiUpdate` gains `failOnRelevanceCheck = false`. When `true`, `run()` throws
`AiUpdateRejected(reason: 'test-injected relevance rejection')` before any other work.

---

## Acceptance criteria

- [ ] `AiUpdateRejected` class exists in `lib/src/ai/ai_update.dart` alongside the existing
      exception classes.
- [ ] `LlmAiUpdate.run()` calls the classifier before the main Gemini call.
- [ ] Classifier uses schema-constrained structured output `{isRelevant: bool, reason: string}`.
- [ ] Classifier prompt includes contact name + category + user input + images-attached bool.
- [ ] Classifier timeout is 5 seconds; timeout causes fail-open (main call fires).
- [ ] Any classifier exception causes fail-open (main call fires). No classifier error surfaces to
      the user.
- [ ] `isRelevant == false` throws `AiUpdateRejected` with the LLM's `reason` string.
- [ ] `isRelevant == true` proceeds to the main Gemini call unchanged.
- [ ] Cancellation during the classifier call throws `AiUpdateCancelled`.
- [ ] `LlmAiUpdate` accepts optional `onClassifierPassed` callback (nullable `void Function()?`).
- [ ] `MockAiUpdate` gains `failOnRelevanceCheck` knob.
- [ ] Headless tests cover: pass path, fail path (rejection thrown), classifier-timeout fail-open,
      classifier-exception fail-open, cancellation.
- [ ] `flutter test test/state/ai/` green.
- [ ] `dart analyze` clean on touched files.

---

## Blocked by

Nothing. Can be implemented standalone.
