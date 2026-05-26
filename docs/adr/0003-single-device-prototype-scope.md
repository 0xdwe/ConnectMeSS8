# ADR-0003: Single-device prototype scope; cross-device evidence deferred

Date: 2026-05-26
Status: accepted

## Context

ConnectMe's PRDs from Pass 4.1 onward describe a cross-device sync story: sign in on phone, see your data on laptop, write on phone, observe replication, etc. Pass 4.2 wired the Firebase Auth + per-contact memory side. Pass 4.5 wired the connection / interaction / event / categories / event-types side. The code path supports cross-device sync via Firestore snapshot listeners.

Multiple issues call for live cross-device evidence to GREEN-confirm the wiring:

- **#053** — Pass 4.1 real-device verification gate (sign-up / sign-out / sign-in / wrong-password against the real Firebase project).
- **#060 device half** — Pass 4.2 production cutover + offline two-device smoke + rules-denial evidence.
- **#061** — Pass 4.2 closeout (gated on #053 + #060 device half).
- **#071** — Pass 4.5 cutover + two-device smoke (the cross-device sync claim).
- **#073** — Pass 4.5 emulator integration-test verification (blocked by macOS-desktop `firebase_auth/keychain-error`; needs iOS Sim or signed macOS or Android Emulator).

Each of these requires either real devices (#053, #060 device half, #061, #071) or a non-default emulator target (#073). The user is solo on a single MacBook; the prototype audience is single-user. Spending wall-clock time on multi-device evidence before the product story warrants it is friction.

Two paths considered:

- **A.** Block each pass's closeout on the device evidence. Pass 4.2 #061 and Pass 4.5 #072 cannot land until #053 / #060 / #071 / #073 all run GREEN.
- **B.** Ship the code-track passes; defer device evidence to when it becomes load-bearing (e.g. before Pass 4.4's FCM push notifications, before any cross-device claim is made publicly, before onboarding a second user).

Pass 4.2 closeout chose B. Pass 4.5 closeout (commit `2889b59`) reaffirmed B for #071 and #073.

## Decision

ConnectMe is a single-device prototype until further notice. Cross-device evidence (real-device verification gates, two-device smokes, emulator integration test GREEN evidence) is deferred to a future pass that needs it. The code-track passes (Pass 4.2, Pass 4.5) ship without it. `progress.md` "Pass 4 — deferred" section tracks the parked issues so they're picked up at the right moment, not lost.

The deferral is NOT a rejection of cross-device sync as a feature. The wiring is in place; the evidence run is what's deferred. When evidence is needed, the parked issues get unstuck without any code-track regression.

## Consequences

- Headless tests + JS rules tests + structural review of integration test files are sufficient evidence for a code-track pass to ship.
- Test counts in `progress.md` cite headless and JS rules numbers; emulator GREEN counts are explicitly absent until a future pass runs them.
- The orphan-memory bug from PRD §Q9 cannot be reproduced single-device today (it requires a sign-out race or a permission-denied during the post-batch memory cascade); it lands as a Pass 4.6 reconciler when cross-device usage starts producing them in practice.
- Future architecture reviews should NOT suggest "block on real-device evidence" without first checking if cross-device usage is on the critical path.

## When to revisit

Any of:

- The user picks up the app on a second device for the first time.
- Pass 4.4 starts, since FCM push requires real-device evidence.
- A second user is onboarded.
- A claim is made publicly that ConnectMe syncs across devices.
- The prototype graduates from single-user.

When triggered, work the parked issues in order: #053 → #060 device half → #061 → #071 → #073. They form a chain.
