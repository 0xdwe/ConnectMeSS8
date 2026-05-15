# Figma Reference Feature Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the missing user-facing features and visual patterns from `figma_reference/` into the real Flutter app.

**Architecture:** Keep the Flutter app as source of truth and translate React state/features into Riverpod `AppState` mutations plus Flutter modals/screens. Extend existing models conservatively instead of adding storage or new packages. Preserve current routing and widget structure while making UI match the Figma export: teal headers, rounded white sheets, icon-first actions, segmented/toggle controls, searchable contact linking, undo snackbars.

**Tech Stack:** Flutter, Dart, Riverpod `NotifierProvider`, GoRouter, Material widgets, existing test stack (`flutter_test`).

---

## Source Feature Map

`figma_reference/src/app/App.tsx` has these shipped features not fully present in Flutter:

- Editable user profile with name, email, emoji/image avatar.
- Settings entry for Manage Event Types.
- Event create/edit/delete in one modal, with all-day toggle, start/end time, recurring toggle, recurrence pattern, optional contact link, custom event type.
- Event delete undo toast.
- Contact edit modal with delete action.
- Shared Activity modal that logs note/photo activity and shows an AI suggestion before saving.
- Contact dashboard actions: edit, share activity, AI update.
- Header/profile display uses editable user data.

Flutter already has:

- Auth, shell tabs, profile screen, contact screen, recommendations, AI update screen.
- Add/edit connection basics.
- Add event basics.
- Manage categories basics.
- Theme modal.
- AI update state mutation.

## File Structure

- Modify `lib/src/models/social_models.dart`
  - Add `AppUser`.
  - Extend `PlannerEvent` with Figma event fields.
  - Add `RecurrencePattern` enum or use string labels via extension. Use enum for type safety.
  - Add `copyWith` for `PlannerEvent`.

- Modify `lib/src/state/app_state.dart`
  - Store `user` and `eventTypes`.
  - Seed Figma reference user/event data.
  - Add controller methods: `updateUser`, `saveEvent`, `deleteEvent`, `restoreEvent`, `addEventType`, `renameEventType`, `deleteEventType`, `deleteConnection`, `logSharedActivity`.

- Modify `lib/src/widgets/crm_widgets.dart`
  - Make `AppHeader` accept `userName` and `userAvatar`.
  - Add tiny reusable action row/sheet helpers only if they reduce duplicate modal code.

- Modify `lib/src/features/shell_screen.dart`
  - Pass user data to `AppHeader`.
  - Add "Share Activity" action to plus menu if design has room; keep existing Add/Update actions.

- Modify `lib/src/features/profile_screen.dart`
  - Render editable `state.user`.
  - Add edit icon button that opens profile modal.

- Create `lib/src/features/modals/edit_user_profile_modal.dart`
  - Bottom sheet with avatar preview, Emoji/Image segmented control, name/email fields, Save.
  - Image mode stores typed URL/path string for now; no new file picker dependency.

- Modify `lib/src/features/tabs/settings_tab.dart`
  - Open edit profile modal for Edit Profile row.
  - Add Manage Event Types row.

- Create `lib/src/features/modals/manage_event_types_modal.dart`
  - Add/edit/delete event types.
  - Protect default types: `Plan`, `Reminder`, `Birthday`, `Meeting`, `Call`, `Dinner`, `Coffee`.

- Modify `lib/src/features/modals/add_event_modal.dart`
  - Support create and edit modes.
  - Add event type, all-day toggle, start/end `TimeOfDay`, recurring toggle, recurrence pattern, optional contact selector.
  - Add Delete button in edit mode.

- Modify `lib/src/features/tabs/planner_tab.dart`
  - Open event modal on event tap with selected event.
  - Show event type/time/recurrence chips in list/calendar cards.
  - Show undo snackbar after delete.

- Create `lib/src/features/modals/shared_activity_modal.dart`
  - Contact selector, note/photo segmented control, content field, AI suggestion card, Save.

- Modify `lib/src/features/contact_profile_screen.dart`
  - Add Share Activity button beside Edit and AI Update.
  - Show shared activity history with attachment label.

- Modify `lib/src/features/modals/edit_connection_modal.dart`
  - Add delete action matching Figma modal.
  - Confirm delete before removing.

- Modify `test/state/app_state_test.dart`
  - Add focused state mutation tests for user, event CRUD/undo, event types, shared activity, delete connection cascade.

- Modify `test/widget_test.dart`
  - Add smoke tests for settings event type modal and planner edit event modal.

---

### Task 1: Extend Models And State

**Files:**
- Modify: `lib/src/models/social_models.dart`
- Modify: `lib/src/state/app_state.dart`
- Test: `test/state/app_state_test.dart`

- [ ] **Step 1: Write failing state tests**

Append these tests inside `main()` in `test/state/app_state_test.dart`:

