# Architecture Review: Firebase Integration Compliance

**Reviewer angle:** Architecture compliance and missing Firebase integration
**Date:** 2026-05-16
**Scope:** Whether the current ConnectMe codebase satisfies the TA requirement of "integration of Flutter with Firebase services."

---

## TL;DR

ConnectMe is a **pure in-memory Flutter prototype with zero Firebase integration, by design.** Every architectural decision recorded in the repo (PRD, DESIGN, context, issue specs, dependency manifest) treats the backend as out of scope. There is no Firebase code, no Firebase config, no Firebase commit in history, and no other backend either. If the TAs require a Flutter + Firebase demo, **this project does not meet that requirement today** and cannot be demo'd as one without new work.

This is not a "rules violation" so much as a planning gap: the team explicitly chose mock-only and never planned the Firebase slice. The fix is additive, not corrective.

---

## Review

### Correct (what is already good)

- **State management is clean and well-isolated.** `lib/src/state/app_state.dart` centralizes everything in one `AppController extends Notifier<AppState>` with an immutable `AppState` container (lines 22-37) and `copyWith` (lines 252-279). Every mutation goes through controller methods like `addConnection`, `saveEvent`, `commitAiUpdate`. This is a friendly seam to slot a repository / Firestore layer behind without rewriting widgets.
- **AI service is already abstracted behind an interface.** `lib/src/ai/ai_update_service.dart:5-11` defines `abstract class AiUpdateService` and the controller depends on the interface via `aiUpdateServiceProvider` (`app_state.dart:6-8`). Swapping `MockAiUpdateService` for a real implementation (Firebase AI / Cloud Functions / Vertex AI) requires changing one provider line.
- **Auth flow is gated through the controller.** `auth_screen.dart` calls `ref.read(appControllerProvider.notifier).signIn()` / `signUp(...)` (lines 67, 99). A real Firebase Auth integration replaces the controller methods, not the screen.
- **Honest disclosure to test users.** `auth_screen.dart:189` displays "Prototype demo. No real backend or saved accounts." — the UI does not lie about the lack of persistence.
- **No half-finished Firebase code lying around.** Either you ship Firebase fully or you don't; there is no partial integration to untangle.

### Blocker — Firebase integration is entirely absent

Evidence (each item independently verified):

1. **State is in-memory only.** `AppState` lives inside a Riverpod `Notifier` and is rebuilt from `AppState.seeded()` on every `AppController.build()` (`app_state.dart:286`) and on every `signOut()` (`app_state.dart:298`). No persistence. Closing the app drops every user-created connection, event, and interaction. Signing out literally resets back to the seeded fixtures.
2. **AI is fake.** `MockAiUpdateService.categorizeAndUpdate` (`ai_update_service.dart:13-58`) is keyword matching on `input.toLowerCase()` (e.g. `lower.contains('birthday')`). No network call, no model, no backend. The class name is `Mock` and the only registered provider points at it (`app_state.dart:6-8`).
3. **Auth is mock.** Validation is `value.contains('@')` and `value.length < 6` (`auth_screen.dart:51-58`). Any valid-shaped credential succeeds. `signIn()` just sets `isAuthed: true` (`app_state.dart:289`); `signUp()` only writes the typed name/email into the in-memory user (`app_state.dart:290-298`). Nothing leaves the device.
4. **No Firebase config files anywhere.** `find` returns zero results for `firebase_options.dart`, `GoogleService-Info.plist`, and `google-services.json`. Android `app/` and iOS `Runner/` directories contain no Firebase plist/json.
5. **No Firebase dependencies.** `pubspec.yaml` lists `flutter_riverpod`, `go_router`, `google_fonts`, `intl`, `uuid`, `file_selector`, `cupertino_icons`, plus dev `flutter_test` and `flutter_lints`. No `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`. Also no alternate networking client (`http`, `dio`) — there is literally no way for the app to talk to any backend right now.
6. **No Firebase code in source.** Repo-wide grep for `firebase|firestore|FlutterFire|FirebaseAuth|cloud_firestore|firebase_auth|firebase_core` produces exactly two hits: `docs/prd/2026-05-15-mock-auth-form-prd.md:64` (which lists Firebase as **explicitly out of scope**) and `ios/Pods/SDWebImage/README.md` (third-party docs, irrelevant).
7. **No Firebase in git history.** 53 commits across all branches. `git log --all --oneline` shows no Firebase-related work in the project's lifetime — initial commit through the most recent `02b334d fix: prevent RenderFlex overflow`. The project has always been mock-only.
8. **Architecture docs do not assume Firebase.** `PRODUCT.md` describes the product behavior with no backend references. `DESIGN.md` is visual/styling only — zero hits for `backend|persist|database|api|server|cloud|firebase`. `context.md` describes state as "`flutter_riverpod` only. Single `AppController extends Notifier<AppState>`... `AppState` is a flat immutable container." No backend layer is described or implied.
9. **No ADRs.** `docs/` contains `issues/`, `prd/`, `superpowers/` — no `adr/` directory and no architecture decision records discussing backend choice. The only backend-adjacent decision is in the mock-auth PRD (`docs/prd/2026-05-15-mock-auth-form-prd.md`) which lists "Firebase, Supabase, OAuth, Apple login, Google login, or email verification" under **Out of Scope** (line 64).

