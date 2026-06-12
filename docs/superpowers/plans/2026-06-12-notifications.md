# Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship persisted notification controls, local PlannerEvent reminders,
FCM registration, and scheduled suggested check-in pushes.

**Architecture:** Extend `UserDocStore` for account-scoped preferences, keep
schedule generation pure, isolate platform plugins behind a gateway, and add a
Firebase scheduled function that mirrors Maintenance Need policy. Flutter
side effects are coordinated by Riverpod and remain outside `AppController`.

**Tech Stack:** Flutter 3.41, Riverpod 3, Firestore, Firebase Messaging,
flutter_local_notifications, timezone, Firebase Functions v2, Jest.

**Implementation status (2026-06-12):** Flutter code, platform configuration,
rules, and Cloud Function code are complete on `feat/notifications`. The
targeted Flutter suite, touched-file analyzer, Android build/install/launch,
JavaScript syntax checks, and pure Function helper assertions are green.
Firestore emulator and Functions Jest runs remain blocked by unavailable
network downloads, and production deployment is pending review and merge.

---

### Task 1: Persist Notification Preferences

**Files:**
- Create: `lib/src/state/notifications/notification_preferences.dart`
- Create: `lib/src/state/notifications/notification_preferences_controller.dart`
- Create: `test/state/notifications/notification_preferences_test.dart`
- Create: `test/state/notifications/notification_preferences_controller_test.dart`
- Modify: `lib/src/state/connections/user_doc_store.dart`
- Modify: `lib/src/state/connections/in_memory_user_doc_store.dart`
- Modify: `lib/src/state/connections/firebase_user_doc_store.dart`
- Modify: `lib/src/state/connections/user_doc_store_providers.dart`
- Modify: `test/state/app_state_test.dart`

- [ ] Write failing model codec tests for defaults, round-trip, malformed
  fallback, and partial-map fallback.
- [ ] Run `flutter test test/state/notifications/notification_preferences_test.dart`
  and confirm RED.
- [ ] Implement immutable preferences, `copyWith`, Firestore codec, and
  validation.
- [ ] Extend `UserDocSnapshot` and `UserDocStore` with
  `saveNotificationPreferences`.
- [ ] Add failing controller tests for snapshot hydration, durable updates,
  and write failure.
- [ ] Implement the auth-aware Riverpod controller and run both files GREEN.

### Task 2: Secure Preferences And FCM Registrations

**Files:**
- Modify: `firestore/firestore.rules`
- Modify: `firestore/rules.test.js`

- [ ] Add failing rules cases proving owner-only well-formed preference maps
  and notification token documents.
- [ ] Run the Firestore emulator Jest command and confirm the new cases fail.
- [ ] Add closed-shape validators for `notificationPreferences` and
  `notificationTokens/{tokenHash}`.
- [ ] Re-run the rules suite and confirm GREEN.

### Task 3: Build The Local Schedule Planner

**Files:**
- Create: `lib/src/state/notifications/notification_schedule.dart`
- Create: `lib/src/state/notifications/notification_schedule_planner.dart`
- Create: `test/state/notifications/notification_schedule_planner_test.dart`

- [ ] Write failing tests for timed events, all-day events, birthdays,
  disabled channels, past events, quiet-hour deferral, stale deferral,
  recurrence, stable IDs, ordering, and the 50-request cap.
- [ ] Run the planner test and confirm RED.
- [ ] Implement the pure planner with deterministic FNV-1a IDs.
- [ ] Run the planner test and confirm GREEN.

