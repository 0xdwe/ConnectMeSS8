# Edit Profile Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhances the Edit Profile screen by pinning action buttons to the bottom of the screen, removing the redundant app bar save button, simplifying text field labels with prefix icons, and adding Quick Stats and Google Calendar integration controls.

**Architecture:** Update `lib/src/features/edit_profile_screen.dart` to clean up text fields, move action buttons into `Scaffold.bottomNavigationBar`, add a read-only stats bar, and expose the existing `toggleGoogleCalendar` controller method through a toggle switch in a new integrations card.

**Tech Stack:** Flutter, Riverpod, Material Design.

---

### Task 1: Add a failing widget test for Edit Profile Screen

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing widget test**

Add the following widget test to the end of `test/widget_test.dart` (before the final closing brace):

```dart
  testWidgets('EditProfileScreen displays stats, gcal sync switch, and handles layout updates', (WidgetTester tester) async {
    final eventsStore = InMemoryEventStore();
    final connectionsStore = InMemoryConnectionStore();
    final interactionStore = InMemoryInteractionStore();
    final userDocStore = InMemoryUserDocStore();
    final batchedWrites = InMemoryBatchedWrites(
      connectionStore: connectionsStore,
      interactionStore: interactionStore,
      eventStore: eventsStore,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(
                uid: 'demo-uid',
                isAnonymous: false,
                email: 'demo@example.com',
                displayName: 'Cliff Owen',
              ),
            ),
          ),
          eventStoreProvider.overrideWithValue(eventsStore),
          connectionStoreProvider.overrideWithValue(connectionsStore),
          interactionStoreProvider.overrideWithValue(interactionStore),
          userDocStoreProvider.overrideWithValue(userDocStore),
          batchedWritesProvider.overrideWithValue(batchedWrites),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(
            body: EditProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify stats cards are present
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Interactions'), findsOneWidget);
    expect(find.text('Avg Bond'), findsOneWidget);

    // Verify fields have prefix icons but no inner labels (e.g. labelText)
    final nameField = tester.widget<TextField>(find.byKey(const Key('profile-name-field')));
    expect(nameField.decoration?.labelText, isNull);
    expect(nameField.decoration?.prefixIcon, isNotNull);

    // Verify Google Calendar sync switch is present and toggles correctly
    expect(find.text('Sync with Google Calendar'), findsOneWidget);
    final switchFinder = find.byKey(const Key('profile-gcal-switch'));
    expect(switchFinder, findsOneWidget);

    // Redundant save button in AppBar actions should be removed
    expect(find.byIcon(Icons.save_outlined), findsNothing);

    // Bottom action buttons must exist
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "Set-Location c:\Users\sukse\ConnectMeSS8; flutter test test/widget_test.dart --name 'EditProfileScreen displays stats, gcal sync switch, and handles layout updates'"`
Expected: Compilation failure or test failure (since gcal switch, stats card, and field decor changes are not implemented).

- [ ] **Step 3: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: add widget test for edit profile screen enhancements"
```

---

### Task 2: Implement Edit Profile Screen enhancements

**Files:**
- Modify: `lib/src/features/edit_profile_screen.dart`

- [ ] **Step 1: Implement `_StatCard` private widget**

Append `_StatCard` helper class to the bottom of `lib/src/features/edit_profile_screen.dart`:

```dart
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceSunken,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: tokens.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.h3(color: tokens.ink),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption(color: tokens.inkSubtle).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Re-style text fields & add stats bar, gcal card, bottom navbar actions**

Modify `lib/src/features/edit_profile_screen.dart`:
1. Remove `actions` list from the `AppBar` (redundant save button).
2. Read the global `AppState` using `ref.watch(appControllerProvider)`.
3. Add the stats row and integrations/Google Calendar sync toggle switch.
4. Extract the Save & Cancel button row to `bottomNavigationBar` of the Scaffold.

Show the complete changes for `Widget build(BuildContext context)`:

