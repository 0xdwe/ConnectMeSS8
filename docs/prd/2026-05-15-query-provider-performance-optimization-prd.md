# Query Provider Performance Optimization PRD

## Problem Statement

The Home, People, and Planner tabs rebuild on every `AppState` change (theme toggle, tab switch, unrelated contact update), and each rebuild re-runs expensive query operations in `build()` methods:

- **PeopleTab**: Filters all connections with string matching, then sorts the entire filtered list — O(n log n) on every rebuild
- **PlannerTab**: Queries `selectedEvents` by iterating all events and calling `DateUtils.isSameDay()` — happens twice per rebuild (once for the tile list, once for the "Selected day" section)
- **HomeTab**: Calls `connections.firstWhere()` for each recommendation card — O(n) lookup per card, no memoization

These queries run even when the underlying data (connections, events) hasn't changed. A user toggling dark mode triggers a full filter/sort cycle in PeopleTab. A user switching tabs triggers event queries in PlannerTab even though the selected date and event list are unchanged.

Additionally, `firstWhere` in HomeTab and ContactProfileScreen throws when a contact ID becomes stale (e.g., after deletion but before route pop), causing crashes on edge-case navigation.

## Solution

Extract query logic from widget `build()` methods into Riverpod derived providers that memoize results and only recompute when their specific data slice changes. Widgets watch narrow slices of `AppState` using `.select()`, so they only rebuild when relevant data changes. Lookups use Map-based O(1) access instead of O(n) `firstWhere`, and return null for missing IDs instead of throwing.

## User Stories

1. As a user toggling dark mode, I want the UI to respond instantly, so that theme changes feel lightweight and don't trigger unrelated work.
2. As a user switching between tabs, I want tab transitions to be smooth, so that navigation feels fluid.
3. As a user typing in the People search field, I want filtering to feel instant, so that I can quickly find a contact.
4. As a user scrolling the People list, I want smooth 60fps scrolling, so that the app feels polished.
5. As a user navigating the Planner calendar, I want day selection to respond immediately, so that I can quickly review my week.
6. As a user with 50+ contacts, I want the app to remain fast, so that I don't feel penalized for using it heavily.
7. As a user deleting a contact, I want the app to handle stale routes gracefully, so that I don't see crashes when navigating back.
8. As a developer, I want query logic testable in isolation, so that I can verify filtering/sorting/lookup behavior without pumping widgets.
9. As a developer, I want widgets to be presentation-only, so that business rules are separated from UI.
10. As a developer, I want memoized queries, so that expensive operations run once per data change, not once per frame.

## Implementation Decisions

### Modules to build

- **Query providers** (new): Riverpod family providers that derive filtered/sorted/looked-up data from `AppState`. These are the new deep modules — small interface (a provider signature), large implementation (filtering, sorting, Map construction, null-safe lookup).
  - `filteredContactsProvider(ContactFilter)` — filters and sorts connections based on query string, category, and sort mode
  - `selectedDayEventsProvider(DateTime)` — returns events for a specific date
  - `contactByIdProvider(String)` — O(1) lookup, returns `Connection?`
  - `eventByIdProvider(String)` — O(1) lookup, returns `PlannerEvent?`
  - `interactionsByContactProvider(String)` — returns interactions for a contact

- **ContactFilter model** (new): Immutable data class holding `query`, `category`, `sort` — used as the family key for `filteredContactsProvider`.

- **Widget refactors** (modified): `PeopleTab`, `PlannerTab`, `HomeTab`, `ContactProfileScreen` — remove inline queries, watch derived providers instead.

### Interfaces

**filteredContactsProvider**:
```dart
final filteredContactsProvider = Provider.family<List<Connection>, ContactFilter>(
  (ref, filter) {
    final connections = ref.watch(appControllerProvider.select((s) => s.connections));
    // filter + sort logic here
    return filtered;
  },
);
```

**selectedDayEventsProvider**:
```dart
final selectedDayEventsProvider = Provider.family<List<PlannerEvent>, DateTime>(
  (ref, date) {
    final events = ref.watch(appControllerProvider.select((s) => s.events));
    return events.where((e) => DateUtils.isSameDay(e.date, date)).toList();
  },
);
```

**contactByIdProvider**:
```dart
final contactByIdProvider = Provider.family<Connection?, String>(
  (ref, id) {
    final connections = ref.watch(appControllerProvider.select((s) => s.connections));
    return {for (var c in connections) c.id: c}[id]; // O(1), null-safe
  },
);
```

### Technical clarifications

