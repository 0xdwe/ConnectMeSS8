# connect_me

A Flutter app for relationship maintenance, designed for busy professionals and people with ADHD who need a memory aid for the people in their lives.

## Project documentation

Six files at the project root are the canonical living docs. Everything else is per-task or historical.

- `README.md` — this file
- `AGENTS.md` — onboarding for AI coding agents (read this first if you are one)
- `CONTEXT.md` — domain glossary, named seams, source-of-truth contracts
- `PRODUCT.md` — product principles and audience
- `DESIGN.md` — design system, tokens, typography
- `progress.md` — active worklog

## `docs/` layout

```
docs/
  adr/        # Architecture Decision Records (cross-pass decisions, numbered)
  prd/        # Product Requirement Documents, one per feature
  issues/     # Atomic issue specs (numbered, kebab-case)
  reviews/    # Subagent reviews, audits, and research output (dated)
  context/    # Per-task agent scratchpads (dated)
  operations/ # Ops runbooks (rules deploy, etc.)
  archive/    # Superseded snapshots and per-task closeouts (dated)
```

## Convention for agent-generated markdown

When a subagent produces a `.md` file mid-task (review, research brief, context handoff, completion report, implementation summary), it does **not** live at the project root. Use:

- `docs/reviews/<YYYY-MM-DD>-<topic>.md` — one-shot reviews, audits, research briefs
- `docs/context/<YYYY-MM-DD>-<topic>.md` — per-task context handoffs and scratchpads
- `docs/archive/<YYYY-MM-DD>-<topic>.md` — completion reports, implementation summaries, and stale snapshots kept for historical reference

Only the six canonical docs above belong at the project root. PRDs and issues live under `docs/prd/` and `docs/issues/`. ADRs live under `docs/adr/`.

## Getting started with Flutter

If this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Online documentation](https://docs.flutter.dev/)
