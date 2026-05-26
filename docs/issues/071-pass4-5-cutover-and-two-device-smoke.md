# #071 Pass 4.5 production cutover + offline two-device smoke

Labels: issue, needs-triage

## Parent

docs/prd/2026-05-26-connection-persistence-pass-4-5-prd.md

## What to build

Pass 4.5's analog of Pass 4.2's #060. By the time this issue runs, #070 has already wired `AppController` through `FirebaseConnectionStore` / `FirebaseInteractionStore` / `FirebaseEventStore`. This issue is verification + smoke evidence on real devices.

Offline persistence was already enabled in Pass 4.2 #060 code half (`Settings(persistenceEnabled: true)`), so no new client config is needed.

Likely device-blocked. The agent-doable parts are documented in the AC; the device-bound parts have to be captured manually.

## Acceptance criteria

- [ ] Production cutover end-to-end verified on at least one of {macOS, iOS Simulator, Android Emulator, physical device}. Chrome web does NOT count.
- [ ] Two-device same-account smoke documented in `progress.md`. Pick at least two of {macOS, iOS Simulator, Android Emulator, physical device}, name them, and capture the trace:
  - Sign in as the same test account on both.
  - Add a connection on device A while online.
  - Observe the connection on device B within 10s.
  - Log an interaction on device B.
  - Observe the interaction on device A.
  - Schedule an event on device A.
  - Observe the event on device B.
  - Add a category "Mentor" on device A.
  - Observe the new category in the People filter on device B.
- [ ] Offline write trace: take device B offline, make a connection edit on device B, reconnect, observe replication to device A within 10s.
- [ ] Snapshot-listener resilience trace: leave device A on the People tab; on device B, delete a connection. Device A's list updates without manual refresh within 10s.
- [ ] Smoke validates live rules against `connect-me-e20b1`.
- [ ] Rules-denial evidence: a second signed-in test user cannot read user A's connections / interactions / events collections (Firebase console rules-playground screenshot or an explicit emulator-style denial test sufficient).
- [ ] iOS coverage required either here or via #053 (Pass 4.1 real-device gate, which is also still pending).
- [ ] No regression of Pass 4.2's memory-document behavior (memories still load, AI Update still commits memory then state).
- [ ] `progress.md` updated with the smoke trace and the deferred → done transition.

## Blocked by

- #070
