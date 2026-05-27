# ADR-0006: Defer the `FirestoreSnapshotMirror` extraction

Date: 2026-05-27
Status: accepted

## Context

The architectural-deepening review on 2026-05-26 flagged candidate #1: extract a `FirestoreSnapshotMirror<T>` module from the four Firebase store adapters in `lib/src/state/connections/`. The four files (`firebase_connection_store.dart`, `firebase_interaction_store.dart`, `firebase_event_store.dart`, `firebase_user_doc_store.dart`) share a near-identical lifecycle structure: `StreamSubscription` against `.snapshots()`, broadcast `StreamController`, `_mirror: Map<String, T>?`, per-subscriber replay-on-listen wrapper, idempotent `dispose()`, listener-error forwarding without mirror corruption.

About 200 of 280 lines per file are this shared lifecycle code, copy-pasted three times (the user-doc store has a slightly different shape — single document instead of collection — and would not be part of the consolidation).

A grilling pass on candidate #1 walked the design tree:

- **Q1** — Scope. Decided: collections-only consolidation (3 stores). The user-doc store stays as-is.
- **Q2** — File path. Decided: `lib/src/state/connections/firestore_snapshot_mirror.dart`.
- **Q3** — Shape. Decided: composition. Each store HAS-A mirror as a private field; delegates `snapshot()` / `snapshotSync()` / `dispose()` to it.
- **Q4** — Interface. Decided: 3 public methods (`snapshot`, `snapshotSync`, `dispose`); CRUD stays on the per-store class; silent-drop on per-document decode failure.
- **Q5** — Test substrate. Decided in principle: ~12-15 new headless mirror tests, ~12-18 integration lifecycle tests trim from the emulator suite (moved to headless via fake `Stream<QuerySnapshot>`).

After Q5, the user paused on whether the refactor is essential and asked for an honest cost/benefit. The honest accounting:

**Real wins**:

- ~600 lines of lifecycle code consolidated.
- The PRD §Q6 listener-error positive test (currently deferred to #073 emulator GREEN) becomes testable headlessly against a fake stream.
- Adding a fifth collection in some future pass would cost ~80 lines instead of ~280.

**Honest costs**:

- 4-6 hours of work-review-fix loops on a refactor with zero user-visible behavior change.
- A regression in the mirror module would simultaneously affect all three stores — wider blast radius than the current per-store layout, where a regression is contained.
- Time displaced from work that moves the user-visible product forward: Pass 4.3 (real LLM), Pass 4.4 (Cloud Functions + FCM push), the deferred cross-device-evidence chain (ADR-0003), the 33 unrelated UI-merge widget test failures, and the two #070 follow-ups (#074, #075).

**No active forcing function**:

- No known bug in the lifecycle code; the reviewers across #065, #067, #068 signed off, the tests pass, the code works.
- No pending Pass 4.x that adds a new store family; the leverage win is hypothetical.
- The headless testability argument is the only concrete benefit, but PRD §Q6's listener-error contract is structurally verified by code review (#065 reviewer SUB-1 fix added a positive test in `firebase_connection_store_test.dart:360-409`); GREEN-confirmation is parked under #073 alongside other emulator evidence per ADR-0003.

## Decision

Defer the `FirestoreSnapshotMirror` extraction. The four Firebase store adapters keep their current shape until at least one of the revisit triggers below fires.

This decision says NOTHING about whether the refactor is good architecture in the abstract — it is. It says only that Pass 4.5 just shipped, the existing code works, and the leverage payback is too far away to justify the work now.

## Consequences

- **The duplication stays real.** Three of four Firebase store files retain ~200 lines of near-identical lifecycle code. A future bug in one would have to be fixed in three.
- **Future architecture reviews should not re-suggest this candidate** without checking the revisit triggers below.
- **The grilling notes (Q1–Q5 above) remain valid** if and when the refactor lands. The design tree is already walked; if a trigger fires, the refactor starts at "implement Q1–Q5" rather than "design from scratch."
- **No new code, no test changes, no commits beyond this ADR.**

## When to revisit

Any of the following should reopen this decision:

1. **A new store family lands or is planned.** If Pass 4.6 (orphan memory reconciliation, AppUser cleanup) or any future pass adds a fifth Firestore collection adapter, the consolidation pays back immediately. Implement Q1–Q5 as part of that pass.
2. **A real bug appears in the lifecycle code in one store but not the others.** That's the locality argument going from theoretical to concrete. The fix lands by extracting the mirror as part of the bug-fix work.
3. **The headless testability of the PRD §Q6 listener-error contract becomes load-bearing.** If #073's emulator GREEN evidence is delayed past a hard deadline (e.g. before a public release), or if a regression in listener-error handling slips past the current structural review, the headless mirror tests become essential.
4. **A contributor proposes the refactor in a PRD or grilling pass with a concrete forcing function.** Cite this ADR; document why the trigger fired.

When triggered, start from the Q1–Q5 design tree above, not from scratch.