```dart
  test('user profile updates drive app state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appControllerProvider.notifier).updateUser(
      name: 'Jamie Chen',
      email: 'jamie@example.com',
      avatar: '🙂',
      avatarKind: AvatarKind.emoji,
    );

    final user = container.read(appControllerProvider).user;
    expect(user.name, 'Jamie Chen');
    expect(user.email, 'jamie@example.com');
    expect(user.avatar, '🙂');
    expect(user.avatarKind, AvatarKind.emoji);
  });

  test('event CRUD supports edit, delete, and restore', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appControllerProvider.notifier);
    controller.saveEvent(
      PlannerEvent(
        id: 'custom-event',
        title: 'Lunch with Sam',
        contactId: 'sarah',
        category: 'Friends',
        date: DateTime(2026, 5, 20),
        note: 'Try ramen place',
        eventType: 'Lunch',
        isAllDay: false,
        startTimeMinutes: 12 * 60,
        endTimeMinutes: 13 * 60,
        isRecurring: true,
        recurrencePattern: RecurrencePattern.monthly,
      ),
    );

    expect(container.read(appControllerProvider).events.last.title, 'Lunch with Sam');

    controller.saveEvent(
      container.read(appControllerProvider).events.last.copyWith(
            title: 'Lunch with Sarah',
            eventType: 'Coffee',
          ),
    );

    final edited = container
        .read(appControllerProvider)
        .events
        .firstWhere((event) => event.id == 'custom-event');
    expect(edited.title, 'Lunch with Sarah');
    expect(edited.eventType, 'Coffee');

    final deleted = controller.deleteEvent('custom-event');
    expect(deleted?.id, 'custom-event');
    expect(
      container.read(appControllerProvider).events.any((event) => event.id == 'custom-event'),
      isFalse,
    );

    controller.restoreEvent(deleted!);
    expect(
      container.read(appControllerProvider).events.any((event) => event.id == 'custom-event'),
      isTrue,
    );
  });

  test('event type management protects defaults and updates custom types', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appControllerProvider.notifier);
    controller.addEventType('Workshop');
    controller.renameEventType('Workshop', 'Demo Day');
    controller.deleteEventType('Plan');
    controller.deleteEventType('Demo Day');

    final eventTypes = container.read(appControllerProvider).eventTypes;
    expect(eventTypes, contains('Plan'));
    expect(eventTypes, isNot(contains('Workshop')));
    expect(eventTypes, isNot(contains('Demo Day')));
  });

  test('shared activity creates interaction and bumps contact momentum', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(appControllerProvider).interactions.length;
    container.read(appControllerProvider.notifier).logSharedActivity(
          contactId: 'sarah',
          type: SharedActivityType.note,
          content: 'Walked by the river and talked about summer plans.',
        );

    final state = container.read(appControllerProvider);
    expect(state.interactions.length, before + 1);
    expect(state.interactions.first.contactId, 'sarah');
    expect(state.interactions.first.type, InteractionType.sharedActivity);
    expect(state.interactions.first.note, contains('summer plans'));
  });

  test('deleting connection removes related events and interactions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appControllerProvider.notifier).deleteConnection('mike');

    final state = container.read(appControllerProvider);
    expect(state.connections.any((connection) => connection.id == 'mike'), isFalse);
    expect(state.events.any((event) => event.contactId == 'mike'), isFalse);
    expect(state.interactions.any((interaction) => interaction.contactId == 'mike'), isFalse);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/state/app_state_test.dart
```

Expected: FAIL with missing `AppState.user`, `AvatarKind`, `RecurrencePattern`, `eventTypes`, `updateUser`, `saveEvent`, `restoreEvent`, `addEventType`, `renameEventType`, `deleteEventType`, `logSharedActivity`, `deleteConnection`.

- [ ] **Step 3: Add model types and copy helpers**

In `lib/src/models/social_models.dart`, add before `AttachmentRef`:

```dart
enum AvatarKind { emoji, image }

enum RecurrencePattern { daily, weekly, monthly, yearly }

extension RecurrencePatternLabel on RecurrencePattern {
  String get label => switch (this) {
    RecurrencePattern.daily => 'Daily',
    RecurrencePattern.weekly => 'Weekly',
    RecurrencePattern.monthly => 'Monthly',
    RecurrencePattern.yearly => 'Yearly',
  };
}

enum SharedActivityType { note, photo }

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.avatar,
    required this.avatarKind,
    required this.totalPoints,
    required this.currentLevel,
    required this.nextLevelPoints,
  });

  final String name;
  final String email;
  final String avatar;
  final AvatarKind avatarKind;
  final int totalPoints;
  final int currentLevel;
  final int nextLevelPoints;

  AppUser copyWith({
    String? name,
    String? email,
    String? avatar,
    AvatarKind? avatarKind,
    int? totalPoints,
    int? currentLevel,
    int? nextLevelPoints,
  }) {
    return AppUser(
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      avatarKind: avatarKind ?? this.avatarKind,
      totalPoints: totalPoints ?? this.totalPoints,
      currentLevel: currentLevel ?? this.currentLevel,
      nextLevelPoints: nextLevelPoints ?? this.nextLevelPoints,
    );
  }
}
```

Replace `PlannerEvent` with:

