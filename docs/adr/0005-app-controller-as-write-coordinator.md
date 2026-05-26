# ADR-0005: `AppController` stays as the write coordinator

Date: 2026-05-26
Status: accepted

## Context

Pass 4.5 PRD §Q14 grilling raised the question: a more idiomatic Riverpod approach would use `StreamProvider<List<Connection>>` directly off Firestore snapshots, with no `AppController` umbrella layer. Why keep AppController?

`AppController` is a 27-method `Notifier<AppState>` that coordinates auth, tab navigation, theme, user profile, connections, interactions, events, categories, event types, and AI updates. After Pass 4.5 #070, every mutating method writes through one of the Pass 4.5 stores. The reads, however, all flow through `AppController.state` — which is itself a denormalization of the four store snapshot mirrors per ADR-0004.

A pure-StreamProvider shape would mean: read paths go directly to per-collection providers (`connectionsProvider`, `interactionsProvider`, `eventsProvider`); write paths get scattered to per-feature notifiers or top-level mutating providers. AppController would either go away or shrink to just the "session" concerns (auth, tab, theme).

Three things kept AppController in place during Pass 4.5:

1. **Multi-store atomic writes need a place to live.** `deleteConnection`, `applyAiUpdateResult`, and `removeSampleConnections` mutate multiple stores in one batched Firestore write. A pure StreamProvider shape gives no place for the multi-store batched-write contract to live.
2. **Recommendation cache identity-pinning** (#062) reads `AppController.state.connections` for the recommendation engine input. Pass 4.6 may rewire this to read from snapshot mirrors directly, but Pass 4.5 explicitly kept the AppController-as-input shape.
3. **The unified AI Update flow** from Pass 3 §Q1 already depends on AppController being the write target. `AiUpdate.commit` writes to memory, then to AppController state — the all-or-nothing rollback contract.

Two future moves were also considered and deferred:

- **(deferred) Carve `AppController` along Pass 3 §Q3 lines.** Connections / Planner / AI / Session as separate notifiers. The architectural-deepening review on 2026-05-26 surfaced this as candidate #3. It earns its keep but Pass 4.5 #070 didn't go there. Open as a Pass 4.6 candidate.
- **(deferred) Move recommendation engine input from AppController to per-store snapshot mirrors.** PRD Q14 grilling acknowledged this as a clean future move once `AppController` carves; not done now.

## Decision

`AppController` stays as the write coordinator for Pass 4.5 and onward, until the carve in Pass 4.6 (or whenever it lands) makes per-feature notifiers the new default. The read paths can still be backed by snapshot listeners inside the stores; AppController's state is the denormalization. The layer earns its keep on the write side because of the multi-store atomic contract, the AI update flow's rollback contract, and the recommendation cache's input shape.

This decision says NOTHING about the future carve. It says only: "do not delete AppController as part of Pass 4.5."

## Consequences

- **The 27-method god-module shape is intentional debt** until the carve lands.
- **Tests register many overrides**: `test_overrides.dart`'s `signedInDemoOverrides` collects every store override needed for an AppController-driven test. The cost compounds as new stores are added.
- **Adding a new mutating method goes on AppController by default.** Resist the temptation to add a new top-level provider unless the operation is genuinely orthogonal (e.g. a settings flag with no domain interaction).
- **A future ADR will supersede this one** when the carve lands and AppController is split or shrunk.

## When to revisit

When any of these become true:

- The 27-method count grows past, say, 35. The maintenance cost of a single-file Notifier with that many methods is real.
- A new write-coordination concern comes in (Pass 4.4 push notifications, Pass 4.3 LLM concurrency) and forces the carve naturally.
- The recommendation cache rewires to read directly from snapshot mirrors (the deferred Pass 4.6 / #074 work). Then `connectionsProvider` becomes a real read path and the AppController-as-write-coordinator role weakens.
- A contributor proposes the carve in a PRD or grilling pass. The architectural-deepening review on 2026-05-26 already named it as candidate #3.

When triggered, the carve is shaped along Pass 3 §Q3 lines: `ConnectionsController`, `PlannerController`, `AiUpdateController`, `SessionController`. Reference the architectural-deepening review notes from that date.
