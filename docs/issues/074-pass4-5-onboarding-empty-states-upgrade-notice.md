# #074 Pass 4.5 onboarding modal + empty-state UX + persistence-upgraded notice

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

The UI half of the original #069 scope. #069 ships the `ConnectionSeeder` service + sentinels + rules + headless tests as a parameterized API. #074 builds the UI that drives the seeder choice + the empty-state experience for users who picked "Start fresh."

Three pieces:

1. **Onboarding prompt** on the auth screen's `_AuthMode.signup` flow — a modal or full-screen step shown AFTER `signUp()` succeeds and BEFORE the first navigation to the shell. Two-button choice: "Start with sample contacts" (Mike / Sarah / Emily / David / David / Jessica + their interactions and events) or "Start fresh" (empty connections / interactions / events; categories + eventTypes still seeded). Choice persisted to a Riverpod state and passed to `ConnectionSeeder.run(choice: ...)` from #069.
2. **Empty-state UX**: People tab when `connections` is empty AND seeder has completed shows a short copy + "Add your first contact" CTA. Home recommendations list shows a calmer placeholder when there are no recommendations.
3. **One-time "persistence upgraded" notice** when both: (a) `connectionsSeededAt` was just written this session, AND (b) the auth account already existed before this build (heuristic: Firebase Auth `creationTime` is older than this build's release date, OR a fallback flag like `data/persistence_v45_seen` to ensure the notice fires at most once per device per account).

## Acceptance criteria

- [ ] `seederChoiceProvider` (or equivalent) holds the user's "samples vs fresh" choice as a Riverpod state. Default `null` until the user has answered the prompt.
- [ ] Onboarding prompt fires only on `_AuthMode.signup` AFTER `signUp()` returns success; does NOT fire on `_AuthMode.login`.
- [ ] Two-button choice modal with `Sample contacts` / `Start fresh` buttons. Copy reviewed by user.
- [ ] User's choice persists into the Riverpod state; the seeder reads from there.
- [ ] Auto-trigger: a provider watches `currentUserProvider` + the seeder choice. When both are present and the seeder has not yet run, `ConnectionSeeder.run()` is invoked.
- [ ] Empty-state on People tab: shown when `connections` is empty AND `connectionsSeededAt != null` (loading shows nothing; signed-out shows nothing). Short copy + "Add your first contact" CTA that opens the existing add-connection flow.
- [ ] Empty-state on Home recommendations: shown when no recommendations are visible. Calmer placeholder copy.
- [ ] One-time "persistence upgraded" notice: heuristic on Firebase Auth `creationTime` < this build's release date AND `connectionsSeededAt` was just written this session. Notice copy reviewed by user. Marker stored in `SharedPreferences` (or equivalent) so the notice fires at most once per device per account.
- [ ] Widget tests for the onboarding prompt: signup flow shows the modal; chosen value writes to the provider; cancel-on-the-modal is OR is not allowed (decided in implementation).
- [ ] Widget tests for the empty-state widgets: copy rendered; CTA tappable; not shown when seeder has not run.
- [ ] Widget tests for the persistence-upgraded notice: fires once per (device, account); does not fire for fresh signups.
- [ ] `flutter analyze` clean. Default `flutter test` sweep stays at or above baseline.

## Why split out from #069

- The infrastructure half (#069) was reviewable in one sitting and had no product copy decisions.
- The UI half has three product-copy decisions and two UX placement decisions that benefit from explicit user review.
- Splitting keeps each merge focused and reviewable.

## Blocked by

- #069 (seeder service must exist before the UI can drive it)

## Notes

- The decision to split was made in chat after #068 landed. See chat history for the original #069 scope (which is preserved in the parent PRD).
- `data/persistence_v45_seen` lives outside the gitignored `/data/` directory by convention; this issue picks the actual storage mechanism (`shared_preferences` is the obvious candidate).