```dart
class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.title,
    required this.contactId,
    required this.category,
    required this.date,
    required this.note,
    this.eventType = 'Plan',
    this.isAllDay = true,
    this.startTimeMinutes,
    this.endTimeMinutes,
    this.isRecurring = false,
    this.recurrencePattern,
  });

  final String id;
  final String title;
  final String? contactId;
  final String category;
  final DateTime date;
  final String note;
  final String eventType;
  final bool isAllDay;
  final int? startTimeMinutes;
  final int? endTimeMinutes;
  final bool isRecurring;
  final RecurrencePattern? recurrencePattern;

  PlannerEvent copyWith({
    String? title,
    String? contactId,
    String? category,
    DateTime? date,
    String? note,
    String? eventType,
    bool? isAllDay,
    int? startTimeMinutes,
    int? endTimeMinutes,
    bool? isRecurring,
    RecurrencePattern? recurrencePattern,
  }) {
    return PlannerEvent(
      id: id,
      title: title ?? this.title,
      contactId: contactId ?? this.contactId,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      eventType: eventType ?? this.eventType,
      isAllDay: isAllDay ?? this.isAllDay,
      startTimeMinutes: startTimeMinutes ?? this.startTimeMinutes,
      endTimeMinutes: endTimeMinutes ?? this.endTimeMinutes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
    );
  }
}
```

- [ ] **Step 4: Extend AppState**

In `lib/src/state/app_state.dart`, add constructor fields:

```dart
    required this.user,
    required this.eventTypes,
```

Add fields:

```dart
  final AppUser user;
  final List<String> eventTypes;
```

In `seeded()`, add:

```dart
      user: const AppUser(
        name: 'Alex Martinez',
        email: 'alex.martinez@email.com',
        avatar: '👤',
        avatarKind: AvatarKind.emoji,
        totalPoints: 240,
        currentLevel: 7,
        nextLevelPoints: 300,
      ),
      eventTypes: const ['Plan', 'Reminder', 'Birthday', 'Meeting', 'Call', 'Dinner', 'Coffee'],
```

Update seed events to include Figma fields:

```dart
        PlannerEvent(
          id: 'e1',
          title: 'Coffee with Sarah',
          contactId: 'sarah',
          category: 'Friends',
          date: DateTime(2026, 4, 28),
          note: 'Google Calendar mock sync',
          eventType: 'Coffee',
          isAllDay: false,
          startTimeMinutes: 10 * 60,
          endTimeMinutes: 11 * 60 + 30,
        ),
```

Apply the same pattern to remaining seeded events:

```dart
eventType: 'Meeting' // Team Meeting, timed 14:00-15:30
eventType: 'Reminder' // Call Mike, all day
eventType: 'Birthday' // Emily Birthday, all day
eventType: 'Dinner' // Family Dinner, timed 18:30-21:00
```

Update `copyWith` args and return:

```dart
    AppUser? user,
    List<String>? eventTypes,
```

```dart
      user: user ?? this.user,
      eventTypes: eventTypes ?? this.eventTypes,
```

- [ ] **Step 5: Add controller methods**

In `AppController`, add:

```dart
  static const defaultEventTypes = ['Plan', 'Reminder', 'Birthday', 'Meeting', 'Call', 'Dinner', 'Coffee'];

  void updateUser({
    required String name,
    required String email,
    required String avatar,
    required AvatarKind avatarKind,
  }) {
    state = state.copyWith(
      user: state.user.copyWith(
        name: name.trim().isEmpty ? state.user.name : name.trim(),
        email: email.trim().isEmpty ? state.user.email : email.trim(),
        avatar: avatar.trim().isEmpty ? state.user.avatar : avatar.trim(),
        avatarKind: avatarKind,
      ),
    );
  }

  void saveEvent(PlannerEvent event) {
    final exists = state.events.any((item) => item.id == event.id);
    state = state.copyWith(
      events: exists
          ? [
              for (final item in state.events)
                if (item.id == event.id) event else item,
            ]
          : [...state.events, event],
    );
  }

  PlannerEvent? deleteEvent(String eventId) {
    PlannerEvent? deleted;
    final remaining = <PlannerEvent>[];
    for (final event in state.events) {
      if (event.id == eventId) {
        deleted = event;
      } else {
        remaining.add(event);
      }
    }
    state = state.copyWith(events: remaining);
    return deleted;
  }

  void restoreEvent(PlannerEvent event) {
    state = state.copyWith(
      events: [...state.events, event]..sort((a, b) => a.date.compareTo(b.date)),
    );
  }

  void addEventType(String eventType) {
    final clean = eventType.trim();
    if (clean.isEmpty || state.eventTypes.contains(clean)) return;
    state = state.copyWith(eventTypes: [...state.eventTypes, clean]);
  }

  void renameEventType(String oldValue, String newValue) {
    final clean = newValue.trim();
    if (clean.isEmpty || state.eventTypes.contains(clean)) return;
    state = state.copyWith(
      eventTypes: [
        for (final item in state.eventTypes)
          if (item == oldValue) clean else item,
      ],
      events: [
        for (final event in state.events)
          if (event.eventType == oldValue) event.copyWith(eventType: clean) else event,
      ],
    );
  }

  void deleteEventType(String eventType) {
    if (defaultEventTypes.contains(eventType)) return;
    state = state.copyWith(
      eventTypes: [
        for (final item in state.eventTypes)
          if (item != eventType) item,
      ],
      events: [
        for (final event in state.events)
          if (event.eventType == eventType) event.copyWith(eventType: 'Plan') else event,
      ],
    );
  }

  void deleteConnection(String contactId) {
    state = state.copyWith(
      connections: [
        for (final connection in state.connections)
          if (connection.id != contactId) connection,
      ],
      events: [
        for (final event in state.events)
          if (event.contactId != contactId) event,
      ],
      interactions: [
        for (final interaction in state.interactions)
          if (interaction.contactId != contactId) interaction,
      ],
    );
  }

  void logSharedActivity({
    required String contactId,
    required SharedActivityType type,
    required String content,
  }) {
    final interaction = CrmInteraction(
      id: _uuid.v4(),
      contactId: contactId,
      type: InteractionType.sharedActivity,
      title: type == SharedActivityType.photo ? 'Shared photo' : 'Shared note',
      note: content.trim(),
      date: DateTime.now(),
      attachments: type == SharedActivityType.photo
          ? [AttachmentRef(name: 'Shared photo', path: content.trim())]
          : const [],
    );
    final updatedConnections = [
      for (final connection in state.connections)
        if (connection.id == contactId)
          connection.copyWith(
            lastContact: DateTime.now(),
            bondScore: (connection.bondScore + 3).clamp(0, 100),
            nextStep: 'Plan a follow-up activity within the next week',
          )
        else
          connection,
    ];
    state = state.copyWith(
      interactions: [interaction, ...state.interactions],
      connections: updatedConnections,
    );
  }
```

