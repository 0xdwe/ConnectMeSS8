# #081 AI Update modal loading + cancel UX, hard cutover to LlmAiUpdate

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md

## What to build

Wire the AI Update modal for the realities of a real LLM call — visible loading state, cancel affordance, and the Pass 4.3 failure-taxonomy snackbars — and flip production `aiUpdateProvider` to `LlmAiUpdate`. After this issue lands, signed-in users on a Pass 4.3 build hit Gemini for real when they tap Update with AI.

Cancellation triggers `AiUpdateCancelled` from #080, which closes the modal silently with no snackbar (cancellation is not an error). All other failure types from PRD §Q8 surface via the existing snackbar pattern, with copy tailored per error class.

## Acceptance criteria

- [ ] Production `aiUpdateProvider` binds `LlmAiUpdate` for signed-in users (hard cutover, no feature flag).
- [ ] Signed-out users continue to hit `_SignedOutAiUpdate` from #080.
- [ ] AI Update modal shows a loading state during `run()`: centered spinner, warm copy ("Reading what you've shared with [Sarah]…", contact name interpolated), Cancel button visible.
- [ ] Cancel during `run()` invokes the cancellation path, which aborts the in-flight Gemini call and throws `AiUpdateCancelled`. Modal closes silently — no snackbar, no error UI.
- [ ] Snackbar copy per PRD §Q8 failure taxonomy:
  - Transient (overload / timeout / network drop / malformed) after retry: "AI didn't respond in time. Try again?"
  - App Check rejection: "AI service unavailable. Please retry, or sign out and back in."
  - Quota exceeded: "AI service is temporarily over capacity. Please try again later."
  - Content policy: "That content couldn't be processed. Try rephrasing, or removing an attachment."
  - All attachments unreadable AND no useful text: "Attachments couldn't be read. Try again, or continue without them."
- [ ] `MockAiUpdate` keyword-list comments reviewed: any "let it die" wording in `progress.md` is corrected during closeout (#083), but the keyword list itself is preserved as a deterministic test fixture.
- [ ] Existing modal call sites continue to use the Pass 4.5 #070 await + try/catch + snackbar pattern.
- [ ] Widget test added (or existing test updated) verifying the loading state appears during a slow `run()`, and Cancel triggers the silent-close path. Uses `MockAiUpdate` with an injection knob to simulate slow `run()` — does NOT hit Gemini.
- [ ] Widget test added (or existing test updated) verifying each snackbar message fires for its corresponding `AiUpdateFailure` shape. Uses `MockAiUpdate` injection knobs.
- [ ] First-frame visual sanity check on the AI Update modal: spinner is centered, copy uses contact's first name, Cancel button is reachable and not visually hidden.
- [ ] `flutter analyze` clean for new files.
- [ ] `flutter test test/state/` and the targeted widget suite pass; no regressions.

## Blocked by

#080
