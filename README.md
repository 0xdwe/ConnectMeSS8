# ConnectMe

<p align="center">
  <img src="assets/images/update_budi_mascot.png" alt="ConnectMe Mascot" width="120" />
</p>

<p align="center">
  <b>A thoughtful personal CRM that does the remembering for you, then nudges gently.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Gemini_API-blue?style=flat&logo=google-gemini&logoColor=white" alt="Gemini API" />
  <img src="https://img.shields.io/badge/ADHD--Friendly-warmgreen?style=flat" alt="ADHD-Friendly" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg?style=flat" alt="License" />
</p>

---

## 🌟 What is ConnectMe?

**ConnectMe** is an open-source, empathy-driven personal CRM designed to bridge the gap in our working memory. It is built for:
- **Busy professionals** who feel quiet guilt about losing touch with friends and family.
- **People with ADHD or working memory differences** who need external systems to hold relationship state, without the anxiety of streaks, notifications, or performance grades.

Unlike corporate CRMs (like Salesforce or HubSpot) that treat relationships as sales pipelines, **ConnectMe** focuses on the human element. Success is simple: *open the app, remember a friend, send a genuine message, and close the app.*

---

## 🚀 Key Features

### ⭕ Interactive Bond Rings
Avatars are wrapped in dynamic, tier-colored rings representing relationship strength based on the contact’s **Bond Score (0–100)**:
- **Close** (80–100) — Tinted in brand purple.
- **Steady** (50–79) — Neutral slate.
- **Drifting** (0–49) — Soft warning orange.
*A small, subtle trend arrow indicators show if the bond is trending up (recently connected) or drifting down.*

### ✨ Update with AI (Powered by Google Gemini)
Type a quick diary-like note or paste a chat log directly into the free-text input. Using the **Firebase Gen AI SDK (Gemini)**, ConnectMe:
1. Automatically parses the input into structured timeline events (`CrmInteraction`).
2. Extracts updated preference facts, contact details, and upcoming events.
3. Computes a diminishing-returns `bondScore` bump.
4. Generates a markdown preview for you to verify and approve before anything is committed to database.

### 📝 Per-Contact Memory Dossiers
Each contact maintains a structured `MemoryDocument` (markdown narrative with YAML frontmatter) containing:
- **Summary & Preferences**: Important details like favorite foods, allergies, or spouse's name.
- **Interaction History**: A timeline of atomic events (e.g., "had coffee on Tuesday").
- **AI-Driven Topics & Conversation Starters**: Gemini-enriched, context-aware prompts to help kick off your next conversation.

### 📅 Smart Recommendations & Unified Planner
- **Nudge-based Recommendations**: The home screen surfaces cards for drifting contacts or upcoming events. It is a pure, side-effect-free ranking function based on a derived **Maintenance Need** score.
- **Unified Planner**: A lightweight calendar for scheduling future interactions (coffee, call, birthday) with automatic timezone-aware notifications.

---

## 🧠 Core Philosophy & Anti-Shame Design

ConnectMe is built on a foundation of compassionate product design:
1. **Never Shame the User**: No "you haven't contacted Sarah in 47 days" pressure. No red overdue badges. Warnings are soft and encouraging (e.g., *"Sarah could use a check-in"*).
2. **Predictable Cadence**: ADHD users suffer from surprise popups and destructive state changes. ConnectMe requires explicit confirmations and offers an **Undo** capability on all major timeline actions (such as deleting an interaction log).
3. **AI as an Assistant, Not a Stand-in**: AI does not write messages for you, speak in a synthetic assistant persona, or silently mutate your data. It only structures details you provide, showing a confirmation card first.
4. **Privacy-First Graph**: All relationship data, interaction history, and memory documents are locked behind Firebase Auth, stored in subcollections matching your secure UID, and isolated end-to-end.

---

## 🛠️ Tech Stack & Architecture

ConnectMe is built with a highly decoupled, test-driven architecture:

