# Code Context

Scope: ConnectMe Flutter app, Issue #026 (Query Provider Performance Optimization). Implementation appears feature-complete in working tree but uncommitted. Two pre-existing test files fail (unrelated to this work).

## Files Retrieved

1. `lib/src/state/query_providers.dart` (lines 1-109, untracked) — new file, the core deliverable for #026
2. `test/state/query_providers_test.dart` (lines 1-233, untracked) — 17 unit tests, all passing
3. `lib/src/features/contact_profile_screen.dart` (modified, +44/-8) — refactored to use new providers
4. `lib/src/features/tabs/home_tab.dart` (modified, +12/-7) — refactored
5. `lib/src/features/tabs/people_tab.dart` (modified, +16/-12) — refactored, uses `.select()`
6. `lib/src/features/tabs/planner_tab.dart` (modified, +35/-27) — refactored, adds `_EventTileWithContact`
7. `docs/issues/026-query-provider-performance-optimization.md` — issue spec
8. `docs/prd/2026-05-15-query-provider-performance-optimization-prd.md` — PRD with full design rationale
9. `progress.md` — last entry is #022 (AI preview stagger), not yet updated for #026
10. `IMPLEMENTATION_SUMMARY_query_providers.md` and `COMPLETION_REPORT.md` (untracked) — author-written notes claiming the work is complete
11. `lib/src/features/ai_update_screen.dart` (lines 172, 208) — still contains `firstWhere` calls (out of #026 scope)
12. `lib/src/features/recommendations_screen.dart` (line 27) — still contains `firstWhere` (out of #026 scope)
13. `lib/src/state/app_state.dart` (line 274) — internal `firstWhere` in controller (different concern)

## Key Code

### query_providers.dart (the new module)

```dart
class ContactFilter {
  const ContactFilter({required this.query, required this.category, required this.sort});
  final String query;
  final String category;
  final ContactSort sort;
  // proper == and hashCode (required for Riverpod family keys)
}

final contactByIdProvider = Provider.family<Connection?, String>((ref, id) {
  final connections = ref.watch(appControllerProvider.select((s) => s.connections));
  final connectionMap = {for (var c in connections) c.id: c};
  return connectionMap[id]; // O(1), null-safe
});

final eventByIdProvider = Provider.family<PlannerEvent?, String>(...);
final interactionsByContactProvider = Provider.family<List<CrmInteraction>, String>(...);
final selectedDayEventsProvider = Provider.family<List<PlannerEvent>, DateTime>(...);

final filteredContactsProvider = Provider.family<List<Connection>, ContactFilter>(
  (ref, filter) {
    final connections = ref.watch(appControllerProvider.select((s) => s.connections));
    final filtered = connections.where(...).toList();
    filtered.sort((a, b) => switch (filter.sort) {
      ContactSort.name => a.name.compareTo(b.name),
      ContactSort.lastContact => b.lastContact.compareTo(a.lastContact),
      ContactSort.bondScore => b.bondScore.compareTo(a.bondScore),
    });
    return filtered;
  },
);
```

Note: every provider builds its lookup Map / runs filter+sort inside the provider body. Riverpod will memoize per-family-key; identical inputs return the same cached value until the watched slice changes. There is no manual cache.

### Widget refactor patterns (representative)

`people_tab.dart` (uses `.select()` for narrow rebuilds):
```dart
final categories = ref.watch(appControllerProvider.select((s) => ['All', ...s.categories]));
final filter = ContactFilter(query: query, category: category, sort: sort);
final people = ref.watch(filteredContactsProvider(filter));
final hasAnyConnections = ref.watch(appControllerProvider.select((s) => s.connections.isNotEmpty));
```

`contact_profile_screen.dart` (null-safe lookup with empty-state fallback):
```dart
final person = ref.watch(contactByIdProvider(contactId));
if (person == null) return Scaffold(... 'This contact no longer exists.' ... TextButton(onPressed: () => context.pop(), child: const Text('Go Back')));
final state = ref.watch(appControllerProvider);              // still watched for insight
final insight = state.contactInsightFor(contactId);
final history = ref.watch(interactionsByContactProvider(contactId));
```

`planner_tab.dart` (introduces helper widget that owns the contact lookup):
```dart
class _EventTileWithContact extends ConsumerWidget {
  // ...
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = event.contactId != null ? ref.watch(contactByIdProvider(event.contactId!)) : null;
    return EventTile(event: event, contact: contact, onTap: onTap, onDelete: onDelete);
  }
}
```

`home_tab.dart` (uses `Builder` to scope each rec card; still watches full `appControllerProvider` at top — see Open Questions):
```dart
Builder(builder: (context) {
  final contact = ref.watch(contactByIdProvider(recs[i].contactId));
  if (contact == null) return const SizedBox.shrink();
  return RecommendationCard(...);
});
```

## Architecture

- State management: `flutter_riverpod` only. Single `AppController extends Notifier<AppState>` exposed via `appControllerProvider` in `lib/src/state/app_state.dart`.
- `AppState` is a flat immutable container holding `connections`, `events`, `interactions`, `categories`, `eventTypes`, `themeMode`, `selectedTab`, etc. All mutations go through `AppController` methods.
- Issue #026 introduces a derived-provider layer in `lib/src/state/query_providers.dart` between `appControllerProvider` and the widgets. Widgets stop reaching into `state.connections.firstWhere(...)` and instead read narrow slices via `.select()` plus `Provider.family` lookups.
- Routing: `go_router` (`context.push('/contact/$id')`).
- Tabs live in `lib/src/features/tabs/{home,people,planner,settings}_tab.dart`; modals in `lib/src/features/modals/`; widgets in `lib/src/widgets/`.
- Theming via `context.tokens`, spacing via `AppSpacing.spaceN` constants. Recent commits show a sweeping migration to spacing/radius tokens.
- Tests use `ProviderContainer` for unit tests (`test/state/`) and `ProviderScope(child: ConnectMeApp())` plus the auth-and-navigate dance for widget tests (`test/features/`).

## Status snapshot

What's done (uncommitted, in working tree):
- Issue #026 implementation: provider module, 17 unit tests (all green), four widget refactors per acceptance criteria.
- All five providers from the spec (`contactByIdProvider`, `eventByIdProvider`, `interactionsByContactProvider`, `selectedDayEventsProvider`, `filteredContactsProvider`) plus `ContactFilter` with proper equality.
- Null-safe handling: `ContactProfileScreen` shows "Contact Not Found" + Go Back; `HomeTab` and `_EventTileWithContact` render `SizedBox.shrink()` for missing contacts.
- `flutter test test/state/query_providers_test.dart` → 17/17 pass.

What's in progress / not yet done:
- No commit has been made for #026. Working tree has 4 modified files plus 3 untracked source/doc files.
- `progress.md` still reads "Completed - Issue #022"; not updated for #026.
- `flutter analyze` was not verified by the scout (build commands have no `timeout` available locally and full `flutter test` exceeded 5 minutes; only the new test file was run end to end).

What's next (from `docs/issues/`):
- No issue #027+ exists. #026 is the most recent issue file. After #026 is committed, planning input will need to come from elsewhere (PRD backlog or human triage).

Pre-existing failures (also fail with the working changes stashed, so they are NOT regressions from #026):
- `test/features/planner_calendar_test.dart` — `authenticateAndNavigateToPlanner` cannot find a `Planner` text widget after sign-in. Likely a tab-label/layout drift from earlier UI work.
- `test/features/recommendation_tap_test.dart` — also fails (didn't capture the exact assertion in this scout pass, but verified it fails on `main` without #026 changes too).

TODO comments in the codebase (untouched by #026, both pre-existing):
- `lib/src/widgets/crm_widgets.dart:315` — "Navigate to Update Connection flow"
- `lib/src/features/ai_update_screen.dart:182` — "Implement undo by removing the saved interactions"

Out-of-scope `firstWhere` callsites still present (not part of #026 acceptance criteria, but worth flagging):
- `lib/src/features/recommendations_screen.dart:27`
- `lib/src/features/ai_update_screen.dart:172` and `:208`
- `lib/src/state/app_state.dart:274` (internal controller logic, different concern)

## Start Here

Open `lib/src/state/query_providers.dart` first. It's small (109 lines), fully self-contained, and shows the exact provider shapes the four refactored widgets consume. From there:
1. Skim `test/state/query_providers_test.dart` to confirm the contract (esp. null-return semantics and `ContactFilter` equality).
2. Read the four diffs in `git diff` order: `contact_profile_screen.dart` → `home_tab.dart` → `people_tab.dart` → `planner_tab.dart` to see the four flavors of the refactor (null-state screen, builder scope, `.select()` slices, helper widget).
3. Cross-check against `docs/issues/026-query-provider-performance-optimization.md` acceptance criteria — every box maps to a concrete change in the diffs.

## Open questions for an implementing agent

1. Is the goal to commit #026 as-is, or to extend it? If the scope is "finish and commit," the implementation already meets every acceptance-criteria box and the new test file is green.
2. `home_tab.dart` still does `final state = ref.watch(appControllerProvider);` near the top of `build()`, which defeats some of the narrow-rebuild benefit advertised in the PRD. Same in `contact_profile_screen.dart` (kept for `state.contactInsightFor(...)`). Should these be tightened with further `.select()` calls, or accept that as out of scope for this slice?
3. `recommendations_screen.dart:27` still uses `connections.firstWhere(...)` and would crash on a stale rec ID, mirroring the bug #026 fixed in `HomeTab`. Issue #026 does not list it. Should it be folded in or filed as #027?
4. `progress.md` is stale (last entry: #022). Update it as part of the #026 commit, or in a separate housekeeping commit?
5. Do the pre-existing failures in `planner_calendar_test.dart` and `recommendation_tap_test.dart` block merging #026? They fail on `main` with the changes stashed, so they're not caused by #026, but the issue states "All existing widget tests pass unchanged" as an acceptance criterion.
6. The three untracked top-level markdown files (`COMPLETION_REPORT.md`, `IMPLEMENTATION_SUMMARY_query_providers.md`, `FIGMA_VS_FLUTTER_COMPARISON.md`) — keep, move under `docs/`, or discard before committing? `FIGMA_VS_FLUTTER_COMPARISON.md` was not inspected and may be unrelated to #026.
7. `flutter analyze` was not run end-to-end by the scout. Worth confirming zero-issues claim from `COMPLETION_REPORT.md` before commit.
