# About Connect Me Redesign Spec

Redesign the "About Connect Me" settings row to show a rich bottom sheet display (Option A) summarizing the latest app updates, replacing the simple native alert dialog.

## Goal
Make the "About Connect Me" section of settings feel premium and detailed. Instead of a basic alert dialog, show an interactive bottom sheet containing branding, version data, and a list of version updates that match actual recent app enhancements (AI Updates, Bond Scoring, Firebase Syncing, Smart Notifications).

---

## Design Spec (Option A)
The redesigned layout will display a modal bottom sheet:
- **Top Handle Bar**: A standard centered rounded indicator bar.
- **Header Section**:
  - A stylized app icon container with a custom linear gradient background (`tokens.aiGradient`).
  - An icon inside the logo container (`Icons.diversity_3` or similar relationships symbol).
  - App Name: "Connect Me" (`AppTypography.h1` style).
  - Version & Build details: "Version 3.0.0 (Build 42)".
- **Features / Updates Section**:
  - Section Title: "What's New in v3" (`AppTypography.caption` with bold/uppercase letter spacing).
  - A scrollable list of key updates. Each update consists of:
    - An Emoji or bullet icon.
    - A bold title (`AppTypography.bodyLg` weight).
    - A descriptive caption (`AppTypography.caption` in `tokens.inkMuted`).
- **Footer Buttons**:
  - A primary **Done** button (`AppTypography.body` in `tokens.primary` / `tokens.primaryOn` container).
  - A secondary **Send Feedback** button (opens email client or logs feedback, styled with standard button outline).

---

## Proposed Changes

### Modals & Screens

#### [NEW] [about_modal.dart](file:///c:/Users/sukse/ConnectMeSS8/lib/src/features/modals/about_modal.dart)
- Create `showAboutBottomSheet(BuildContext context)` helper.
- Build `AboutModal` widget class.
- Structure it as a `SafeArea` with a `Column` containing:
  - A drag handle container.
  - Header branding elements.
  - A `Flexible` or `ListView` showing the features array.
  - Footer buttons.

#### [NEW] [about_features.dart](file:///c:/Users/sukse/ConnectMeSS8/lib/src/features/tabs/about_features.dart)
- Store static lists of features for clean code isolation:
  ```dart
  class AboutFeature {
    final String emoji;
    final String title;
    final String description;
    const AboutFeature({required this.emoji, required this.title, required this.description});
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

#### [MODIFY] [settings_tab.dart](file:///c:/Users/sukse/ConnectMeSS8/lib/src/features/tabs/settings_tab.dart)
- Replace `onTap: () => _info(context, 'Connect Me v3.0\nMaking relationships matter')` with `onTap: () => showAboutBottomSheet(context)`.

---

## Verification Plan

### Automated Tests
- Create a new test under `test/features/about_modal_test.dart` to verify:
  - Bottom sheet triggers and mounts successfully.
  - Features list matches `kAboutFeatures`.
  - Buttons (Done, Send Feedback) are visible.
  - Tap event triggers are responsive.