Replace existing `addEvent(...)` call body with:

```dart
    saveEvent(
      PlannerEvent(
        id: _uuid.v4(),
        title: title,
        contactId: contactId,
        category: category,
        date: date,
        note: note,
      ),
    );
```

- [ ] **Step 6: Run state tests**

Run:

```bash
flutter test test/state/app_state_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/models/social_models.dart lib/src/state/app_state.dart test/state/app_state_test.dart
git commit -m "feat: extend app state for figma features"
```

---

### Task 2: User Profile Editing

**Files:**
- Modify: `lib/src/widgets/crm_widgets.dart`
- Modify: `lib/src/features/shell_screen.dart`
- Modify: `lib/src/features/profile_screen.dart`
- Modify: `lib/src/features/tabs/settings_tab.dart`
- Create: `lib/src/features/modals/edit_user_profile_modal.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write failing widget smoke test**

Add to `test/widget_test.dart`:

```dart
testWidgets('profile can be edited from settings', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));

  await tester.tap(find.text('Continue with Email'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Setting'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit Profile'));
  await tester.pumpAndSettle();

  expect(find.text('Edit Profile'), findsWidgets);
  await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Jamie Chen');
  await tester.enterText(find.widgetWithText(TextField, 'Email'), 'jamie@example.com');
  await tester.tap(find.text('Save Changes'));
  await tester.pumpAndSettle();

  expect(find.text('Jamie Chen'), findsOneWidget);
});
```

- [ ] **Step 2: Run widget test to verify it fails**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: FAIL because settings opens `/me` instead of modal and no editable user state appears in header.

- [ ] **Step 3: Create edit profile modal**

Create `lib/src/features/modals/edit_user_profile_modal.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

Future<void> showEditUserProfileModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const EditUserProfileModal(),
  );
}

class EditUserProfileModal extends ConsumerStatefulWidget {
  const EditUserProfileModal({super.key});

  @override
  ConsumerState<EditUserProfileModal> createState() => _EditUserProfileModalState();
}

