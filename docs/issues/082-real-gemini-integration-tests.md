# #082 Real Gemini integration tests for formatting and prompt rules

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md

## What to build

A small suite of real-Gemini integration tests that prove `LlmAiUpdate` produces output matching the Pass 4.3 schema and prompt rules end-to-end. These tests live under `integration_test/state/ai/`, are gated behind `--dart-define=RUN_GEMINI_TESTS=1`, and are excluded from default `flutter test` and CI sweeps. Writing the tests is AFK; running them GREEN is HITL because it requires real Firebase Auth + App Check on a target where they work (currently blocked on macOS desktop by `firebase_auth/keychain-error`, same gate as Pass 4.5 #073).

Per the user's direction during grilling, this issue exists specifically to verify that the live Gemini API conforms to the schema, voice rules, and bond-score calibration before Pass 4.3 closes.

## Acceptance criteria

- [ ] Integration test file at `integration_test/state/ai/llm_ai_update_gemini_test.dart`.
- [ ] Tests are skipped unless `--dart-define=RUN_GEMINI_TESTS=1` is set, so default sweeps and CI do not burn Gemini calls.
- [ ] Test cases assert structural invariants only (not exact LLM prose):
  - Schema compliance: every required field present, types right, enums in `InteractionType` range, `bondScoreDelta` in 0..5, ISO date format on `newHistoryBullet` (`- YYYY-MM-DD — ...`).
  - Anti-shame voice rule: regex check against every returned string field rejects numeric day-count phrases ("47 days", "haven't talked in", etc.).
  - `bondScoreDelta` calibration: empty input → delta == 0; "Sarah and I just got engaged" → delta ≥ 3; routine "had coffee" → delta ≤ 2.
  - Empty-input fallback: input == "" with no images → null summary, empty `topicsToAdd` / `preferencesToAdd` / `upcomingToAdd`, generic bullet, delta == 0.
  - Image vision: a known fixture image input (small JPEG checked in under `integration_test/fixtures/` or generated at test time) produces a valid result that references something visible in the image. Test asserts the bullet/note is non-trivially populated, not the exact phrasing.
- [ ] At minimum 4 cases: happy path with text-only, happy path with image, empty input, calibration sanity (one trivial + one major).
- [ ] Tests use the production `LlmAiUpdate` adapter against the real Firebase project (`connect-me-e20b1`), not a fake `FirebaseAI` handle.
- [ ] If a test case requires a content-policy refusal to be observed, it is OPTIONAL (these are hard to trigger reliably) and is documented as an expected-skipped case rather than a hard failure.
- [ ] Documentation snippet under `docs/operations/` (or appended to existing Firebase ops doc) covering: how to run the integration suite, how to register an App Check debug token for the test runner, expected cost per run.
- [ ] GREEN-confirmation deferred is acceptable: tests must compile clean and be structurally complete in this issue. A live GREEN run can be deferred behind the same target-selection gate as #073, and re-confirmed in a follow-up issue if needed.
- [ ] `flutter analyze` clean for new files.
- [ ] Default `flutter test test/state/` and `flutter test integration_test/` (without the dart-define flag) baseline unchanged.

## Blocked by

#081
