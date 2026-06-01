# Pass 4.3 — LlmAiUpdate with Firebase AI Logic (post-grilling)

Labels: prd, needs-triage

> Builds on: Pass 3 `AiUpdate` / `MemoryDocument` seam, Pass 4.1 Firebase Auth, Pass 4.2 `FirebaseMemoryStore`, and Pass 4.5 Firestore-backed Relationship Graph.
> Status: **post-grilling.** This PRD incorporates the Pass 4.3 design conversation: Firebase AI Logic, Gemini Developer API, current-generation Gemini Flash-Lite, schema-constrained structured output, image vision, App Check, and real Gemini integration tests.

## Problem Statement

ConnectMe's AI Update flow is architecturally ready for a real LLM, but today the only adapter is `MockAiUpdate`. The mock is deterministic and useful for tests, but product-wise it is not actually intelligent: it categorizes with a small keyword list, appends a short History bullet, and leaves `MemoryDocument.upcoming` empty.

This means the app already has a strong memory substrate but cannot use it fully. The `MemoryDocument` has sections for Summary, History, Preferences, Topics, and Upcoming. The `RecommendationEngine` already knows how to surface upcoming-driven cards such as trips and milestones. Pass 4.2 and Pass 4.5 made the underlying memory and Relationship Graph durable in Firestore. But the running app still cannot semantically extract relationship context from free-form text or images.

The user-visible failure is that "Update with AI" feels like a placeholder. If the user says Sarah's daughter is starting kindergarten, the app can only keyword-match "kindergarten." If the user attaches a photo from a celebration, the current mock cannot see it. If the user mentions a trip next month, the `Upcoming` section does not get populated, so the Home recommendations cannot react to it.

Pass 4.3 replaces that placeholder with a real LLM-backed adapter while preserving the Pass 3 `AiUpdate` contract: `run` is purely constructive, `commit` persists memory then state with rollback on failure, and callers do not need to know which adapter produced the result.

## Solution

Pass 4.3 introduces `LlmAiUpdate`, a production adapter for the existing `AiUpdate` seam. It uses Firebase AI Logic with the Gemini Developer API backend and a current-generation Gemini Flash-Lite model, defaulting to the model recommended by the Firebase console at implementation time (expected: `gemini-3.1-flash-lite`).

The app does not ask the user for an OpenAI, OpenRouter, or other third-party API key. Google Cloud / Firebase project billing covers inference, protected by App Check. The existing 9,400 NTD Blaze/free-trial credit is sufficient for prototype usage, especially with Flash-Lite and budget alerts.

The LLM call uses schema-constrained structured output rather than prose parsing. Gemini returns a validated shape that maps onto an `AiUpdateResult`: interaction type, title, note, MemoryDocument update deltas, next step, and a bounded bond-score delta. This avoids brittle regex or JSON-in-markdown parsing.

The prompt sends the relevant relationship context: Connection metadata, current Bond Score / tier, current MemoryDocument, up to five recent CrmInteractions, today's date, user input, and attachments. Image attachments are vision-enabled: the app reads local image bytes at AI Update time, downscales them before upload, and sends them to Gemini as image parts. Non-image attachments remain name-only.

The textual signal extracted from images is written into the MemoryDocument and CrmInteraction. The image file itself is not uploaded to Firebase Storage and does not become cross-device durable in this pass.

App Check is enabled before the first real AI Logic call ships. Development uses the App Check debug provider; release mobile builds use Play Integrity on Android and DeviceCheck on iOS. Production-grade attestation hardening is deferred because this is a final-project prototype, not a public launch.

## User Stories