### Note — Compliance gap and what it would take

If the TA bar is "integration of Flutter with Firebase services" (any non-trivial use), the minimum credible additions are roughly:

- **`firebase_core` bootstrap.** Add `firebase_core` to `pubspec.yaml`, run FlutterFire CLI to generate `lib/firebase_options.dart` plus platform configs (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`), and call `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` from `lib/main.dart` before `runApp`.
- **`firebase_auth` replacing the mock auth.** Replace `signIn()` / `signUp()` in `AppController` with `FirebaseAuth.instance.signInWithEmailAndPassword(...)` / `createUserWithEmailAndPassword(...)`. Auth state should drive `isAuthed` via `authStateChanges()` instead of being toggled by the screen. Drop the "Prototype demo. No real backend or saved accounts." line in `auth_screen.dart:189`.
- **`cloud_firestore` for at least one collection.** The obvious target is `connections` (per-user subcollection at `users/{uid}/connections`). Wire reads as a stream into a new `connectionsStreamProvider`, and route `addConnection` / `updateConnection` / `deleteConnection` writes through a `ConnectionsRepository` that calls Firestore. Events and interactions follow the same pattern.
- **Repository seam.** Today `AppController` mutates lists directly (e.g. `app_state.dart:325-336`). Insert a thin repository between controller and store so widgets keep working unchanged. The fact that all mutations already funnel through controller methods makes this a contained refactor rather than a rewrite.
- **Test updates.** Existing widget tests assume immediate, synchronous state changes. Firebase calls are async streams — tests will need a fake `FirebaseAuth` / `FirebaseFirestore` (e.g. `firebase_auth_mocks`, `fake_cloud_firestore`).

A scoped MVP — Firebase Auth on the auth screen plus Firestore-backed connections — is enough to demo "Flutter + Firebase integration" without touching events, interactions, or AI.

### Note — Risk assessment for demo

- **Cannot be demo'd as "Flutter + Firebase" today.** No code path touches Firebase. Showing the app to a TA and claiming Firebase integration would be inaccurate.
- **The codebase is in good shape to add it.** Clean controller seam, abstracted AI service, single source of state truth, no contradictory persistence (e.g. nobody is half-using `shared_preferences`). A Firebase slice is additive work, not a rescue.
- **Effort estimate is real.** Auth swap alone is small (a day or two), but full credible integration with Firestore-backed connections, async stream wiring, and updated tests is more like a week of focused work given the scope of state currently in `AppState`.
- **Watch out for the `signOut()` reset.** `app_state.dart:298` returns `AppState.seeded()` — once Firebase is wired, sign-out must not clobber the user's real data. This line will need to become a true logout that clears auth and resets local cache without re-seeding fixtures.
- **Check intent before acting.** The PRD explicitly excludes Firebase. If TA requirements have shifted under the team's feet, document the new requirement before changing PRDs/issues, otherwise this turns into scope creep that contradicts the recorded plan.

### Note — Honest framing

The team did not "violate the rules"; they followed a documented plan that excluded Firebase. The rules — if "integration of Flutter with Firebase services" really is a hard TA requirement — were never adopted into this project's planning artifacts. Two reasonable reads:

1. **TA requirement was always there and was missed in planning.** Then this is a planning failure that the team needs to recover from with a Firebase slice before the demo.
2. **TA requirement was added or clarified late.** Then the PRD's "Out of Scope" line is now stale and should be updated alongside new issue tickets describing the Firebase integration slice.

Either way, the corrective action is the same: add a Firebase integration. The code is well-positioned to receive it. The disagreement to surface to the team is **whether to keep mock auth and add Firestore for data only, or replace mock auth wholesale with Firebase Auth**. Picking one keeps the slice minimal; picking both is the credible "Flutter + Firebase" demo.
