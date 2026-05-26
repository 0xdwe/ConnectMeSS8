# ADR-0001: Use markdown ADRs in this directory

Date: 2026-05-26
Status: accepted

## Context

ConnectMe shipped its first three full passes (Pass 1 UI consistency, Pass 2 contact profile, Pass 3 per-contact memory) and most of Pass 4 without an ADR directory. Decisions lived inside PRDs, issue files, and review transcripts under `.agent-runs/`. By the time Pass 4.5 wrapped, several decisions were being re-litigated in architecture reviews because they were buried in pass-specific narratives:

- "Why don't we use `fake_cloud_firestore`?" — answer in Pass 4.2 PRD §Q9, but a reviewer would have to know to look there.
- "Why is `AppController` not split per concern?" — answer in Pass 4.5 PRD §Q14 and the post-#070 review, but neither is the authoritative place to put a cross-cutting decision.
- "Why is the codebase single-device-only when Pass 4.2 + Pass 4.5 wired cross-device sync?" — answer is scattered across `progress.md` deferral notes for #053 / #060 / #071 / #073.

The `improve-codebase-architecture` skill expects `docs/adr/` to exist so it can mark "candidate contradicts ADR-NNNN" and skip already-settled territory.

Other formats considered:

- **Plain comments in code**: don't survive the grep horizon for cross-cutting decisions.
- **`progress.md` notes**: progress.md is per-commit; ADRs are per-decision and outlive commits.
- **PRD §Q sections**: per-pass and would tangle when one pass's decision is overturned by another.
- **GitHub Discussions / issue comments**: not in the repo, lost on tool migration.

## Decision

Use Michael Nygard-style ADRs as markdown files in `docs/adr/`. Sequentially numbered, four-section format (Context / Decision / Consequences / When to revisit), tracked in the README's index. Status field flips to `superseded` (with a forward link) rather than being deleted; the history is the artifact.

## Consequences

- Architecture-review skills can reference ADRs by number and skip re-suggesting settled work.
- New decisions with cross-pass impact (cleavages, bans, scope cuts) get a written home.
- Cost: one more directory + a small ritual when a decision is recorded. The directory is lightweight (one file per decision, ~50-100 lines).

## When to revisit

Never, unless the team prefers a different format (e.g. moving to a hosted ADR tool). The format itself is unopinionated and survives tool changes.
