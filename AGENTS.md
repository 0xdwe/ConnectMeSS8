# Agents Onboarding

If you are an AI coding agent landing on this repo: read this file first. It tells you what ConnectMe is, what's been built, what conventions to follow, and where to look next.

This file is the canonical onboarding document. Other docs (CONTEXT.md, progress.md, ADRs, PRDs) are referenced from here.

---

## What ConnectMe is

A Flutter personal-CRM app for relationship maintenance. Users add Connections (people they want to maintain ties with), log CrmInteractions, schedule PlannerEvents, and get AI-driven Recommendations. Per-contact MemoryDocuments persist as markdown narratives that grow on each "Update with AI" run. Backed by Firebase (Auth + Firestore).

Single-device prototype scope as of 2026-05-26 — see ADR-0003.

---

## Read these in order on a fresh chat

1. **`README.md`** — repo layout and where things live.
2. **`CONTEXT.md`** — domain glossary (Connection, CrmInteraction, MemoryDocument, AI Update, Bond Score, Recommendation), named seams (MemoryStore, ConnectionStore, BatchedWrites, etc.), source-of-truth contracts. Use these terms exactly when writing code, PRDs, issues, or commits.
3. **`progress.md`** — active worklog. The "Current status" block at the top tells you what's shipped, in flight, and deferred. The "Notes for the next session" block at the bottom names known traps.
4. **`docs/adr/`** — cross-pass decisions you should not re-litigate. Read the ADR README's index; pull individual ADRs as relevant.
5. **`docs/prd/`** — per-pass design narratives. Pull when working on the corresponding pass.
6. **`docs/issues/`** — atomic issue specs. Each numbered issue has a parent PRD and acceptance criteria.

---

## What's been shipped

Quick scan; full detail in `progress.md`.