- Providers live in a new file: `lib/src/state/query_providers.dart`
- `ContactFilter` is an immutable class with `==` and `hashCode` overrides (required for Riverpod family keys)
- Widgets use `ref.watch(filteredContactsProvider(filter))` instead of inline filtering
- Widgets use `.select()` to watch only the data slice they need: `ref.watch(appControllerProvider.select((s) => s.connections))`
- `firstWhere` calls are replaced with provider lookups that return nullable types
- Widgets handle null gracefully: show empty state or navigate back if contact is missing

### Architectural decisions

- **Depth**: Query providers are deep modules. Interface = provider signature (one line). Implementation = filtering, sorting, Map construction, null handling. Callers get memoization and narrow rebuilds without knowing how.
- **Seam**: The provider boundary is a real seam. Tests can override providers with mock data. Widgets are decoupled from query logic.
- **Locality**: Query bugs are isolated to `query_providers.dart`. Widget bugs are isolated to presentation. A filter bug doesn't require reading widget code.
- **Leverage**: Every widget that needs filtered contacts gets memoization for free. Adding a new filtered view (e.g., "recently added") is one new provider, zero widget changes.

### Schema changes

None. This is a refactor of existing query logic, not a data model change.

### API contracts

None. This is internal architecture, no external APIs.

### Specific interactions

- User types in People search → `PeopleTab` updates local `query` state → watches `filteredContactsProvider(ContactFilter(query, category, sort))` → provider recomputes only if filter changed → list rebuilds with new data
- User toggles dark mode → `AppState.themeMode` changes → `PeopleTab` does NOT rebuild (it doesn't watch `themeMode`) → no filter/sort work triggered
- User taps a recommendation card → `HomeTab` calls `context.push('/contact/${rec.contactId}')` → `ContactProfileScreen` watches `contactByIdProvider(contactId)` → if null, shows "Contact not found" and pops route

## Testing Decisions

### What makes a good test

- Test external behavior: given a filter, does the provider return the correct filtered list?
- Test memoization: does the provider return the same instance when inputs haven't changed?
- Test null safety: does `contactByIdProvider` return null for missing IDs instead of throwing?
- Do NOT test implementation details: don't assert on the internal Map structure, don't mock Riverpod internals.

### Which modules will be tested

- **Query providers** (unit tests): Test filtering, sorting, lookup, null handling in isolation. No widgets, no `pumpWidget`.
  - `test/state/query_providers_test.dart` — new file
  - Test `filteredContactsProvider` with various `ContactFilter` inputs
  - Test `contactByIdProvider` with valid and invalid IDs
  - Test `selectedDayEventsProvider` with dates that have events and dates that don't

- **Widget integration** (existing widget tests): Verify that widgets still work after refactor. No new tests needed — existing tests should pass unchanged.
  - `test/features/people_tab_test.dart` (if it exists) or `test/widget_test.dart`
  - Pump `PeopleTab`, type in search, assert filtered results appear

### Prior art

- `test/state/app_state_test.dart` — shows how to test Riverpod providers with `ProviderContainer`
- `test/widget_test.dart` — shows how to pump widgets and assert on rendered content

## Out of Scope

- Splitting `AppController` into domain services (that's a separate, larger refactor)
- Adding a repository seam for persistence (separate work)
- Moving UI concerns out of domain models (separate work)
- Extracting form logic from modals (separate work)
- Real-time performance profiling or benchmarking (we're addressing known O(n) and O(n log n) work in hot paths; profiling can come later if needed)
- Pagination or virtualization for large lists (not needed until 100+ contacts)

## Further Notes

This PRD addresses the performance bottleneck identified in the architecture review: widgets rebuilding on every `AppState` change and re-running expensive queries in `build()` methods. The fix is a standard Riverpod pattern (derived providers + `.select()`) that improves performance, testability, and separation of concerns.

The work is scoped to query extraction only. Larger architectural improvements (domain services, repository seam) are deferred to future PRDs to keep this slice shippable.

Expected performance gains:
- Theme toggle: no filter/sort work triggered (currently triggers full People list recompute)
- Tab switch: no query work in inactive tabs (currently all tabs rebuild on every state change)
- People search: memoized results, only recomputes when filter changes (currently recomputes on every keystroke even if query is unchanged)
- Contact lookup: O(1) Map access instead of O(n) `firstWhere` (currently iterates full list for every recommendation card)

This is a high-leverage, low-risk refactor. No user-facing behavior changes, no schema changes, no new features. Pure performance and architecture improvement.
