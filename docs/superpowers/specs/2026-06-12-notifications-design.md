# ConnectMe Notifications Design

Date: 2026-06-12
Status: approved for implementation

## Goal

Turn Settings > Notifications into functional controls for planner reminders,
birthday reminders, and gentle suggested check-ins. Preferences follow the
signed-in account, local reminders work without a server, and suggested
check-ins use Firebase Cloud Messaging.

## Product Behavior

- A master `Allow notifications` switch controls every notification channel.
- Enabling the master switch requests the operating-system notification
  permission in direct response to the user's tap.
- Disabling the master switch cancels local reminders and unregisters the
  current FCM token.
- `Suggested check-ins` sends at most one gentle recommendation per local day.
- `Planner reminders` schedules non-birthday PlannerEvents using one global
  lead time. Presets are 15 minutes, 1 hour, 1 day, and 2 days, with a custom
  minutes/hours/days/weeks option.
- `Birthday reminders` schedules Birthday PlannerEvents for 9:00 AM on the
  event date, 1 day before, 1 week before, or a custom lead time.
- `Quiet hours` defer a notification to the quiet-hours end. A planner
  reminder is dropped if deferral would move it past the event start.
- Permission-denied UI explains that ConnectMe cannot notify and offers an
  operating-system settings action.
- User-facing check-in copy remains gentle and contains no numeric overdue
  counts.

## Persistence

Notification preferences extend the existing `UserDocStore` snapshot and are
stored as a closed `notificationPreferences` map on `users/{uid}`. Writes use
`set + merge: true`, preserving categories, event types, and seeder sentinels.

The map contains:

- `enabled`
- `suggestedCheckIns`
- `plannerReminders`
- `birthdayReminders`
- `defaultReminderMinutes`
- `birthdayReminderMinutes`
- `quietHoursEnabled`
- `quietStartMinutes`
- `quietEndMinutes`
- `timeZone`
- `schemaVersion`

Missing or malformed maps decode to defaults so existing accounts remain
compatible.

FCM registrations live at
`users/{uid}/notificationTokens/{sha256(token)}` with the token, platform,
time zone, and updated timestamp. The signed-in owner may create, update, or
delete only well-formed token documents. Cloud Functions use the Admin SDK to
read registrations and remove tokens rejected by FCM.

## Flutter Architecture

`NotificationPreferencesController` is a Riverpod notifier that watches the
auth-aware `UserDocStore`, mirrors preference snapshots, and writes preference
updates durably before publishing state.

`NotificationGateway` isolates platform plugins. Production uses
`firebase_messaging`, `flutter_local_notifications`, `flutter_timezone`, and
`timezone`; tests use an in-memory fake.

`NotificationSchedulePlanner` is pure Dart. It converts PlannerEvents plus
preferences and `now` into at most 50 stable scheduled requests. It handles
all-day events, timed events, birthday separation, recurring next
occurrences, quiet hours, past events, and deterministic notification IDs.

`NotificationCoordinator` observes signed-in identity, preferences, and the
current PlannerEvent snapshot. It initializes plugins, registers or removes
the FCM token, and replaces ConnectMe-owned local schedules whenever those
inputs change. Permission prompts are never initiated by this background
coordinator; they are initiated only by the settings interaction.

Foreground FCM messages are displayed through the local notification plugin.
Background notification messages are displayed by the operating system.

## Cloud Function

A second-generation scheduled function runs hourly. For each user whose
preferences enable suggested check-ins, it:

1. Resolves the user's local hour from the persisted IANA time zone.
2. Targets 9:00 AM, or the first hourly run after quiet hours end.
3. Uses connection category, Bond Score tier, latest interaction, and the
   shipped Maintenance Need thresholds to choose the highest-need Connection.
4. Claims a daily delivery document transactionally before sending.
5. Sends a notification titled `A gentle check-in` with body
   `<name> could use a check-in.`
6. Removes invalid FCM token documents.

The function mirrors the pure Dart maintenance policy constants. A parity
test locks the JavaScript policy boundaries to the documented calibration.

## Platform Configuration

Android uses inexact scheduling, so ConnectMe does not request exact-alarm
permission. It declares notification, vibration, and reboot permissions plus
the plugin's scheduled-notification receivers. Core library desugaring is
enabled.

iOS enables Push Notifications and background remote notifications in the
project entitlements/capabilities. Permission is requested at runtime after
the user enables notifications.

## Limits And Evidence

- iOS keeps only 64 pending local notifications; ConnectMe schedules the
  earliest 50.
- Scheduled notifications are best-effort on Android devices whose vendors
  aggressively restrict background work.
- Headless Flutter tests cover preferences and schedule planning.
- Firestore rules tests cover preference maps and token ownership/shape.
- Function unit tests cover maintenance ranking, quiet-hour eligibility,
  daily de-duplication helpers, and invalid-token classification.
- The Android debug APK builds, installs, and launches on the emulator.
  Signed-in device delivery and APNs delivery still require configured
  test accounts and platform push credentials.
- Deploying scheduled Cloud Functions requires the Firebase project to have
  billing enabled.