class _EditUserProfileModalState extends ConsumerState<EditUserProfileModal> {
  late final name = TextEditingController(text: ref.read(appControllerProvider).user.name);
  late final email = TextEditingController(text: ref.read(appControllerProvider).user.email);
  late final avatar = TextEditingController(text: ref.read(appControllerProvider).user.avatar);
  late AvatarKind avatarKind = ref.read(appControllerProvider).user.avatarKind;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 18, 22, bottom + 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Edit Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                ),
                IconButton(onPressed: Navigator.of(context).pop, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFE0F0F0),
                child: Text(avatar.text.isEmpty ? '👤' : avatar.text, style: const TextStyle(fontSize: 42)),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<AvatarKind>(
              segments: const [
                ButtonSegment(value: AvatarKind.emoji, icon: Icon(Icons.emoji_emotions_outlined), label: Text('Emoji')),
                ButtonSegment(value: AvatarKind.image, icon: Icon(Icons.image_outlined), label: Text('Image')),
              ],
              selected: {avatarKind},
              onSelectionChanged: (value) => setState(() => avatarKind = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avatar,
              decoration: InputDecoration(labelText: avatarKind == AvatarKind.emoji ? 'Avatar emoji' : 'Image URL or path'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.moss),
                    onPressed: () {
                      ref.read(appControllerProvider.notifier).updateUser(
                            name: name.text,
                            email: email.text,
                            avatar: avatar.text,
                            avatarKind: avatarKind,
                          );
                      Navigator.pop(context);
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire editable user into header/profile/settings**

Change `AppHeader` in `lib/src/widgets/crm_widgets.dart`:

```dart
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.onProfileTap,
    required this.userName,
    required this.userAvatar,
  });
  final VoidCallback onProfileTap;
  final String userName;
  final String userAvatar;
```

Replace header title row avatar section:

```dart
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Connect Me',
                  style: TextStyle(
                    color: AppTheme.moss,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  userName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            key: const Key('profile-button'),
            borderRadius: BorderRadius.circular(40),
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFE0F0F0),
              child: Text(userAvatar, style: const TextStyle(fontSize: 32)),
            ),
          ),
```

In `lib/src/features/shell_screen.dart`, replace `AppHeader(...)`:

```dart
              AppHeader(
                userName: ref.watch(appControllerProvider.select((state) => state.user.name)),
                userAvatar: ref.watch(appControllerProvider.select((state) => state.user.avatar)),
                onProfileTap: () => context.push('/me'),
              ),
```

In `lib/src/features/profile_screen.dart`, import modal and replace hard-coded user values:

```dart
import 'modals/edit_user_profile_modal.dart';
```

Use:

```dart
final user = state.user;
```

Replace header back align with row:

```dart
Row(
  children: [
    Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: Navigator.of(context).pop,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, color: Colors.white, size: 34),
              SizedBox(width: 12),
              Text('Back', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    ),
    IconButton.filledTonal(
      onPressed: () => showEditUserProfileModal(context),
      icon: const Icon(Icons.edit),
    ),
  ],
),
```

Replace avatar/name/email:

```dart
CircleAvatar(radius: 66, backgroundColor: Colors.white, child: Text(user.avatar, style: const TextStyle(fontSize: 54))),
const SizedBox(height: 24),
Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
const SizedBox(height: 12),
Text(user.email, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700)),
```

In `lib/src/features/tabs/settings_tab.dart`, import modal:

```dart
import '../modals/edit_user_profile_modal.dart';
```

Replace edit row:

```dart
_Row(icon: Icons.person_outline, label: 'Edit Profile', onTap: () => showEditUserProfileModal(context)),
```

- [ ] **Step 5: Run widget test**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: PASS for new test; fix existing finders if current labels differ.

- [ ] **Step 6: Commit**

```bash
git add lib/src/widgets/crm_widgets.dart lib/src/features/shell_screen.dart lib/src/features/profile_screen.dart lib/src/features/tabs/settings_tab.dart lib/src/features/modals/edit_user_profile_modal.dart test/widget_test.dart
git commit -m "feat: add editable user profile"
```

---

### Task 3: Event Types And Event Edit Modal

**Files:**
- Create: `lib/src/features/modals/manage_event_types_modal.dart`
- Modify: `lib/src/features/modals/add_event_modal.dart`
- Modify: `lib/src/features/tabs/settings_tab.dart`
- Modify: `lib/src/features/tabs/planner_tab.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write failing widget smoke tests**

Add to `test/widget_test.dart`:

```dart
testWidgets('settings can add custom event type', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));

  await tester.tap(find.text('Continue with Email'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Setting'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Manage Event Types'));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextField, 'New event type'), 'Workshop');
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  expect(find.text('Workshop'), findsOneWidget);
});

testWidgets('planner opens existing event in edit mode', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));

  await tester.tap(find.text('Continue with Email'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Planner'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Coffee with Sarah').first);
  await tester.pumpAndSettle();

  expect(find.text('Edit Event'), findsOneWidget);
  expect(find.text('Delete Event'), findsOneWidget);
});
```

- [ ] **Step 2: Run widget tests to verify failure**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: FAIL because Manage Event Types row/modal and planner event edit mode are missing.

- [ ] **Step 3: Create Manage Event Types modal**

Create `lib/src/features/modals/manage_event_types_modal.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

Future<void> showManageEventTypesModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ManageEventTypesModal(),
  );
}

class ManageEventTypesModal extends ConsumerStatefulWidget {
  const ManageEventTypesModal({super.key});

  @override
  ConsumerState<ManageEventTypesModal> createState() => _ManageEventTypesModalState();
}

