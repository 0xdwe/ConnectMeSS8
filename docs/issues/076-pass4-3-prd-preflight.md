# #076 Pass 4.3 PRD pre-flight

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md

## What to build

No-code pre-flight gate before Pass 4.3 implementation begins. Confirm prerequisites are in place: Firebase AI Logic is reachable in the project, the Gemini Developer API path is selected (not Vertex AI), the current-generation Gemini Flash-Lite model is the recommended default in the Firebase console at the time of work, App Check is configurable for the platforms we will exercise, and there is no in-flight branch touching the `AiUpdate` seam.

This is HITL because it depends on the user reading the live Firebase console and confirming model + project state. No code changes.

## Acceptance criteria

- [ ] Firebase AI Logic is enabled on the `connect-me-e20b1` Firebase project.
- [ ] Gemini Developer API backend is selected over Vertex AI.
- [ ] Current Firebase-recommended Flash-Lite model name is recorded in Pass 4.3 PRD §Q2 (expected: `gemini-3.1-flash-lite`).
- [ ] App Check is available for the platforms we will exercise (debug provider for development, Play Integrity / DeviceCheck for release mobile).
- [ ] Google Cloud project credit confirmed to cover prototype usage (≥ ~9,400 NTD remaining or equivalent free-tier headroom).
- [ ] Budget alert configured in Google Cloud (e.g. 1,000 NTD threshold) so cost spikes ping the user before the credit drains.
- [ ] No in-flight branch modifies `lib/src/ai/ai_update.dart`, `lib/src/features/ai_update_screen.dart`, `lib/src/features/modals/ai_update_modal.dart`, or `lib/src/state/firebase_providers.dart`.
- [ ] OpenAI / OpenRouter / user-supplied API key paths are explicitly out of scope for Pass 4.3 per PRD §Q1 and §Out of Scope.
- [ ] Pass 4.5 Firestore-backed Relationship Graph is on `main` and `flutter test test/state/` baseline (232 passed + 2 skipped) is intact so Pass 4.3 deltas can be measured.

## Blocked by

None — must run first.