1. As a ConnectMe user, I want Update with AI to understand what I typed, so that I do not have to manually summarize every relationship detail.
2. As a ConnectMe user, I want the app to update Sarah's memory when I mention her daughter's kindergarten milestone, so that I can remember to ask about it later.
3. As a ConnectMe user, I want the app to notice preferences like "Sarah prefers tea over coffee," so that future suggestions feel personal.
4. As a ConnectMe user, I want the app to recognize upcoming events like trips, appointments, birthdays, and school starts, so that Home recommendations can surface timely check-ins.
5. As a ConnectMe user, I want the AI to read attached images when I include them, so that visual context can become relationship memory.
6. As a ConnectMe user, I want image-derived facts to persist as text, so that I do not lose the insight even if the image file is local-only.
7. As a ConnectMe user, I want non-image attachments to still be acknowledged by name, so that the AI does not pretend to have read files it cannot inspect.
8. As a ConnectMe user, I want AI Update to feel warm and non-judgmental, so that the app helps me maintain relationships without shame.
9. As a ConnectMe user, I do not want the app to say things like "you haven't talked in 47 days," so that reminders do not feel accusatory.
10. As a ConnectMe user, I want the AI's suggested next step to be specific and gentle, so that I can act on it quickly.
11. As a ConnectMe user, I want to preview the AI result before committing it, so that I can reject a bad update.
12. As a ConnectMe user, I want cancellation during an AI call to leave memory and state untouched, so that changing my mind is safe.
13. As a ConnectMe user, I want a clear loading state while the AI is reading my update, so that a few seconds of latency does not feel broken.
14. As a ConnectMe user, I want retry-friendly errors when the AI service times out, so that transient network problems do not destroy my work.
15. As a ConnectMe user, I want content-policy failures to tell me to rephrase or remove an attachment, so that I know what action I can take.
16. As a ConnectMe user, I want empty input with no images to produce no invented details, so that the app never hallucinates relationship facts.
17. As a ConnectMe user, I want meaningful updates to move Bond Score more than trivial updates, so that relationship strength reflects real context.
18. As a developer, I want `LlmAiUpdate` to satisfy the existing `AiUpdate` interface, so that the UI and AppController do not need a new orchestration layer.
19. As a developer, I want `MockAiUpdate` to remain deterministic for tests, so that widget and state tests do not depend on live LLM calls.
20. As a developer, I want real Gemini integration tests for schema formatting, so that the output shape is proven against the actual API.
21. As a developer, I want the model name configurable in the adapter, so that we can move from Flash-Lite to Flash or Pro without reshaping the app.
22. As a developer, I want App Check enabled before AI Logic is used, so that the Firebase project credit is protected from abuse.
23. As a developer, I want prompt versioning, so that prompt regressions can be diagnosed later.
24. As a developer, I want no raw prompts persisted to Firestore, so that sensitive relationship context is not duplicated into a second durable artifact.
25. As a final-project maintainer, I want the implementation to avoid OpenAI / OpenRouter key UX, so that the demo does not require graders to bring their own API key.

## Implementation Decisions

### Q1 — LLM provider and call origin

Pass 4.3 uses Firebase AI Logic rather than a direct OpenAI key, OpenRouter key, or custom Cloud Function proxy.

Firebase AI Logic wins for this project because the app already uses Firebase Auth, Firestore, and a Blaze/free-trial Google Cloud project. It avoids user-supplied key UX, keeps provider auth inside Firebase, uses existing project billing, and avoids pulling Cloud Functions forward from Pass 4.4.

OpenAI and OpenRouter are out of scope for Pass 4.3. OpenRouter remains a future option if Gemini quality is insufficient, but the Pass 3 `AiUpdate` seam makes a later adapter swap cheap.

### Q2 — Gemini backend and model

The backend is the Gemini Developer API path exposed by Firebase AI Logic, not Vertex AI. Vertex AI's regional/IAM/audit features are unnecessary for a final-project prototype.