class _ManageEventTypesModalState extends ConsumerState<ManageEventTypesModal> {
  final eventType = TextEditingController();
  String? editing;
  final editValue = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(appControllerProvider.select((state) => state.eventTypes));
    final controller = ref.read(appControllerProvider.notifier);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Manage Event Types', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                IconButton(onPressed: Navigator.of(context).pop, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB7D7FF)),
              ),
              child: const Text('Default event types cannot be deleted. Custom types can be edited or removed.'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: TextField(controller: eventType, decoration: const InputDecoration(labelText: 'New event type'))),
                IconButton.filled(
                  onPressed: () {
                    controller.addEventType(eventType.text);
                    eventType.clear();
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final type in types)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: editing == type
                    ? TextField(controller: editValue, decoration: const InputDecoration(labelText: 'Event type name'))
                    : Text(type),
                trailing: editing == type
                    ? Wrap(
                        children: [
                          IconButton(
                            onPressed: () {
                              controller.renameEventType(type, editValue.text);
                              setState(() => editing = null);
                            },
                            icon: const Icon(Icons.check),
                          ),
                          IconButton(onPressed: () => setState(() => editing = null), icon: const Icon(Icons.close)),
                        ],
                      )
                    : Wrap(
                        children: [
                          if (AppController.defaultEventTypes.contains(type))
                            const Padding(
                              padding: EdgeInsets.only(top: 12, right: 8),
                              child: Text('Default', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                            ),
                          IconButton(
                            onPressed: () {
                              editValue.text = type;
                              setState(() => editing = type);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: AppController.defaultEventTypes.contains(type) ? null : () => controller.deleteEventType(type),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire settings row**

In `lib/src/features/tabs/settings_tab.dart`, import:

```dart
import '../modals/manage_event_types_modal.dart';
```

Add row in Customization card:

```dart
_Row(icon: Icons.event_note_outlined, label: 'Manage Event Types', onTap: () => showManageEventTypesModal(context)),
```

- [ ] **Step 5: Replace AddEventModal with edit-capable modal**

Change signature in `lib/src/features/modals/add_event_modal.dart`:

```dart
Future<void> showAddEventModal(
  BuildContext context, {
  DateTime? initialDate,
  PlannerEvent? event,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddEventModal(initialDate: initialDate, event: event),
  );
}

class AddEventModal extends ConsumerStatefulWidget {
  const AddEventModal({super.key, this.initialDate, this.event});
  final DateTime? initialDate;
  final PlannerEvent? event;
```

Inside state, initialize:

```dart
  late final title = TextEditingController(text: widget.event?.title ?? '');
  late final note = TextEditingController(text: widget.event?.note ?? '');
  late DateTime date = widget.event?.date ?? widget.initialDate ?? DateTime.now();
  late String? contactId = widget.event?.contactId;
  late String category = widget.event?.category ?? ref.read(appControllerProvider).categories.first;
  late String eventType = widget.event?.eventType ?? ref.read(appControllerProvider).eventTypes.first;
  late bool isAllDay = widget.event?.isAllDay ?? true;
  late TimeOfDay startTime = _timeFromMinutes(widget.event?.startTimeMinutes ?? 9 * 60);
  late TimeOfDay endTime = _timeFromMinutes(widget.event?.endTimeMinutes ?? 10 * 60);
  late bool isRecurring = widget.event?.isRecurring ?? false;
  late RecurrencePattern recurrencePattern = widget.event?.recurrencePattern ?? RecurrencePattern.weekly;

  TimeOfDay _timeFromMinutes(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  int _minutesFromTime(TimeOfDay time) => time.hour * 60 + time.minute;
```

Build fields in this order:

```dart
Text(widget.event == null ? 'Add Event' : 'Edit Event', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))
TextField(controller: title, decoration: const InputDecoration(labelText: 'Event Title'))
ListTile(...date picker...)
SwitchListTile(title: const Text('All Day'), value: isAllDay, onChanged: (value) => setState(() => isAllDay = value))
if (!isAllDay) Row(children: [start time picker, end time picker])
DropdownButtonFormField<String>(value: eventType, decoration: const InputDecoration(labelText: 'Event Type'), items: state.eventTypes...)
DropdownButtonFormField<String?>(value: contactId, decoration: const InputDecoration(labelText: 'Link to Contact (Optional)'), items: [const DropdownMenuItem<String?>(value: null, child: Text('No contact')), ...])
SwitchListTile(title: const Text('Repeat'), value: isRecurring, onChanged: (value) => setState(() => isRecurring = value))
if (isRecurring) SegmentedButton<RecurrencePattern>(...)
TextField(controller: note, decoration: const InputDecoration(labelText: 'Note'))
```

Save with:

```dart
final cleanTitle = title.text.trim();
ref.read(appControllerProvider.notifier).saveEvent(
  PlannerEvent(
    id: widget.event?.id ?? const Uuid().v4(),
    title: cleanTitle.isEmpty ? 'New Event' : cleanTitle,
    contactId: contactId,
    category: category,
    date: date,
    note: note.text.trim(),
    eventType: eventType,
    isAllDay: isAllDay,
    startTimeMinutes: isAllDay ? null : _minutesFromTime(startTime),
    endTimeMinutes: isAllDay ? null : _minutesFromTime(endTime),
    isRecurring: isRecurring,
    recurrencePattern: isRecurring ? recurrencePattern : null,
  ),
);
Navigator.pop(context);
```

Import `uuid`:

```dart
import 'package:uuid/uuid.dart';
```

Add edit-mode delete button:

```dart
if (widget.event != null)
  TextButton.icon(
    onPressed: () {
      final deleted = ref.read(appControllerProvider.notifier).deleteEvent(widget.event!.id);
      Navigator.pop(context, deleted);
    },
    icon: const Icon(Icons.delete_outline),
    label: const Text('Delete Event'),
  ),
```

- [ ] **Step 6: Wire planner event edit and undo**

In `lib/src/features/tabs/planner_tab.dart`, find event tap handler. Replace with:

```dart
onTap: () async {
  final deleted = await showAddEventModal(context, event: event);
  if (deleted is PlannerEvent && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${deleted.title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref.read(appControllerProvider.notifier).restoreEvent(deleted),
        ),
      ),
    );
  }
},
```

Show event metadata near title:

```dart
Text(
  event.isAllDay
      ? '${event.eventType}${event.isRecurring ? ' • ${event.recurrencePattern?.label ?? 'Repeats'}' : ''}'
      : '${event.eventType} • ${_formatMinutes(event.startTimeMinutes)}-${_formatMinutes(event.endTimeMinutes)}',
  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
),
```

Add helper:

```dart
String _formatMinutes(int? minutes) {
  if (minutes == null) return '';
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}
```

- [ ] **Step 7: Run tests**

Run:

```bash
flutter test test/widget_test.dart test/state/app_state_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/src/features/modals/manage_event_types_modal.dart lib/src/features/modals/add_event_modal.dart lib/src/features/tabs/settings_tab.dart lib/src/features/tabs/planner_tab.dart test/widget_test.dart
git commit -m "feat: port event editing and event types"
```

---

### Task 4: Shared Activity Modal

**Files:**
- Create: `lib/src/features/modals/shared_activity_modal.dart`
- Modify: `lib/src/features/shell_screen.dart`
- Modify: `lib/src/features/contact_profile_screen.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write failing widget smoke test**

Add to `test/widget_test.dart`:

```dart
testWidgets('contact screen can share activity note', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));

  await tester.tap(find.text('Continue with Email'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('People'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sarah Johnson'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Share Activity'));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'Walked by the river');
  expect(find.text('AI Suggestion'), findsOneWidget);
  await tester.tap(find.text('Share Activity').last);
  await tester.pumpAndSettle();

  expect(find.text('Walked by the river'), findsOneWidget);
});
```

- [ ] **Step 2: Run widget test to verify failure**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: FAIL because Share Activity button/modal are missing.

- [ ] **Step 3: Create shared activity modal**

Create `lib/src/features/modals/shared_activity_modal.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

Future<void> showSharedActivityModal(BuildContext context, {String? initialContactId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SharedActivityModal(initialContactId: initialContactId),
  );
}

class SharedActivityModal extends ConsumerStatefulWidget {
  const SharedActivityModal({super.key, this.initialContactId});
  final String? initialContactId;

  @override
  ConsumerState<SharedActivityModal> createState() => _SharedActivityModalState();
}

class _SharedActivityModalState extends ConsumerState<SharedActivityModal> {
  String? contactId;
  SharedActivityType type = SharedActivityType.note;
  final content = TextEditingController();

  @override
  void initState() {
    super.initState();
    contactId = widget.initialContactId;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    contactId ??= state.connections.first.id;
    final hasContent = content.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Share Activity', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                IconButton(onPressed: Navigator.of(context).pop, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: contactId,
              decoration: const InputDecoration(labelText: 'Contact'),
              items: state.connections.map((contact) => DropdownMenuItem(value: contact.id, child: Text(contact.name))).toList(),
              onChanged: (value) => setState(() => contactId = value),
            ),
            const SizedBox(height: 14),
            SegmentedButton<SharedActivityType>(
              segments: const [
                ButtonSegment(value: SharedActivityType.note, icon: Icon(Icons.notes_outlined), label: Text('Note')),
                ButtonSegment(value: SharedActivityType.photo, icon: Icon(Icons.image_outlined), label: Text('Photo')),
              ],
              selected: {type},
              onSelectionChanged: (value) => setState(() => type = value.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: content,
              minLines: type == SharedActivityType.note ? 4 : 1,
              maxLines: type == SharedActivityType.note ? 6 : 1,
              decoration: InputDecoration(labelText: type == SharedActivityType.note ? 'Notes' : 'Photo URL or path'),
              onChanged: (_) => setState(() {}),
            ),
            if (hasContent) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7D6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Suggestion', style: TextStyle(fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('This shared moment shows strong connection. Plan a follow-up activity within the next week to maintain momentum.'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.moss),
                    onPressed: hasContent
                        ? () {
                            ref.read(appControllerProvider.notifier).logSharedActivity(
                                  contactId: contactId!,
                                  type: type,
                                  content: content.text,
                                );
                            Navigator.pop(context);
                          }
                        : null,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share Activity'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire contact action**

In `lib/src/features/contact_profile_screen.dart`, import:

```dart
import 'modals/shared_activity_modal.dart';
```

Add button in header action row between edit and AI:

```dart
IconButton.filledTonal(
  tooltip: 'Share Activity',
  onPressed: () => showSharedActivityModal(context, initialContactId: person.id),
  icon: const Icon(Icons.ios_share),
),
```

Add visible text button under score panels for testability and accessibility:

```dart
FilledButton.icon(
  onPressed: () => showSharedActivityModal(context, initialContactId: person.id),
  icon: const Icon(Icons.ios_share),
  label: const Text('Share Activity'),
),
const SizedBox(height: 16),
```

- [ ] **Step 5: Wire shell plus menu**

In `lib/src/features/shell_screen.dart`, import:

```dart
import 'modals/shared_activity_modal.dart';
```

Add pill above Update Connection:

```dart
_ActionPill(label: 'Share Activity', onTap: () { setState(() => actionsOpen = false); showSharedActivityModal(context); }),
const SizedBox(height: 16),
```

- [ ] **Step 6: Run tests**

Run:

```bash
flutter test test/widget_test.dart test/state/app_state_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/features/modals/shared_activity_modal.dart lib/src/features/shell_screen.dart lib/src/features/contact_profile_screen.dart test/widget_test.dart
git commit -m "feat: add shared activity logging"
```

---

### Task 5: Contact Delete And Visual Polish

**Files:**
- Modify: `lib/src/features/modals/edit_connection_modal.dart`
- Modify: `lib/src/features/contact_profile_screen.dart`
- Modify: `lib/src/features/tabs/people_tab.dart`
- Modify: `lib/src/features/tabs/home_tab.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write failing widget test for contact delete**

Add to `test/widget_test.dart`:

```dart
testWidgets('contact edit modal can delete a connection', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: ConnectMeApp()));

  await tester.tap(find.text('Continue with Email'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('People'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mike Chen'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete Connection'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();

  expect(find.text('Mike Chen'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: FAIL because edit modal has no delete action.

- [ ] **Step 3: Add delete action to edit connection modal**

In `lib/src/features/modals/edit_connection_modal.dart`, add below Save:

```dart
const SizedBox(height: 10),
TextButton.icon(
  onPressed: () async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Remove ${widget.connection.name} and related events?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(appControllerProvider.notifier).deleteConnection(widget.connection.id);
      Navigator.pop(context);
      Navigator.pop(context);
    }
  },
  icon: const Icon(Icons.delete_outline),
  label: const Text('Delete Connection'),
),
```

- [ ] **Step 4: Match Figma card density and action affordances**

In `lib/src/features/contact_profile_screen.dart`:

- Keep teal top header.
- Make action buttons have tooltips: `Edit`, `Share Activity`, `AI Update`.
- Make history card subtitles include date and note:

```dart
subtitle: Text('${DateFormat.yMMMd().format(item.date)} • ${item.note}'),
```

Import:

```dart
import 'package:intl/intl.dart';
```

In `lib/src/features/tabs/people_tab.dart`:

- Ensure each contact card shows avatar, name, category chip, last contact, score ring.
- Preserve existing search/filter/sort behavior.
- Use `ScoreRing(score: person.bondScore, size: 58, stroke: 6)` if score is text-only now.

In `lib/src/features/tabs/home_tab.dart`:

- Ensure top action area has three clear buttons matching Figma: Add Connection, Update Connection, View Recommendations.
- Use icons: `Icons.person_add_alt_1`, `Icons.auto_awesome`, `Icons.lightbulb_outline`.

- [ ] **Step 5: Run full verification**

Run:

```bash
dart format lib test
flutter test
flutter analyze
```

Expected: format changes only in touched Dart files, all tests PASS, analyze reports no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/modals/edit_connection_modal.dart lib/src/features/contact_profile_screen.dart lib/src/features/tabs/people_tab.dart lib/src/features/tabs/home_tab.dart test/widget_test.dart
git commit -m "feat: polish contact dashboard actions"
```

---

## Final Verification

- [ ] Run all automated checks:

```bash
dart format lib test
flutter test
flutter analyze
```

Expected: all pass.

- [ ] Manual smoke test:

```bash
flutter run -d chrome
```

Expected:

- Login works.
- Header shows editable user name/avatar.
- Settings -> Edit Profile saves name/email/avatar.
- Settings -> Manage Event Types adds custom type and protects defaults.
- Planner opens event edit modal, supports all-day, timed, recurring, contact link, delete, undo.
- Contact screen opens Share Activity, saves note/photo path, updates history.
- Contact edit can delete connection and return to People.
- Existing AI update flow still works.

## Self-Review

**Spec coverage:** This plan ports implemented Figma features visible in `App.tsx` and component files into Flutter: profile edit, event type management, event CRUD/undo, shared activity, contact delete, header/profile display, visual action patterns.

**Placeholder scan:** No task contains TBD, TODO, "similar to", or unscoped "handle edge cases". Each code-changing task includes exact file targets and concrete code snippets.

**Type consistency:** `AvatarKind`, `RecurrencePattern`, `SharedActivityType`, `AppUser`, `PlannerEvent.copyWith`, and `AppController` methods are introduced before any task uses them.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-05-figma-reference-feature-port.md`. Two execution options:

**1. Subagent-Driven (recommended)** - Dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