```dart
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final appState = ref.watch(appControllerProvider);

    final previewProfile = AccountProfile(
      uid: _initialProfile?.uid ?? '',
      email: email.text,
      name: name.text.trim().isEmpty
          ? (_initialProfile?.name ?? '')
          : name.text.trim(),
      photoUrl: _removePhoto ? null : _initialProfile?.photoUrl,
    );

    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text('Edit Profile', style: AppTypography.h2(color: tokens.ink)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
        leadingWidth: 70,
        leading: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tokens.border),
            ),
            child: IconButton(
              icon: Icon(Icons.close, color: tokens.inkSubtle, size: 18),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space5,
            AppSpacing.space4,
            AppSpacing.space5,
            AppSpacing.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Center CircleAvatar with floating Camera Icon Overlay ───
              const SizedBox(height: 12),
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.primary.withValues(alpha: 0.15),
                          width: 4,
                        ),
                      ),
                      child: AccountAvatar(
                        profile: previewProfile,
                        radius: 64,
                        glyphSize: 48,
                        backgroundColor: tokens.primaryTint,
                        localImage: _pickedAvatar == null
                            ? null
                            : FileImage(_pickedAvatar!),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: tokens.primary,
                        elevation: 4,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _showAvatarOptionSheet,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            key: Key('edit-avatar-camera-button'),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // PROFILE PHOTO Label
              Center(
                child: Text(
                  'PROFILE PHOTO',
                  style: AppTypography.caption(color: tokens.primary).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Outlined Remove Photo pilled button
              Center(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _pickedAvatar = null;
                      _removePhoto = true;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(
                      color: tokens.danger.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Remove Photo',
                    style: AppTypography.body(
                      color: tokens.danger,
                    ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Quick Stats Row ───
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Connections',
                      value: '${appState.connections.length}',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Interactions',
                      value: '${appState.interactions.length}',
                      icon: Icons.chat_bubble_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Avg Bond',
                      value: '${appState.averageConnectionScore}%',
                      icon: Icons.favorite_border,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Input Fields Card (Name and Email) ───
              CardBox(
                padding: const EdgeInsets.all(16),
                border: Border.all(color: tokens.border, width: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'NAME',
                      style: AppTypography.caption(color: tokens.primary)
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                    ),
                    TextField(
                      key: const Key('profile-name-field'),
                      controller: name,
                      onChanged: (_) => setState(() => _nameError = null),
                      style: AppTypography.body(
                        color: tokens.ink,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        errorText: _nameError,
                        border: InputBorder.none,
                        isDense: true,
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: tokens.primary,
                          size: 20,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Divider(color: tokens.border, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'EMAIL ADDRESS',
                      style: AppTypography.caption(color: tokens.primary)
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                    ),
                    TextField(
                      key: const Key('profile-email-field'),
                      controller: email,
                      readOnly: true,
                      style: AppTypography.body(
                        color: tokens.inkMuted,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        prefixIcon: Icon(
                          Icons.mail_outline,
                          color: tokens.inkSubtle,
                          size: 20,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Integrations Settings Card (Google Calendar Sync) ───
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: Border.all(color: tokens.border, width: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'INTEGRATIONS',
                      style: AppTypography.caption(color: tokens.primary)
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          color: tokens.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync with Google Calendar',
                                style: AppTypography.body(color: tokens.ink)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Import planner events automatically',
                                style: AppTypography.caption(
                                  color: tokens.inkSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          key: const Key('profile-gcal-switch'),
                          value: appState.googleCalendarLinked,
                          activeThumbColor: tokens.primary,
                          onChanged: (value) {
                            ref
                                .read(appControllerProvider.notifier)
                                .toggleGoogleCalendar(value);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space5,
            0,
            AppSpacing.space5,
            AppSpacing.space4,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: tokens.inkSubtle,
                    side: BorderSide(color: tokens.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTypography.body().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    key: const Key('profile-save-button'),
                    onPressed: _saving ? null : _saveChanges,
                    child: Text(
                      _saving ? 'Saving…' : 'Save Changes',
                      style: AppTypography.body(
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Run widget test to verify it passes**

Run: `powershell -Command "Set-Location c:\Users\sukse\ConnectMeSS8; flutter test test/widget_test.dart --name 'EditProfileScreen displays stats, gcal sync switch, and handles layout updates'"`
Expected: PASS

- [ ] **Step 4: Run static analysis**

Run: `powershell -Command "Set-Location c:\Users\sukse\ConnectMeSS8; flutter analyze"`
Expected: No errors or warnings in modified files.

- [ ] **Step 5: Commit changes**

```bash
git add lib/src/features/edit_profile_screen.dart
git commit -m "feat(profile): enhance edit profile screen with quick stats, google calendar switch and bottom pinned actions"
```
