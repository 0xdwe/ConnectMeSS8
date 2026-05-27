# Architecture Decision Records

Cross-cutting decisions that should not be re-litigated by future architecture reviews. PRDs (`docs/prd/`) capture per-pass design narratives; ADRs capture decisions that span passes and need a stable home so future skills (especially `improve-codebase-architecture` and `grill-with-docs`) don't re-suggest things we've already settled.

## Format

Each ADR is a single markdown file named `NNNN-kebab-title.md` where `NNNN` is a zero-padded sequence number. Use this skeleton:

```markdown
# ADR-NNNN: Short imperative title

Date: YYYY-MM-DD
Status: accepted | superseded by ADR-MMMM | deprecated

## Context

What pressure forced this decision. The state of the codebase at the time. Other options that were considered.

## Decision

The chosen path, stated as one sentence followed by detail.

## Consequences

What this enables. What this constrains. Cost paid.

## When to revisit

Concrete trigger conditions that would warrant reopening this decision.
```

Status transitions:
- `accepted` — current decision.
- `superseded by ADR-MMMM` — replaced; keep the old ADR around as history. The new ADR's "Context" cites the old one.
- `deprecated` — no longer relevant (the underlying constraint went away). Keep around as history.

## Index

| # | Title | Status |
|---|---|---|
| 0001 | [Use markdown ADRs in this directory](./0001-use-markdown-adrs.md) | accepted |
| 0002 | [Reject `fake_cloud_firestore`; use InMemory + emulator](./0002-no-fake-cloud-firestore.md) | accepted |
| 0003 | [Single-device prototype scope; cross-device evidence deferred](./0003-single-device-prototype-scope.md) | accepted |
| 0004 | [Firestore is the source of truth (post-Pass 4.5)](./0004-firestore-is-source-of-truth.md) | accepted |
| 0005 | [`AppController` stays as the write coordinator](./0005-app-controller-as-write-coordinator.md) | accepted |
| 0006 | [Defer the `FirestoreSnapshotMirror` extraction](./0006-defer-firestore-snapshot-mirror.md) | accepted |
