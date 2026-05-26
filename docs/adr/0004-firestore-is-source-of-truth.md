# ADR-0004: Firestore is the source of truth (post-Pass 4.5)

Date: 2026-05-26
Status: accepted

## Context

Before Pass 4.5, `AppController.state` was the source of truth for connections, interactions, events, categories, and event types. The data was seeded from constants on every app launch, mutated via in-memory `state.copyWith(...)` calls, and lost on app process death. Pass 4.2 had landed Firebase Auth + per-contact memory persistence, but the relationship graph itself stayed in RAM.

This produced a class of bugs:

- **The orphan memory bug**: a user adding "Prabowo," tapping Update with AI, force-quitting, then relaunching saw Prabowo gone but his memory document orphaned in Firestore.
- **Sign-out data loss**: signing out cleared connections; the hotfix on `main` (`4a4a7e5`) preserved them across sign-out within a single process but could not survive process death.
- **No cross-device sync** despite Pass 4.2 having paid for the auth-aware seam.

Pass 4.5 (#063 through #072, merged 2026-05-26 as `2889b59`) cut over: every mutating method on `AppController` now writes through one of four stores (`ConnectionStore`, `InteractionStore`, `EventStore`, `UserDocStore`), each backed by a Firestore snapshot listener. AppController state is now a denormalization of the four store snapshot mirrors. Sign-out tears down the listeners; the next sign-in opens fresh listeners that fill state from Firestore. Multi-store operations (`deleteConnection`, `applyAiUpdateResult`, `removeSampleConnections`) use Firestore `WriteBatch` for atomicity.

Two paths considered for "what owns the data":

- **A.** Keep AppController as the source of truth; persist defensively to Firestore on a debounce. (Pre-Pass-4.5 status quo, plus a reconciler.)
- **B.** Make Firestore the source of truth; AppController state is a thin denormalization of snapshot mirrors. (Pass 4.5 PRD §Q4 / §Q6.)

A would require: dirty tracking in AppController, a flush schedule, conflict resolution between the local copy and a remote write, manual cross-device sync logic. B uses Firestore's built-in replication + offline cache + listener model. PRD §Q4 chose B.

## Decision

Firestore owns the durable record of the relationship graph. `AppController.state.connections / interactions / events / categories / eventTypes` is a thin denormalization of the four store snapshot mirrors. Cross-instance writes flow in via snapshot listeners. The user-doc state (categories, eventTypes, seeder sentinels) is also denormalization.

Concretely:

- Mutating methods on AppController are async and write through their store(s) BEFORE updating local state. The local-state update is the cosmetic part; the durability is at the Firestore commit.
- Multi-store operations use `BatchedWrites` with `WriteBatch` for atomicity. On commit failure, AppController state is not advanced.
- Snapshot listener teardown on auth swap clears state automatically. The next sign-in opens fresh listeners.
- The `MemoryStore` family (Pass 4.2) is the one exception today: it uses a request/response shape (`.get()` / `.set()` / `.delete()`), no listener. PRD §Q6 of Pass 4.5 explicitly noted this asymmetry; future Pass 4.6 work could harmonize.

## Consequences

- **Orphan-memory bug fixed**: deleteConnection's batched write deletes the connection + interactions + events atomically; the memory cascade is post-batch best-effort (documented gap, PRD §Q9).
- **Cross-device sync wired** via snapshot listeners. Cross-device EVIDENCE is deferred per ADR-0003.
- **Sign-out hotfix removed**: the hotfix on `main` (`4a4a7e5`) is gone; signOut() is trivial.
- **Async UI**: every mutating UI action is now an async call. Modal call sites must `await` and surface a snackbar on throw (review C1 fix from #070).
- **First-frame race**: AppController's initial state seeds from `AppState.seeded()` constants for one frame before snapshot listeners overwrite. For a "Start fresh" user this is a one-frame flash of demo data; imperceptible in practice but a real visible artifact (review S5 from #070).
- **Test substrate**: AppController contract tests register every store override (connection / interaction / event / userDoc / memory / batched / auth). The `signedInDemoOverrides` helper at `test/test_overrides.dart` collects them.
- **The `MemoryStore` asymmetry** is a known gap. A future ADR may supersede this one if MemoryStore adopts the snapshot pattern.

## When to revisit

If any of these become true, this ADR should be reopened or superseded:

- A future store family wants a different ownership model (e.g. local-first with eventual sync). Then this ADR becomes scoped to the existing four families plus memory.
- The first-frame seeded flash becomes user-visible enough to justify changing the initial state to empty + a hold-the-splash gate.
- The orphan-memory window from the post-batch memory cascade actually produces user-visible orphans. The reconciler work (Pass 4.6 from PRD §Q9) would land then.
- MemoryStore adopts the snapshot pattern; this ADR is superseded by one that names "Firestore is the source of truth for ALL durable user data."
