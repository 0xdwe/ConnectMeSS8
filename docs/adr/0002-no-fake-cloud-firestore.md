# ADR-0002: Reject `fake_cloud_firestore`; use InMemory adapters + emulator

Date: 2026-05-26
Status: accepted

## Context

When Pass 4.2 introduced the `MemoryStore` seam and Pass 4.5 introduced the `ConnectionStore` / `InteractionStore` / `EventStore` / `UserDocStore` seams, every store needed two layers of test substrate:

1. **Headless tests** that exercise the store contract without booting Firebase. Run on every `flutter test test/state/`.
2. **Emulator-backed integration tests** that verify the real Firestore adapter against the rules layer. Run via `firebase emulators:exec --only firestore "flutter test integration_test/state/connections/"`.

Three options for the headless layer:

- **A.** `fake_cloud_firestore` — a community-maintained pub package that simulates Firestore in-memory.
- **B.** Hand-rolled `InMemory*Store` adapters that implement the same Dart store interface as the production adapter.
- **C.** Skip the headless layer entirely; rely only on emulator tests.

Pass 4.2 PRD §Q9 chose B. The reasoning that landed:

- `fake_cloud_firestore` simulates the Firestore SDK, NOT the rules layer. Headless tests using it would silently pass writes that production rules deny. False confidence.
- The store interfaces (`MemoryStore`, `ConnectionStore`, etc.) are simple. An InMemory adapter is ~90 lines per store family. The maintenance cost is low.
- InMemory adapters are headless (no I/O, fast in CI), match the production interface byte-for-byte, and surface contract regressions on the same code path the production adapter uses.
- The rules layer is verified separately by JS rules tests (`firestore/rules.test.js`) and Dart emulator integration tests. The headless tests focus on the store contract, not Firestore semantics.

Pass 4.5 PRD §Q9 reaffirmed the same choice for the four new stores.

## Decision

Reject `fake_cloud_firestore` as a project dependency. Every store family ships an in-tree `InMemory*Store` adapter that implements the same Dart interface as its production Firebase adapter. Emulator-backed integration tests cover the Firebase-specific behavior (snapshot listeners against real Firestore, rules denial, multi-store atomic batches against real `WriteBatch`).

Headless tests use the InMemory adapter via Riverpod overrides. The production code path uses the Firebase adapter via the auth-aware provider. Both share the interface; neither knows about the other.

## Consequences

- Headless tests are fast (~5 seconds for the entire `test/state/` suite) and run on every commit without emulator setup.
- Adding a fifth store (e.g. for some Pass 4.6 entity) costs one InMemory adapter plus the production Firebase adapter. The pattern is established.
- Rules-layer correctness is NOT covered by headless tests by design. The JS rules suite (`firestore/rules.test.js`, currently 184 cases) and the Dart emulator integration suite cover that.
- Cost paid: ~90 lines of InMemory adapter per store family. Cheap.
- One real consequence of rejecting the simulator: a contract drift between the InMemory adapter and the Firebase adapter is undetectable by headless tests alone. Currently caught by the AppController contract tests (which exercise both) plus the emulator suite.

## When to revisit

If a future store family has a Firestore-specific contract that's hard to model in an InMemory adapter (e.g. server timestamps with strict ordering, transactions with read-your-writes semantics under contention) AND the emulator suite becomes too slow to run on every PR. Until both are true, this decision stands.

Note: `fake_cloud_firestore` is also worth a re-evaluation if it ever ships rules-layer simulation. It does not today.
