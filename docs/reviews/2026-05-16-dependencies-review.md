# Dependencies and External Services Review

**Scope:** Verify that the repo conforms to the TA constraint of "Flutter + Firebase only" — i.e., no prohibited external services, backends, or non-Firebase cloud SDKs.

**Method:** Inspected `pubspec.yaml`, `pubspec.lock`, all Dart imports under `lib/` and `test/`, native Android/iOS configs, repo-level dotfiles, and project markdown docs. Reviewed recent git history (last 30 commits) and the current working tree diff.

> Note: A `plan.md` was referenced in the task but does not exist in the repo. `progress.md` was read.

---

## Review

### Correct (already conformant)

- **No prohibited HTTP/RPC clients are declared as direct deps.** `pubspec.yaml` direct dependencies are: `flutter`, `cupertino_icons`, `flutter_riverpod`, `go_router`, `google_fonts`, `intl`, `uuid`, `file_selector`. None are HTTP clients, GraphQL clients, ORMs, or non-Firebase cloud SDKs. Evidence: `pubspec.yaml:30-37`.
- **No non-Firebase cloud SDKs anywhere.** No occurrences of AWS/Amplify, Azure, GCP, Supabase, Postgres, MySQL, or Mongo in any Dart source, native config, or lockfile. Evidence: grep across `lib/`, `test/`, `pubspec.lock`, `android/`, `ios/Runner` returned nothing.
- **No real network calls in app code.** Searched `lib/` for `http`, `https://`, `HttpClient`, `Socket`, `websocket`, `fetch(` — zero matches. The "AI" path is a local mock: `lib/src/ai/ai_update_service.dart` defines `MockAiUpdateService` (purely synchronous string parsing), wired in `lib/src/state/app_state.dart` via `const MockAiUpdateService()`.
- **`http` is transitive only, via the test toolchain.** `pubspec.lock` lists `http` with `dependency: transitive` (pulled in by `package:test` / `shelf`). It is not imported anywhere in `lib/` or `test/`. Acceptable: dev-only.
- **No backend config files.** No `.env`, `.env.*`, `docker-compose*`, `Dockerfile`, `serverless.yml`, `*.tf`, API gateway specs, or server source trees in the repo.
- **No Firebase config artifacts on disk.** No `google-services.json`, no `GoogleService-Info.plist`, no `firebase.json`, no `.firebaserc`. Native build files (`android/app/build.gradle.kts`, iOS `Podfile.lock`) reference no Firebase plugins. (See "Note" below — this is consistent with the prototype intent but worth confirming against the TA's interpretation of "Firebase only.")
- **Docs explicitly affirm prototype/no-backend intent.** Multiple PRDs and issue specs state this is mock-only with no real backend, no real AI, no Firebase, no Supabase, and no persistence beyond local state. Evidence:
  - `docs/prd/2026-05-15-mock-auth-form-prd.md:64` "Firebase, Supabase, OAuth, Apple login, Google login, or email verification" listed as out of scope.
  - `docs/prd/2026-05-15-update-with-ai-single-flow-prd.md:49` excludes "upload to a backend".
  - `docs/prd/2026-05-15-ui-polish-and-design-system-prd.md:106` "Real backend, real AI, real persistence. The MockAiUpdateService stays."
  - `docs/superpowers/plans/2026-05-02-contact-ai-insights.md:7` "Keep current Riverpod/local mock architecture; no backend or real AI API."
- **Recent commits do not introduce backend infrastructure.** Last 30 commits are all UI, design tokens, animation, accessibility, and a local query-providers performance optimization. The current working-tree diff (`git status`) modifies only screen/tab Dart files and adds a local-only `query_providers.dart` plus its test.
- **`progress.md` is appropriate for a scratch/memory file.** Tracks the last completed issue (#022 stagger animation). It is not committed (untracked per `git status`); `.gitignore` does not currently list it but the working rules permit untracked progress files in coding repos. Not a violation of the dependency rule.

### Note (observations / risks, not violations)

- **`google_fonts: ^8.1.0` performs a runtime HTTPS fetch to `fonts.gstatic.com`** to download font files on first use, then caches them locally. This is a standard Flutter package, not a backend integration, and it does not transmit project data. It is almost certainly inside the spirit of "Flutter only" — the TAs allow standard Flutter packages — but it is technically an outbound network call to a Google CDN. If the assignment is read strictly as "no network calls except Firebase," this is the only borderline case. Two non-destructive mitigations if the TAs object:
  - Bundle the Inter font files as assets and use `Theme`/`TextTheme` directly (drop `google_fonts`); or
  - Pass `GoogleFonts.config.allowRuntimeFetching = false` and ship pre-downloaded font files in `assets/fonts/` per the `google_fonts` package's offline guidance.
  - Recommended action: **keep as-is** unless the TAs flag it. Document the runtime fetch in the README if you want to be explicit.
- **`file_selector: ^1.1.0` is a local OS file-picker plugin**, not a network/cloud client. Used only at `lib/src/features/ai_update_screen.dart:3` to attach images in the mock AI flow. No upload occurs — files are referenced as `AttachmentRef`s held in local state. Acceptable.
- **No Firebase is wired up.** The TA constraint "Flutter + Firebase only" is permissive ("the only allowed external service is Firebase") rather than prescriptive ("you must use Firebase"). The product is currently a pure-local prototype, which the PRDs document as intentional. If the assignment actually requires Firebase to be present (e.g., Auth or Firestore must be demonstrated), this repo does not meet that bar — every PRD explicitly excludes it. Worth confirming the TA expectation; if Firebase is required, the auth and persistence layers would need to be re-scoped. **No code change recommended from a "prohibited dependency" angle** — only a scope/requirements check.
- **`uuid` and `intl`** are pure-Dart utility packages (ID generation, locale formatting). Not external services. Acceptable.
- **`flutter_riverpod` and `go_router`** are local state and routing. No external services. Acceptable.

### Fixed

- None. This is a review-only pass; no edits were made.

### Blocker

- None found from the "prohibited dependencies and external services" angle. The repo is clean: no HTTP clients, no GraphQL, no non-Firebase cloud SDKs, no server/infra config, no committed secrets, and no recent commits introducing backend code.

---

## Summary

From a "Flutter + Firebase only" enforcement standpoint, the codebase is in good shape: every direct dependency is a standard Flutter/Dart package, the AI flow is a deterministic local mock, and there is no networking or persistence layer beyond Riverpod in-memory state. The only items worth flagging at all are (1) `google_fonts` runtime CDN fetch, which is conventional and almost certainly fine, and (2) the absence of Firebase itself, which is a scope question for the TAs rather than a dependency violation.
