# #083 Pass 4.3 closeout

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md

## What to build

Documentation sweep that closes Pass 4.3. Update `progress.md` with the new "Current status" line, document the test baseline progression, correct the stale Mock keyword-list note, update CONTEXT.md if any new domain term sharpened during implementation, and file follow-up issues for known deferrals.

No code changes beyond doc edits. Land last.

## Acceptance criteria

- [ ] `progress.md` "Current status" updated: Pass 4.3 shipped, `LlmAiUpdate` is the production adapter, App Check is enabled, `MockAiUpdate` is now test-only.
- [ ] `progress.md` "Pass 4 sub-pass plan" updated: Pass 4.3 marked shipped; Pass 4.4 (Cloud Functions + FCM) is the next pass.
- [ ] `progress.md` "Test baseline progression" table gets new rows for #077–#082 with passing counts and any new skipped cases.
- [ ] `progress.md` "Notes for the next session" updated: the "Don't grow the keyword list further; let it die" note is corrected to "the keyword list survives in `MockAiUpdate` as a deterministic test fixture; production no longer uses it."
- [ ] `progress.md` "Open and pickable" gains the Pass 4.3 follow-ups (see below).
- [ ] CONTEXT.md updated with `LlmAiUpdate` and `AiUpdateCancelled` entries under "Key seams" / "Core domain terms" if not already added during implementation.
- [ ] Follow-up issue filed: **Firebase Storage-backed durable attachments** (cross-device image attachment durability, deferred per PRD §Q7).
- [ ] Follow-up issue filed: **Reset memory for this contact** (per-contact destructive action, deferred per PRD §Q9).
- [ ] Follow-up issue filed: **App Attest hardening** (production-grade attestation, deferred per PRD §Q3).
- [ ] Follow-up issue filed (optional): **OpenRouter / OpenAI fallback adapter** if dogfooding shows Gemini quality gaps; named in PRD §Q1 as a future hedge, not blocking.
- [ ] PRD `2026-05-27-llm-ai-update-pass-4-3-prd.md` re-tagged from `needs-triage` to `ready-for-issues` (or `shipped`).
- [ ] `flutter analyze` clean.
- [ ] `flutter test test/state/` baseline confirmed and recorded.
- [ ] `pubspec.lock` reviewed: any unintentional transitive dependency reverts (such as the current `material_color_utilities` 1.18→1.17 and `test_api` 1.31→1.30 drift) are either committed deliberately or reverted with a one-line note.

## Blocked by

#082