### Task 4: Add Platform Notification Gateway

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/Runner.entitlements`
- Create: `lib/src/state/notifications/notification_gateway.dart`
- Create: `lib/src/state/notifications/flutter_notification_gateway.dart`
- Create: `lib/src/state/notifications/notification_providers.dart`
- Create: `test/state/notifications/notification_gateway_test.dart`

- [ ] Add current compatible plugin dependencies.
- [ ] Define permission, scheduling, token registration, foreground display,
  and settings-opening interfaces.
- [ ] Write failing gateway-facing tests using an in-memory fake.
- [ ] Implement plugin initialization, IANA local time zone setup, inexact
  zoned schedules, Firebase Messaging token refresh, and foreground display.
- [ ] Add Android/iOS platform declarations and run the focused tests GREEN.

### Task 5: Coordinate Events, Preferences, And Tokens

**Files:**
- Create: `lib/src/state/notifications/notification_coordinator.dart`
- Create: `test/state/notifications/notification_coordinator_test.dart`
- Modify: `lib/src/app/connect_me_app.dart`
- Modify: `test/test_overrides.dart`

- [ ] Write failing tests for enabled sync, disabled cancellation, denied
  permission, token registration, token removal, event refresh, and auth
  swap.
- [ ] Implement a Riverpod coordinator that watches current user,
  preferences, and PlannerEvents without adding methods to `AppController`.
- [ ] Activate the coordinator from the application root.
- [ ] Add a no-platform fake to standard headless overrides and run GREEN.

### Task 6: Build Notifications Settings UI

**Files:**
- Create: `lib/src/features/modals/notifications_modal.dart`
- Create: `test/features/notifications_modal_test.dart`
- Modify: `lib/src/features/tabs/settings_tab.dart`
- Modify: `test/features/settings_modal_theme_consistency_test.dart`

- [ ] Write failing widget tests for all switches, disabled child controls,
  reminder lead selection, quiet-hour selection, permission warning, request
  permission flow, and persistence errors.
- [ ] Implement the grouped modal using existing theme tokens and responsive
  scrolling.
- [ ] Replace the Notifications placeholder action with the modal.
- [ ] Run the focused widget tests GREEN and check a narrow phone viewport for
  overflow.

### Task 7: Register FCM Tokens

**Files:**
- Create: `lib/src/state/notifications/notification_token_store.dart`
- Create: `lib/src/state/notifications/firebase_notification_token_store.dart`
- Create: `test/state/notifications/notification_token_store_test.dart`
- Create: `integration_test/state/notifications/firebase_notification_token_store_test.dart`
- Modify: `lib/src/state/notifications/notification_providers.dart`

- [ ] Write failing headless contract tests for save, replace, delete, and
  token hash stability.
- [ ] Implement SHA-256 document IDs and auth-bound Firestore writes.
- [ ] Add structurally complete emulator integration tests without running
  the full integration suite.
- [ ] Run the headless token tests GREEN.

### Task 8: Add Suggested Check-In Cloud Function

**Files:**
- Modify: `firebase.json`
- Create: `functions/package.json`
- Create: `functions/index.js`
- Create: `functions/maintenance_policy.js`
- Create: `functions/test/maintenance_policy.test.js`
- Create: `functions/test/suggested_check_ins.test.js`

- [ ] Write failing Jest tests for policy parity, ranking, local-hour
  eligibility, quiet hours, daily delivery keys, copy, and invalid-token
  errors.
- [ ] Implement pure helpers and run them GREEN.
- [ ] Implement the hourly v2 scheduled function with Admin SDK reads,
  transactional daily claim, multicast FCM send, and invalid-token cleanup.
- [ ] Run `npm test` in `functions` and confirm GREEN.

### Task 9: Verify And Document

**Files:**
- Modify: `CONTEXT.md`
- Modify: `progress.md`

- [ ] Run focused Flutter notification/state/widget tests.
- [ ] Run Firestore rules Jest tests.
- [ ] Run Functions Jest tests.
- [ ] Run touched-file `dart analyze` and `git diff --check`.
- [ ] Build or run the Android app and verify the Notifications modal,
  permission prompt, and pending local reminder flow.
- [ ] Update domain seams and worklog with exact evidence and deployment
  status.
- [ ] Review the final diff for preference compatibility, token security,
  anti-shame copy, and accidental unrelated changes.