- **Pass 1** (UI consistency) — shipped
- **Pass 2** (contact profile redesign) — shipped
- **Pass 3** (per-contact memory + AI Update) — shipped (#040–#050)
- **Pass 4.1** (Firebase Auth) — shipped (#052)
- **Pass 4.2** (FirebaseMemoryStore) — code shipped, device evidence deferred per ADR-0003
- **Pass 4.5** (connection / interaction / event persistence) — shipped 2026-05-26 (#063–#070, #072). Firestore is now the source of truth per ADR-0004; sign-out hotfix removed; orphan-memory bug fixed via multi-store atomic batches.
- **Pass 4.3** (real LLM `AiUpdate` via Firebase AI Logic / Gemini) — shipped. `LlmAiUpdate` adapter, prompt v1–v4, schema-constrained structured output, image attachments, bond score delta, Bond Drift + Maintenance Need chain (#076–#095).
- **Auth-backed User Profile** — shipped 2026-06-05 (#100–#104). Profile reads Firebase Auth identity; signup requires name; avatar uploads/removes via Firebase Storage.
- **Memory Topic Backfill & Scoped Panels** — shipped 2026-06-13 (#105–#108). Topic tap shows only that topic's AI-prepared suggestions; `MemoryTopicEnricher` (Gemini-backed) enriches per-contact; silent background backfill runner on launch; 2-suggestion cap end-to-end.
- **Personalized AI Insights** — shipped 2026-06-13. Local history/notes scanner extracts keyword-matched context; AI prompts generate detail-rich, non-templated suggestions; `Context:` section hidden when no match found; conversation starters capped at 2 throughout the full pipeline.

Test baseline: `flutter test test/state/` passing (0 skipped after #074/#075). JS rules tests 223 passed. Default `flutter test` sweep 273 passed / 33 failed (the 33 are widget-test fixture drift from unrelated UI merges, tracked separately). Targeted topic/widget tests: 57 passing.

---

## What's queued

The genuine product moves:

- **Pass 4.4** — Cloud Functions on Firestore writes; FCM push notifications. `feat/notifications` branch has functional implementation; production deployment and end-to-end push evidence pending review and merge.

Polish / debt:

- **#053 / #060 device half / #071 / #073** — cross-device evidence chain. Deferred per ADR-0003; revisit when triggers fire.
- **The 33 widget test failures** on `main` from `ui-login-page` + `fix-navbar` UI merges. Out of Pass 4 scope.
- **AppUser cleanup** — `AppUser` in `social_models.dart` duplicates `currentUserProvider`. Three callers. File as Pass 4.6 follow-up.
- **#089** — tappable history entries grill. Independent; no blocker.

---

## Conventions to follow

### Workflow

- **Branch all real work.** Never commit directly to `main` unless the user asks. Branch naming: `feat/<issue-number>-<kebab-title>`, `fix/<topic>`, `docs/<topic>`.
- **Work → review → fix loop.** Dispatch a worker subagent for implementation, a reviewer subagent to read the diff against the AC, then a fix worker to address findings. Then commit + merge with `--no-ff`.
- **Subagent transcripts** go in `.agent-runs/` (gitignored). Three files per issue typically: `<NN>-worker.md`, `<NN>-reviewer.md`, `<NN>-fix.md`.
- **Merge with `--no-ff` to `main`** once review fixes land. Don't squash; the merge commit names the issue and what shipped.
- **Push to `origin/main`** after every merge.
- **Update `progress.md`** at the close of each pass (closeout issues are typed `docs(passN.M): #NNN ...`).

### TDD

- TDD strictly when implementing features or fixing bugs. Write failing tests first; implement; see GREEN.
- Skill at `/Users/jamesli/.agents/skills/tdd/SKILL.md`.

### Tests

- **Don't run `flutter test` (the full sweep)** without explicit user permission. It's CPU-heavy and the user has flagged HITL preference for those runs.
- Targeted runs are fine: `flutter test test/state/`, `flutter test test/state/connections/`, `flutter test test/state/<file>.dart`.
- **Don't run `flutter test integration_test/`** until ADR-0003's revisit triggers fire — emulator runs are deferred.
- JS rules tests are CPU-light and fine to run: `cd firestore && firebase emulators:exec --only firestore,storage --project demo-test "npm test"`. Requires JDK 21+ on PATH (`brew install openjdk@21`).

### Code style

- Match `lib/src/state/memory/` patterns when adding a new store seam. The Pass 4.2 / Pass 4.5 stores all share a shape (interface + InMemory + Firebase + auth-aware provider with signed-out sentinel + idempotent dispose).
- **`fake_cloud_firestore` is forbidden** per ADR-0002. Use InMemory adapters for headless tests; emulator for integration tests.
- Use `set + merge: true` when writing to user-doc fields so seeder sentinels are not clobbered.
- Multi-store writes go through `BatchedWrites` for Firestore atomicity.
- UI mutating actions are now async (Pass 4.5 #070); UI call sites must `await` and surface a snackbar on throw. The pattern is at `planner_tab.dart:120-126`.
- **Anti-shame guardrail**: no numeric day counts in user-visible copy. "Mike could use a check-in" is fine; "you haven't talked to Mike in 47 days" is rejected.

### Firebase project

- Production project ID: `connect-me-e20b1`.
- Emulator-only project namespace: `connect-me-rules-test` (NOT a typo).
- Rules CI auto-deploys on `main` push when `firestore/firestore.rules` changes (workflow at `.github/workflows/rules-deploy.yml`).

### Documentation discipline

- **CONTEXT.md** is the canonical domain glossary. Update it lazily when a term sharpens during grilling or a new module earns a domain name.
- **ADRs** capture cross-pass decisions. Format at `docs/adr/README.md`. Add when a decision spans passes and you don't want it re-litigated. Do NOT add for ephemeral decisions ("we'll do X later when convenient" is not an ADR; "we reject Y, here are the revisit triggers" is).
- **PRDs** capture per-pass design narratives. Live in `docs/prd/<YYYY-MM-DD>-<topic>-prd.md`.
- **Issues** are atomic specs. Live in `docs/issues/<NNN>-<topic>.md`. Format: parent PRD reference, "What to build," "Acceptance criteria" checklist, "Blocked by."
- **`progress.md`** is the active worklog. Updated at pass closeouts.
- **Subagent transcripts** go in `.agent-runs/` (gitignored, ephemeral).

---

## What to do when you start a task

1. Read `progress.md`'s top block ("Current status") and bottom block ("Notes for the next session"). Two minutes; tells you what's true today.
2. If the task references a Pass or issue, pull the relevant PRD from `docs/prd/` and the issue file from `docs/issues/`.
3. Check `docs/adr/` for any decision that bears on the task. If you're about to suggest something that an ADR rejects, cite the ADR and explain why the trigger has now fired (or stop).
4. If you don't recognize a domain term, look it up in `CONTEXT.md`. If it's not there, the work probably needs that term added.
5. Branch. Implement. Test (targeted). Commit (don't push to main without dispatch through review).

---

## Known traps

These keep coming up; flag them up-front so you don't step in them.

- **`AppController` is a 27-method god module.** Cleanup is named in ADR-0005 as deferred. Don't suggest splitting it without checking ADR-0005's revisit triggers.
- **Snapshot-listener pattern in 3 Firebase stores has near-identical lifecycle code.** Consolidation is named in ADR-0006 as deferred. Don't suggest extracting `FirestoreSnapshotMirror` without checking ADR-0006's revisit triggers.
- **Cross-device evidence is deferred.** ADR-0003. Don't suggest blocking work on real-device verification.
- **`AppUser` is dead duplication of `currentUserProvider`** (PRD §Q13 of Pass 4.5). Cleanup is filed but deferred.
- **The first-frame seeded flash** on signed-in launch (#070 reviewer S5) is documented behavior. Don't reflexively fix it.
- **The 33 widget test failures** on `main` are NOT Pass 4 work; they're from `ui-login-page` + `fix-navbar` UI merges. Track separately.
- **`AiUpdate.run()` has `onClassifierPassed` optional named param** (Pass 4.4 / #112–#113). Every `implements AiUpdate` class MUST include this param in `run()`. Check `_SignedOutAiUpdate`, `_ThrowingAiUpdate`, `_NoDeltaAiUpdate`, and any inline test fakes when modifying the interface.
- **`MockAiUpdate` fakes cannot `implements` final SDK classes.** `GenerativeModel` and `GenerateContentResponse` are `final class` in `firebase_ai-3.12.1`. Tests must use the `GeminiGenerateContentFn` function-injection seam instead of trying to mock the SDK types directly.
- **`lastRecommendationList` is a module-level variable** in `memory_providers.dart` — it survives Provider disposal during GoRouter navigation. Tests reading it must reset it in `setUp`/`tearDown` to avoid cross-test contamination.
- **Seeded `lastContact` dates use `DateTime.now()` (wall clock).** When writing recommendation tests with a fake clock, the seeded dates may be too close to the fake time, causing all contacts to have `MaintenanceNeed.none`. Either use explicit connections with old dates or set the fake clock far in the future.

---

## When in doubt

- Ask the user. Don't paper over a constraint conflict.
- If two plausible paths exist, present both and let the user pick. Don't unilaterally choose.
- If a refactor improves testability or locality but has no forcing function, write an ADR and defer it (see ADR-0006 for the template).
