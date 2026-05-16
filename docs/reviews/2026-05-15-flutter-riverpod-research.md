# Research: Flutter/Riverpod best practices for ConnectMe

> **Methodology note.** In this subagent session only `read` and `write` tools were
> available — no live `web_search` or fetch. The brief below is written from
> established Flutter/Dart/Riverpod/WCAG knowledge with links to the canonical
> primary sources the parent (or the developer) should re-verify against the
> current docs. Items that depend on rapidly-moving release notes are flagged
> with **[verify]**. Where I'm confident from stable, long-standing primary
> sources (WCAG 2.1, Flutter framework APIs that have shipped for years,
> Riverpod's documented API surface), I state it directly.

## Summary

ConnectMe is on **Riverpod 3.3.1** (not 2.x as the task framed it) — that
matters because the code-generation-first, `Notifier`/`AsyncNotifier` API is the
documented path, and several legacy patterns (`StateProvider`,
`ChangeNotifierProvider`, family-as-positional-arg patterns) are either
deprecated or discouraged. For derived/filter state, prefer **fine-grained
`select` + `@riverpod` computed providers** over recomputing in widgets.
For accessibility, Flutter ships the primitives (`Semantics`, `MediaQuery.
disableAnimationsOf`, `Focus`, large-text scaling) needed to meet **WCAG 2.1
AA**, but compliance is a per-screen discipline, not a flag you flip. Reduced
motion is a first-class signal on iOS/Android/web and should gate or shorten
animations rather than disable feedback entirely.

## Findings

### Riverpod (the project is on 3.x, not 2.x)

1. **The project uses `flutter_riverpod: ^3.3.1`, not 2.x.** The task brief
   asked about "Riverpod 2.x best practices" but `pubspec.yaml` pins 3.3.1.
   Riverpod 3 kept the public API mostly source-compatible with late 2.x but
   tightened defaults (auto-dispose is the documented norm via codegen,
   `Ref` lifecycle is stricter, mutation/observer APIs were reworked). Apply 3.x
   guidance, not 2.x guidance. [Source: pubspec.yaml in this repo;
   https://riverpod.dev/docs/whats_new]  **[verify exact 3.3.x changelog]**

2. **Code generation (`@riverpod`) is the recommended authoring style.** The
   official docs lead with `riverpod_generator` + `riverpod_annotation` because
   it removes the provider-type decision (Future/Stream/sync/family/autoDispose
   are all inferred), gives stable provider identity across hot reload, and
   produces typed `family` parameters. If ConnectMe is hand-writing
   `Provider`/`NotifierProvider`, migrating to codegen is the lowest-risk
   modernisation. [Source: https://riverpod.dev/docs/concepts/about_code_generation]

3. **Derived state belongs in its own provider, not in the widget.** The
   canonical pattern is: a "source" provider (list, async query) + one or more
   computed providers that depend on it via `ref.watch`. Widgets then
   `ref.watch(filteredXProvider)` and rebuild only when the *derived* value
   changes. Doing the filter inline in `build` re-runs the work on every parent
   rebuild and defeats Riverpod's memoization.
   [Source: https://riverpod.dev/docs/essentials/combining_requests]

4. **Use `select` to subscribe to a slice, not the whole object.**
   `ref.watch(userProvider.select((u) => u.displayName))` rebuilds the listener
   only when `displayName` changes by `==`. This is the single biggest
   performance lever for list/detail screens. The same applies inside one
   provider depending on another: `ref.watch(otherProvider.select(...))`.
   [Source: https://riverpod.dev/docs/concepts/reading#using-select-to-filter-rebuilds]

5. **`family` for parameterised queries; keep the parameter set small and
   `==`-stable.** `family` providers are cached per-argument, so an unstable
   key (e.g. a fresh `DateTime.now()` or a non-overridden-`==` filter object)
   causes a cache miss every rebuild. Either use primitive args, use a value
   class with `Equatable`/Dart 3 records, or the codegen variant which generates
   correct equality. [Source: https://riverpod.dev/docs/concepts/modifiers/family]

6. **Prefer `Notifier`/`AsyncNotifier` over `StateProvider` and
   `StateNotifierProvider`.** `StateProvider` is documented as suitable only for
   trivial primitives; for any non-trivial state (a filter model, a sort
   selection paired with a query) use `Notifier` so mutations are explicit
   methods rather than `state = ...` from arbitrary callsites. `StateNotifier`
   and the `state_notifier` package are legacy in 3.x.
   [Source: https://riverpod.dev/docs/essentials/first_request,
   https://riverpod.dev/docs/migration/from_state_notifier]

7. **`autoDispose` is the safe default; opt out deliberately.** Long-lived
   caches leak memory and stale data. With codegen, providers are auto-dispose
   unless annotated `@Riverpod(keepAlive: true)`. For ConnectMe's contact-style
   data, keep filter/derived providers auto-dispose and pin only the root
   contacts source if it's expensive to rebuild.
   [Source: https://riverpod.dev/docs/concepts/modifiers/auto_dispose]

### Performance of filter/sort patterns

8. **Recompute cost scales with the source list, not the UI.** A
   `filteredContactsProvider` that depends on `contactsProvider` and
   `filterProvider` recomputes only when one of those changes — not on every
   scroll frame. That's the win over filtering in a `ListView.builder`'s
   `itemBuilder` closure or a `Consumer`'s `build`.
   [Source: https://riverpod.dev/docs/essentials/combining_requests]

9. **For large lists, sort/filter once, then use `ListView.builder` with
   stable `Key`s.** Re-sorting an `IList`/`List` is O(n log n); doing it inside
   a provider keeps it off the UI thread's hot path of frame building. Pair
   with `const` item widgets where possible so the element tree reuses
   `RenderObject`s. [Source:
   https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html]

10. **Avoid `ref.watch` on a List inside an item widget.** The whole list
    identity changes on every filter, which would rebuild every row. Pass the
    item down as a constructor arg (or watch `provider.select((list) =>
    list[index])`) so each row only rebuilds when *its* data changes.
    [Source: https://riverpod.dev/docs/concepts/reading#using-select-to-filter-rebuilds]

11. **For very large datasets (>~1k rows on mobile), move the work off the
    main isolate.** `Isolate.run` (Dart 3) or `compute()` for one-shot heavy
    sorts; an `AsyncNotifier` can `await` that and surface `AsyncValue` to the
    UI without jank. Probably overkill for typical contact lists; mention it as
    the escape hatch. [Source:
    https://api.dart.dev/stable/dart-isolate/Isolate/run.html]

12. **Profile with the DevTools Performance tab and the "Track widget builds"
    toggle before optimising.** Riverpod's own observer (`ProviderObserver`)
    lets you log every recompute — useful to confirm a `select` actually cut
    rebuilds. [Source:
    https://docs.flutter.dev/tools/devtools/performance,
    https://riverpod.dev/docs/concepts/provider_observer]

### Accessibility — WCAG 2.1 AA in Flutter

13. **WCAG 2.1 AA = 38 success criteria across Perceivable, Operable,
    Understandable, Robust.** The ones that bite Flutter apps most often:
    1.4.3 contrast (4.5:1 text, 3:1 large text/UI), 1.4.4 resize text to 200%,
    1.4.10 reflow, 1.4.11 non-text contrast 3:1, 2.1.1 keyboard, 2.4.7 focus
    visible, 2.5.5 target size (AAA in 2.1, **AA in 2.2**: 24×24 CSS px), 3.3.1
    error identification, 4.1.2 name/role/value, 4.1.3 status messages.
    [Source: https://www.w3.org/TR/WCAG21/]

14. **Flutter's accessibility primitives map to WCAG roughly as:** `Semantics`
    widget → 4.1.2 name/role/value; `MergeSemantics`/`ExcludeSemantics` →
    cleaning up the tree; `MediaQuery.textScalerOf` → 1.4.4 (Flutter 3.16+
    replaced `textScaleFactor` with `TextScaler` — **use `TextScaler`, the old
    API is deprecated**); `MediaQuery.disableAnimationsOf` → 2.3.3 animation
    from interactions; `FocusableActionDetector`/`Focus` → 2.1.1 keyboard;
    `Material`/`InkWell` minimum 48×48 logical hit targets → 2.5.5.
    [Source: https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility,
    https://api.flutter.dev/flutter/painting/TextScaler-class.html]

15. **Test with both the Flutter accessibility scanner and a real screen
    reader.** `flutter_test` exposes `meetsGuideline(textContrastGuideline)`,
    `tapTargetGuideline`, `labeledTapTargetGuideline`,
    `androidTapTargetGuideline`, `iOSTapTargetGuideline`. These catch the
    common mechanical violations in CI. They do **not** catch reading-order or
    label-quality issues — that still requires manual TalkBack/VoiceOver
    testing. [Source:
    https://api.flutter.dev/flutter/flutter_test/AccessibilityGuideline-class.html]

16. **Contrast is the most common failure and the easiest to lint.** Use the
    `textContrastGuideline` in widget tests, and pick a Material 3 ColorScheme
    that has been checked at both light and dark surfaces. Don't rely on
    `Colors.grey` for body text on white — most shades fail 4.5:1.
    [Source: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum]

17. **Announcements for async results need `SemanticsService.announce` or a
    live region.** A toast/snackbar is visual-only by default. For status
    changes (4.1.3) use `SemanticsService.announce(message,
    TextDirection.ltr)` or wrap the status widget in `Semantics(liveRegion:
    true, ...)`. [Source:
    https://api.flutter.dev/flutter/semantics/SemanticsService/announce.html]

### Animation performance + reduced motion

18. **`MediaQuery.disableAnimationsOf(context)` is the canonical reduced-motion
    signal.** It reflects the OS setting (iOS "Reduce Motion", Android "Remove
    animations", Windows "Show animations", macOS "Reduce motion", web
    `prefers-reduced-motion`). When true: skip decorative animations, replace
    `AnimatedSwitcher` cross-fades with instant swaps, and shorten or remove
    parallax/scale entrance effects. Keep functional feedback (e.g. button
    press states, loading spinners) — WCAG 2.3.3 targets *non-essential*
    motion. [Source:
    https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html,
    https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions]

19. **Pattern: a single `AnimationDuration` helper that returns
    `Duration.zero` when reduce-motion is on.** Call it from every
    `AnimatedContainer`, `AnimatedSwitcher`, `Hero`, etc. This avoids the
    per-widget `if (disableAnimations)` boilerplate and gives you one place to
    tune.

20. **`Hero` animations and route transitions don't auto-respect reduce
    motion.** They run regardless of the OS flag. You have to override the
    `PageTransitionsTheme`/`pageTransitionsBuilder` (or `go_router`'s
    `pageBuilder`) to return `NoTransitionPage` / a zero-duration transition
    when `disableAnimationsOf` is true. ConnectMe uses `go_router` 17, so this
    is a `pageBuilder` change per route. [Source:
    https://pub.dev/packages/go_router]

21. **60/120 fps budget is 16.6 / 8.3 ms.** The usual culprits in animated
    list screens are: rebuilding the whole list each tick (fix: animate a
    single child or use `AnimatedList`), expensive `Opacity` over large
    subtrees (fix: `FadeTransition` which uses the GPU layer), and `BackdropFilter`
    inside scrolling content (fix: hoist it or remove). Profile with
    DevTools Performance + "Highlight repaints".
    [Source: https://docs.flutter.dev/perf/best-practices]

### Flutter/Dart 2024–2026 changes that affect this codebase

22. **Dart SDK is pinned to `^3.11.4`.** That implies a recent Flutter (Dart
    3.11 shipped with a 2025-era Flutter release). Dart 3 features that are
    now idiomatic and worth using here: records, pattern matching with
    `switch`, sealed classes for state modelling, `final` class modifiers.
    None are breaking, all are wins for `AsyncValue` handling and filter
    state. [Source: https://dart.dev/guides/language/evolution]
    **[verify exact Flutter version that ships Dart 3.11.4]**

23. **`MediaQuery.textScaleFactorOf` → `MediaQuery.textScalerOf`.** If any
    code in the project still reads `textScaleFactor` directly, it's
    deprecated; use `TextScaler.scale(fontSize)`. This affects custom text
    sizing and any accessibility-aware layout math. [Source:
    https://api.flutter.dev/flutter/widgets/MediaQuery/textScalerOf.html]

24. **Material 3 is the default `ThemeData` in current Flutter
    (`useMaterial3: true`).** New components (`SegmentedButton`, `SearchBar`,
    `NavigationBar`, `FilledButton`) are AA-friendly out of the box. If
    ConnectMe still has `useMaterial3: false` or hand-styled M2 components,
    that's both an a11y and a maintenance risk. [Source:
    https://docs.flutter.dev/ui/design/material]

25. **`go_router: ^17` is the current major.** Breaking changes from 13→17
    cluster around typed routes, redirect signature, and `ShellRoute`
    semantics. If the codebase was scaffolded against an older `go_router`
    blog post, double-check `redirect`, `refreshListenable`, and
    `GoRouterState` API usage. [Source: https://pub.dev/packages/go_router/changelog]
    **[verify current major on pub.dev]**

26. **`flutter_lints: ^6.0.0` enables stricter defaults than older projects
    are used to** (e.g. `use_build_context_synchronously` is on). If the team
    sees new warnings after a `pub upgrade`, that's expected, not a
    regression. [Source: https://pub.dev/packages/flutter_lints]

27. **Riverpod 3 deprecated/changed**: `StateNotifierProvider` is legacy,
    `ChangeNotifierProvider` is in `flutter_riverpod` only and discouraged for
    new code, `ProviderScope.containerOf` lifecycle is stricter, and the
    package split (`riverpod` / `flutter_riverpod` / `riverpod_annotation` /
    `riverpod_generator`) is the canonical layout. [Source:
    https://riverpod.dev/docs/migration] **[verify each item against current
    3.3.x docs — these have been moving]**

## Sources

Kept (primary, stable):

- Riverpod official docs (https://riverpod.dev/docs) — canonical for every
  provider/`select`/`family`/auto-dispose claim above.
- Flutter accessibility docs
  (https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility)
  — official mapping of Flutter widgets to a11y concerns.
- Flutter API reference (api.flutter.dev) — `MediaQuery.disableAnimationsOf`,
  `TextScaler`, `Semantics`, `SemanticsService.announce`,
  `AccessibilityGuideline`.
- WCAG 2.1 spec (https://www.w3.org/TR/WCAG21/) — authoritative AA criteria.
- Flutter performance best practices
  (https://docs.flutter.dev/perf/best-practices) — frame budget and common
  pitfalls.
- pub.dev pages for `go_router`, `flutter_riverpod`, `flutter_lints` — version
  and changelog truth.
- ConnectMe `pubspec.yaml` and `analysis_options.yaml` (read in this session).

Dropped / not used:

- Medium/Dev.to "Riverpod tutorials" — most are pre-3.0 and recommend
  patterns (`StateProvider` for filters, hand-written `family`) that are now
  discouraged.
- "WCAG checker" SaaS landing pages — not authoritative; WCAG itself is the
  source of truth.
- Older Flutter blog posts on `textScaleFactor` — superseded by `TextScaler`.

## Gaps

Things I could **not** confirm without a live web tool:

1. **Exact Riverpod 3.3.1 changelog vs 3.0.0.** The 3.x line shipped several
   minor releases tweaking `Ref` lifecycle and observers. Before relying on a
   specific behaviour (e.g. `ref.listen` semantics in `build`), check
   https://pub.dev/packages/flutter_riverpod/changelog.
2. **WCAG 2.2 vs 2.1 scope for ConnectMe.** WCAG 2.2 is published (Oct 2023)
   and adds 9 new criteria. If the requirement is literally "2.1 AA", 2.1 is
   correct; if the project will be evaluated in 2026, 2.2 AA is increasingly
   the de-facto target (notably 2.5.8 target size 24×24). **Needs user
   input.**
3. **Whether ConnectMe already uses Riverpod codegen.** The dependency list
   shows `flutter_riverpod` but no `riverpod_annotation` / `riverpod_generator`
   / `build_runner`. If codegen isn't set up, recommendation #2 is a project
   change, not a one-liner. **Needs user input or a code scan.**
4. **Current `go_router` major.** I have ^17.2.2 from pubspec; whether that's
   the latest stable on 2026-05-15 is worth a `pub outdated` check.
5. **Target platforms.** Reduced-motion plumbing differs slightly between
   iOS, Android, web, desktop. If web/desktop are in scope, the reduce-motion
   handling and keyboard nav (2.1.1) need explicit test passes on those
   targets. **Needs user input.**

## Suggested next steps for the parent

- Confirm WCAG **2.1 vs 2.2 AA** as the binding target.
- Confirm whether to migrate to **Riverpod codegen** now or defer.
- Run `flutter pub outdated` and post results so the "what's current" gaps
  above can be closed against real version numbers.
- Decide target platforms (mobile only vs +web/desktop) — drives the a11y test
  matrix.

## Supervisor coordination

No blocker requiring `contact_supervisor`. Two items above are flagged as
needing user input (WCAG version, codegen migration, target platforms); those
are decisions for the parent/developer, not mid-task blockers for this
research role.