**Addendum 2026-05-31 — pivoted to Vertex AI.** First real call against `connect-me-e20b1` returned `"Your prepayment credits are depleted. Please go to AI Studio at https://ai.studio/projects to manage your project and billing."` The Gemini Developer API backend bills against AI Studio prepay (separate billing pool from the Cloud project's Blaze credit), and that pool was empty. Switched to `FirebaseAI.vertexAI()` (`us-central1`), which bills against the Google Cloud Blaze account where the prototype's 9,400 NTD credit lives. The SDK call surface above the line is identical: same `generativeModel(model: ...)`, same `generateContent`, same schema-constrained output. Vertex AI API was enabled in the Firebase console as part of the pivot. The model decision below is unchanged.

**Addendum 2026-05-31 — pivoted model to `gemini-2.5-flash-lite`.** First call against Vertex AI returned `Publisher Model ... was not found or your project does not have access to it` for `gemini-3.1-flash-lite`. Vertex AI lags the Developer API on new-generation Gemini publishes; 3.1 was not yet available on Vertex for project connect-me-e20b1. Pivoted to `gemini-2.5-flash-lite`, which is GA on Vertex, same Flash-Lite tier, same schema-constrained structured output and vision capabilities. The constructor is still configurable so dogfooding can swap up.

The default model is the current-generation Gemini Flash-Lite recommended by Firebase docs and the Firebase console at implementation time. During grilling the target was updated away from Gemini 2.0 Flash because 2.0 Flash and Flash-Lite shut down on June 1, 2026. Expected default: `gemini-3.1-flash-lite`.

The model name is configurable on the adapter. If dogfooding shows weak narrative quality, the app can move to Flash or Pro without changing the `AiUpdate` seam.

### Q3 — App Check posture

App Check is enabled and enforced for Firebase AI Logic from day one. Development uses the debug provider; release Android uses Play Integrity; release iOS uses DeviceCheck. App Attest and production-grade attestation hardening are deferred.

App Check initialization happens after Firebase initialization and before any Firebase AI Logic call. This mirrors the existing boundary-function pattern used for Firestore offline persistence.

### Q4 — Output strategy

`LlmAiUpdate` uses schema-constrained structured output. Gemini must return a validated object rather than free-form prose or JSON-in-markdown.

The response includes:

- interaction type, constrained to the existing CrmInteraction enum values.
- interaction title.
- interaction note.
- optional full replacement summary.
- exactly one new history bullet.
- topics to add.
- preferences to add.
- upcoming events to add.
- next-step suggestion.
- bond-score delta in the range 0..5.
- prompt/model metadata needed for debugging.

The app clamps numeric values client-side and rejects malformed responses with `AiUpdateFailure`.

### Q5 — Prompt context

Each LLM call sends:

- today's date.
- Connection name, category, current next step, Bond Score, and Bond Tier context.
- the full current MemoryDocument markdown.
- up to five recent CrmInteractions, most recent first.
- user input.
- attachment names.
- image attachment bytes for supported images.

The full MemoryDocument is capped at 64KB, so no special token-budget trimming is required in Pass 4.3.

### Q6 — Prompt voice and behavior

The system prompt establishes ConnectMe's voice: warm, brief, observational, and non-shaming. It explicitly rejects numeric day counts and any copy that blames the user for not maintaining contact.

The prompt tells Gemini not to invent facts. If it cannot extract a specific detail from text or images, it omits that detail.

Summary rewrites are gated to material changes only. Normal interactions append a History bullet and deltas but leave the Summary unchanged.

**Addendum 2026-06-01 — Bond Score curve.** The original rubric was `bondScoreDelta: integer 0..5` (0=trivial, 5=major life moment). Real dogfooding revealed the rubric was wrong-shaped: every committed update silently mapped to +3 in `applyAiUpdateResult` (the field was emitted, parsed, then discarded), and even after wiring it through, the 0..5 range failed the user's intuition that a deep day-long update at low bond (e.g. bond=20) should move the score by ~+50, while the same update at high bond (e.g. bond=90) should only move it by ~+5.

The redesigned rubric splits two concerns:
1. **LLM emits `interactionDepth: integer 0..100`** judging the input on its own merits. Anchors: 0=trivial, 25=brief with content, 50=substantive conversation, 75=significant news, 100=deep day-long bonding or major life moment.
2. **Code applies the diminishing-returns curve** in `LlmAiUpdate._projectOntoAiUpdateResult`: `delta = floor(depth × (100 − currentBond) / 160)`.

Reference cells: bond=20/depth=100 → +50; bond=90/depth=100 → +6; bond=100/anything → +0; depth=0/any → +0. No `+1` floor at non-zero depth (diminishing returns means small inputs at high bond can produce +0). Bond Tier crossings are silent on the profile; recommendations re-rank on the next read via the existing memory-change cache invalidation.

The delta is invisible in the AI Update preview — user sees the score move on the profile after commit. Surfacing the math in the preview was rejected in the 2026-06-01 grilling (PRD addendum question 4). See `docs/issues/085-apply-llm-bondscoredelta.md` for the full design and the implementation contract. `kLlmAiUpdatePromptVersion` bumps from 1 to 2 with this rubric change.

### Q7 — Image vision support

Pass 4.3 supports image vision for attachments at AI Update time.

The app reads image attachments from the local `AttachmentRef.path`, downscales them to a bounded size before upload, and sends them as image parts to Gemini. The recommended guard is max 1024x1024 and JPEG quality around 85.

Only supported image types are sent as image bytes. Non-image attachments remain name-only. The per-call image cap is four images. Additional images degrade to name-only. If one image cannot be read or resized, that image degrades to name-only and the update continues. If all intended images fail to read and there is no useful text input, the run fails with an actionable `AiUpdateFailure`.

The image itself is not persisted to Firestore or Firebase Storage in Pass 4.3. Only the textual relationship signal extracted from the image persists in the MemoryDocument and CrmInteraction.

### Q8 — Failure taxonomy

`AiUpdate.run` remains purely constructive. LLM failures do not write memory or mutate state.

`AiUpdate.commit` keeps the Pass 3 all-or-nothing contract: memory save first, then state apply, with rollback if the state apply fails after memory save succeeds.

A new cancellation exception is introduced as a sibling to `AiUpdateFailure`. User cancellation during the LLM call closes the modal silently and leaves memory/state untouched.

Transient Gemini failures get one retry with backoff and a 20-second per-call timeout. Transient failures include overload, timeout, network drop, malformed response, and schema mismatch.

Permanent failures do not retry: App Check rejection, quota exhaustion, and content-policy rejection. Content-policy failures get a user-actionable message: rephrase or remove an attachment.

### Q9 — Provider wiring

Production binds `aiUpdateProvider` to `LlmAiUpdate` unconditionally after Pass 4.3. There is no runtime feature flag and no settings toggle.

`MockAiUpdate` remains as a deterministic test adapter, with its keyword categorizer intact. The keyword list stops being production behavior but remains useful for fixtures.

A Firebase AI Logic provider exposes the SDK handle to Riverpod, similar to existing Firebase providers. A signed-out AI Update sentinel throws if the flow is reached outside an authenticated app shell.

### Q10 — User-facing UX

No new Settings UI ships in Pass 4.3. There is no API key field, no model picker, and no prompt diagnostics screen.

The AI Update modal gains a loading state while `run` awaits Gemini. The state uses a centered spinner, warm explanatory copy such as "Reading what you've shared with Sarah…", and a visible Cancel affordance.

Signed-out access is treated as a bug path protected by the sentinel and existing snackbar behavior.

### Q11 — Developer prompt tooling and observability

A small prompt REPL tool is allowed under the project's tooling surface so developers can run the live prompt against arbitrary inputs without exercising the full modal.

The adapter records prompt version, model, latency, retry count, token counts when available, and terminal exception class through debug logging. It does not persist raw prompts or raw responses to Firestore.

An in-memory debug ring buffer may keep the last few AI calls during a debug session, cleared on restart and excluded from release behavior.

### Q12 — Deferred OpenRouter / OpenAI path

OpenRouter and OpenAI direct calls are not part of Pass 4.3. They require key management, secure storage, settings UX, and a different billing story. Firebase AI Logic is the selected path for the project because it is simpler, covered by the existing Google Cloud credit, and aligns with the existing Firebase architecture.

## Testing Decisions

Good Pass 4.3 tests verify observable contracts: valid structured output, safe failure handling, no state mutation on failed runs, correct rollback on commit failures, image fallback behavior, prompt-rule compliance, and real Gemini formatting. Tests should not assert private helper structure or exact LLM prose when the model may legitimately choose different wording.

`MockAiUpdate` remains the test adapter for existing widget, AppController, and state tests. This preserves fast deterministic test runs and keeps most tests independent of network and Gemini availability.

`LlmAiUpdate` gets deterministic failure-path tests through adapter injection knobs: simulated network failure, quota failure, content-policy failure, timeout, malformed response, and cancellation. These tests assert the correct exception type and that memory/state remain untouched.

Happy-path formatting tests for `LlmAiUpdate` use the real Gemini API, not a fake Firebase AI SDK. They live under integration tests and are gated behind an explicit opt-in define so ordinary headless test sweeps do not burn Gemini calls or depend on network availability.

Real Gemini integration tests assert:

- schema compliance: required fields, enum values, string fields, arrays, nullability, and numeric bounds.
- `newHistoryBullet` format: `- YYYY-MM-DD — ...`.
- `bondScoreDelta` range and calibration for empty, routine, and major-life-event inputs.
- anti-shame copy: no numeric day-count language in any returned string field.
- empty-input behavior: no invented details, zero delta, null summary, empty deltas.
- image vision behavior: a controlled image input produces a structurally valid result that references visible image context without violating the prompt rules.

Integration GREEN-confirmation may be deferred behind the same device/emulator target decision currently blocking Pass 4.5 #073, but the tests themselves should be written as part of Pass 4.3.

App Check setup is manually verified against the Firebase console as part of the implementation sequence. CI should not run live Gemini tests by default.

Prior art:

- Pass 3 `AiUpdate` tests prove run/commit separation and rollback.
- Pass 4.2 Firebase provider tests establish auth-aware provider patterns.
- Pass 4.5 store tests establish signed-out sentinels and write-through contracts.
- Existing integration tests demonstrate the pattern for Firebase-backed behavior that is not part of the default `flutter test` sweep.

## Proposed Issue Sequence

1. **Pass 4.3 PRD pre-flight.** Confirm Firebase AI Logic console path, current model name, App Check availability for configured platforms, and no in-flight branch touching `AiUpdate`.
2. **App Check + Firebase AI Logic SDK scaffolding.** Add dependencies, initialize App Check, expose Firebase AI Logic through providers, and document console setup.
3. **Prompt schema + prompt builder.** Define prompt version, response schema, structured output model, user-message builder, and prompt REPL tool.
4. **Image attachment preparation.** Add image-type detection, downscale/compression, per-call cap, and soft-fail fallback behavior.
5. **`LlmAiUpdate` adapter.** Implement the production adapter with Gemini call, schema parsing, retry, timeout, cancellation, and debug instrumentation. Production `aiUpdateProvider` hard-cuts to it.
6. **AI Update modal loading/cancel UX.** Add the loading state, cancel path, and snackbar handling for the new failure taxonomy.
7. **Real Gemini integration tests.** Add opt-in integration tests that validate schema formatting, anti-shame rules, bond-score calibration, empty input, and image vision.
8. **Pass 4.3 closeout.** Update `progress.md`, correct the Mock keyword-list note, file follow-ups for Firebase Storage-backed attachments and memory reset UX if needed.

## Out of Scope

- OpenAI direct integration.
- OpenRouter integration.
- User-supplied API key UX.
- Cloud Functions LLM proxy.
- Pass 4.4 Cloud Functions + FCM push notifications.
- Firebase Storage-backed durable attachments.
- Cross-device attachment file availability.
- App Attest hardening and public-launch abuse operations.
- Prompt analytics persisted to Firestore.
- Firebase Analytics / Crashlytics telemetry.
- In-app prompt debugger or model picker.
- Per-contact AI opt-out.
- Manual MemoryDocument editor or reset-memory UX.
- Replacing `MockAiUpdate` in tests.

## Further Notes

Pass 4.3 is intentionally an adapter swap at the `AiUpdate` seam, not a rewrite of the AI Update flow. The hard-won Pass 3 contract remains load-bearing: `run` constructs, `commit` persists, and rollback is centralized.

The model name should not be hard-coded into design language as a permanent bet. The implementation should default to the current Firebase-recommended Flash-Lite model and keep model selection configurable at the adapter boundary.

The user's Google Cloud credit is sufficient for this pass. The main cost risk is abuse, not normal prototype use. App Check and a budget alert are the appropriate protection level.

Image vision is included because it is a key product feature for the final project. The boundary is clear: Pass 4.3 reads image bytes at update time and persists extracted textual meaning, but it does not make attachments themselves durable.

The "9router" / OpenRouter path was considered and rejected for this pass because it adds key management and provider-routing complexity without improving the immediate Firebase-first prototype path.
