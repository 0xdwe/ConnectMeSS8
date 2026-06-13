# About Connect Me Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the settings "About Connect Me" section as a custom bottom sheet displaying actual v3/v4 feature highlights (AI updates, Bond Scoring, Firebase Sync, Smart Notifications).

**Architecture:** We will create a static configuration data file listing version updates. Then, we will build a custom modal bottom sheet widget using theme tokens (`tokens.aiGradient`, `tokens.surfaceSunken`, etc.) and wire it up to settings tab. Finally, we will write a comprehensive widget test.

**Tech Stack:** Flutter, Riverpod, Dart.

---

### Task 1: Create Static Configuration File

**Files:**
- Create: `lib/src/features/tabs/about_features.dart`

- [ ] **Step 1: Write static configuration data**

Create the file `lib/src/features/tabs/about_features.dart` with the following contents:

```dart
class AboutFeature {
  final String emoji;
  final String title;
  final String description;

  const AboutFeature({
    required this.emoji,
    required this.title,
    required this.description,
  });
}

const List<AboutFeature> kAboutFeatures = [
  AboutFeature(
    emoji: '🤖',
    title: 'AI Memory Updates',
    description: 'Generates deep Markdown memories summarizing contact histories, preferences, and key topics.',
  ),
  AboutFeature(
    emoji: '📈',
    title: 'Bond Score & Drift',
    description: 'Tracks relationship health (0–100) with Bond Rings and automatic cadence-based Bond Drift.',
  ),
  AboutFeature(
    emoji: '☁️',
    title: 'Firebase Cloud Sync',
    description: 'Full real-time sync of connections, interactions, events, and memories via Firebase Auth.',
  ),
  AboutFeature(
    emoji: '🔔',
    title: 'Smart Notifications',
    description: 'Durable notification settings for check-in suggestions, quiet hours, and planner lead times.',
  ),
  AboutFeature(
    emoji: '👤',
    title: 'Auth-Backed Profiles',
    description: 'Upload profile pictures to Firebase Storage and update your Auth display name.',
  ),
];
```

- [ ] **Step 2: Commit static configuration**

Run:
```bash
git add lib/src/features/tabs/about_features.dart
git commit -m "feat: add about features configuration"
```

---

### Task 2: Create About Modal Widget

**Files:**
- Create: `lib/src/features/modals/about_modal.dart`

- [ ] **Step 3: Implement AboutModal and showAboutBottomSheet**

Create the file `lib/src/features/modals/about_modal.dart` with the following contents:

```dart
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../tabs/about_features.dart';

Future<void> showAboutBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AboutModal(),
  );
}

class AboutModal extends StatelessWidget {
  const AboutModal({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          child: Material(
            color: tokens.surfaceSunken,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space2,
                AppSpacing.space4,
                AppSpacing.space6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.border,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.space4),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: tokens.aiGradient,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.primary.withValues(alpha: .24),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.diversity_3,
                        color: tokens.primaryOn,
                        size: 28,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.space3),
                  Center(
                    child: Text(
                      'Connect Me',
                      style: AppTypography.glyph(
                        24,
                        color: tokens.ink,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.space1),
                  Center(
                    child: Text(
                      'Version 3.0.0 (Build 42)',
                      style: AppTypography.caption(color: tokens.inkSubtle),
                    ),
                  ),
                  SizedBox(height: AppSpacing.space5),
                  Text(
                    "WHAT'S NEW IN V3",
                    style: AppTypography.caption(
                      color: tokens.inkSubtle,
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: AppSpacing.space3),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kAboutFeatures.length,
                      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.space3),
                      itemBuilder: (context, index) {
                        final feature = kAboutFeatures[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              child: Text(
                                feature.emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            SizedBox(width: AppSpacing.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feature.title,
                                    style: AppTypography.bodyLg(
                                      color: tokens.ink,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: AppSpacing.space1),
                                  Text(
                                    feature.description,
                                    style: AppTypography.caption(
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: AppSpacing.space6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Feedback features coming soon!'),
                                backgroundColor: tokens.primary,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.ink,
                            side: BorderSide(color: tokens.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Send Feedback',
                            style: AppTypography.body().copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.primary,
                            foregroundColor: tokens.primaryOn,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Done',
                            style: AppTypography.body().copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Commit AboutModal**

Run:
```bash
git add lib/src/features/modals/about_modal.dart
git commit -m "feat: implement AboutModal bottom sheet"
```

---

### Task 3: Integrate into Settings Tab

**Files:**
- Modify: `lib/src/features/tabs/settings_tab.dart`

- [ ] **Step 5: Import AboutModal and replace Alert dialog**

In `lib/src/features/tabs/settings_tab.dart`, add the following import:
```dart
import '../modals/about_modal.dart';
```

And replace the `CardBox` child at lines 131–138:
```dart
          child: _SettingsRow(
            icon: Icons.info_outline,
            iconColor: const Color(0xFF5B8DEF),
            label: 'About Connect Me',
            onTap: () => showAboutBottomSheet(context),
          ),
```

- [ ] **Step 6: Commit SettingsTab changes**

Run:
```bash
git add lib/src/features/tabs/settings_tab.dart
git commit -m "feat: wire AboutModal trigger to settings row"
```

---

### Task 4: Write Widget Test

**Files:**
- Create: `test/features/about_modal_test.dart`

- [ ] **Step 7: Implement AboutModal Widget Test**

Create `test/features/about_modal_test.dart` with the following contents:

```dart
import 'package:connect_me/src/features/tabs/settings_tab.dart';
import 'package:connect_me/src/features/modals/about_modal.dart';
import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_overrides.dart';

void main() {
  testWidgets('AboutModal slides up when row is tapped and displays key info', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedInDemoOverrides(),
          memoryStoreProvider.overrideWithValue(InMemoryMemoryStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.data(false),
          home: const Scaffold(body: SettingsTab()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap on the 'About Connect Me' settings row
    await tester.tap(find.text('About Connect Me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify modal elements are displayed
    expect(find.byType(AboutModal), findsOneWidget);
    expect(find.text('Connect Me'), findsWidgets);
    expect(find.text('Version 3.0.0 (Build 42)'), findsOneWidget);
    expect(find.text("WHAT'S NEW IN V3"), findsOneWidget);

    // Verify a sample feature highlight is listed
    expect(find.text('AI Memory Updates'), findsOneWidget);
    expect(
      find.text('Generates deep Markdown memories summarizing contact histories, preferences, and key topics.'),
      findsOneWidget,
    );

    // Verify buttons are present
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Send Feedback'), findsOneWidget);

    // Tap Done to close bottom sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Verify modal is closed
    expect(find.byType(AboutModal), findsNothing);
  });
}
```

- [ ] **Step 8: Run widget test**

Run:
```bash
flutter test test/features/about_modal_test.dart
```
Expected output: PASS

- [ ] **Step 9: Commit tests**

Run:
```bash
git add test/features/about_modal_test.dart
git commit -m "test: add AboutModal widget tests"
```