- **Frontend**: Written in [Flutter](https://flutter.dev) using [Riverpod](https://riverpod.dev) for state management and [GoRouter](https://pub.dev/packages/go_router) for deep-linked navigation.
- **Database & Storage**: Backed by [Cloud Firestore](https://firebase.google.com/docs/firestore) and [Firebase Storage](https://firebase.google.com/docs/storage) (for user avatars).
- **Authentication**: Secure sign-in via [Firebase Auth](https://firebase.google.com/docs/auth).
- **AI/LLM**: Integrates Gemini Developer APIs using the `firebase_ai` package.
- **Architectural Seams (Adapters)**:
  ConnectMe employs decoupled store patterns (`MemoryStore`, `ConnectionStore`, `InteractionStore`, `EventStore`, `NotificationGateway`). Each seam has:
  - An **InMemory adapter** (allowing fast, headless unit tests to run without initializing Firebase SDKs).
  - A **Firebase adapter** (connecting to the live Cloud Firestore backend or local Firebase Emulator).
  - Multi-store mutations are executed atomically via the `BatchedWrites` seam.

---

## 📂 Developer Guide & Repository Layout

Six files at the project root are the canonical living docs. Refer to these files for detailed architecture, design decisions, and domain glossaries:

- [AGENTS.md](file:///Users/jamesli/Document/VSC/Coursework/SoftwareStudio/ConnectMe/AGENTS.md) — Onboarding guide for AI coding assistants.
- [CONTEXT.md](file:///Users/jamesli/Document/VSC/Coursework/SoftwareStudio/ConnectMe/CONTEXT.md) — Core domain glossary, named seams, and source-of-truth contracts.
- [PRODUCT.md](file:///Users/jamesli/Document/VSC/Coursework/SoftwareStudio/ConnectMe/PRODUCT.md) — Target audiences, product principles, and brand guidelines.
- [DESIGN.md](file:///Users/jamesli/Document/VSC/Coursework/SoftwareStudio/ConnectMe/DESIGN.md) — Visual system tokens, typography scales, color rules, and motions.
- [progress.md](file:///Users/jamesli/Document/VSC/Coursework/SoftwareStudio/ConnectMe/progress.md) — Active session-by-session worklog and status indicator.

### `docs/` Directory Structure

```text
docs/
  adr/        # Architecture Decision Records (cross-pass decisions, numbered)
  prd/        # Product Requirement Documents, one per feature
  issues/     # Atomic issue specs (numbered, kebab-case)
  reviews/    # Subagent reviews, audits, and research output (dated)
  context/    # Per-task agent scratchpads (dated)
  operations/ # Ops runbooks (rules deploy, etc.)
  archive/    # Superseded snapshots and per-task closeouts (dated)
```

---

## 🏁 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (matching the environment version in `pubspec.yaml`)
- [Firebase CLI](https://firebase.google.com/docs/cli) (for running local rules testing and emulator setups)
- JDK 21+ (required for Firestore Emulator rules tests)

### Local Configuration
To run against your own Firebase instance:
1. Initialize a new Firebase Project.
2. Enable **Firestore Database**, **Authentication** (Email/Google), **Storage**, and **Firebase App Check**.
3. Generate your `firebase_options.dart` configuration using the FlutterFire CLI:
   ```bash
   flutterfire configure
   ```

### Running the App
For local development:
```bash
flutter pub get
flutter run
```

### Running Tests
To run targeted unit and state tests:
```bash
# Run state and engine tests
flutter test test/state/
flutter test test/state/connections/

# Run specific widget tests
flutter test test/features/activity_log_delete_test.dart
```

To run security rules tests in the Firebase Emulator:
```bash
cd firestore
firebase emulators:exec --only firestore,storage --project demo-test "npm test"
```

---

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:
1. **Branch naming**: Use `feat/<issue-number>-<title>` or `fix/<topic>`.
2. **Strict TDD**: Write failing unit or widget tests before writing implementation code.
3. **Preserve Seams**: Ensure you implement both `InMemory` and `Firebase` adapters when introducing new stores.
4. **Code Quality**: Follow dart rules in `analysis_options.yaml` and ensure targeted tests pass before submitting.

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
