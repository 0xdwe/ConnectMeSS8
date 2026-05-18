# Code Context — Deepening Opportunities

Read-only architectural scout. Branch `main` @ `c0efe08`. 174/0 tests passing.
Vocabulary follows the brief: module / interface / implementation / depth / seam / adapter / leverage / locality.

## Files Retrieved

1. `lib/main.dart` (1-9) — bootstrap, only mounts `ProviderScope(ConnectMeApp())`.
2. `lib/src/app/connect_me_app.dart` (1-46) — `routerProvider`, theme wiring, root MaterialApp.
3. `lib/src/state/app_state.dart` (1-642) — `AppState` (data + `recommendations` getter + `contactInsightFor`) and `AppController` (every mutator).
4. `lib/src/state/query_providers.dart` (1-109) — `contactByIdProvider`, `eventByIdProvider`, `interactionsByContactProvider`, `selectedDayEventsProvider`, `filteredContactsProvider` + `ContactFilter`.
5. `lib/src/ai/ai_update_service.dart` (1-58) — `AiUpdateService` interface + `MockAiUpdateService` (string-match categorizer).
6. `lib/src/models/social_models.dart` (1-329) — domain types and the `InteractionTypeLabel` extension that pulls `package:flutter/material.dart` into the model layer.
7. `lib/src/widgets/crm_widgets.dart` (1-1328) — 19 widget classes plus `topicsForContact` / `suggestionsForTopic` + static lookup tables (lines 781-895). Includes `AppHeader` (orphan, line 19), deprecated `ScoreRing` (line 79), `HeatmapCard` (orphan, line 331).
8. `lib/src/widgets/bond_ring.dart` (1-306) — `BondTier`, `BondTrend`, `BondRing` (animation contained inside the widget).
9. `lib/src/features/shell_screen.dart` (1-159) — three-tab shell, AppBar avatar → `/settings`.
10. `lib/src/features/auth_screen.dart` (1-412) — almost entirely form UI; logic is two validators + two controller calls.
11. `lib/src/features/contact_profile_screen.dart` (1-305) — reads `contactByIdProvider`, `state.contactInsightFor(id)`, `interactionsByContactProvider`.
12. `lib/src/features/ai_update_screen.dart` (1-443) — input + preview cards; calls `appControllerProvider.notifier.previewAiUpdate` / `commitAiUpdate`.
13. `lib/src/features/recommendations_screen.dart` (1-49) — iterates `state.recommendations`, looks up contacts via provider.
14. `lib/src/features/profile_screen.dart` (1-117) — orphan per `docs/issues/037`.
15. `lib/src/features/tabs/{home,people,planner}_tab.dart` — main consumers of state + query providers.
16. `lib/src/features/modals/*.dart` (11 files, 56-291 lines each) — every modal calls `appControllerProvider.notifier.<mutator>` directly.
17. `test/state/{app_state,query_providers}_test.dart` — direct `ProviderContainer` tests (the only tests that don't pump widgets).
18. `test/features/*` and `test/widgets/*` — pump-the-tree tests.
19. `docs/prd/2026-05-16-per-contact-memory-files-prd.md` — Pass 3 plan: `MemoryDocument`, `MemoryStore` (FileMemoryStore + InMemoryMemoryStore), `MemoryUpdater` (Mock now / LLM later), `memoryProvider`, `memoryTopicsProvider`. Memory is a side effect after `AiUpdateResult`.
20. `docs/issues/026` (query providers), `docs/issues/037` (orphans).
21. `pubspec.yaml` — no `path_provider`, `shared_preferences`, `hive`, `sqflite`, `drift`, `isar`. Persistence does not exist yet.

## Key Code

### `AppController` interface — wide and mostly thin
`lib/src/state/app_state.dart:354-637`. Methods grouped by responsibility:

- **Session/theme/nav** (5): `signIn`, `signUp`, `signOut`, `setTab`, `setThemeMode` (+ deprecated `setDarkMode`). All one-liners over `copyWith`.
- **User profile** (1): `updateUser`.
- **Contacts CRUD + cascades** (4): `addConnection`, `updateConnection`, `deleteConnection` (cascades into events + interactions), `removeSampleConnections` (also cascades).
- **Interactions** (1): `logInteraction`.
- **Planner CRUD** (5): `addEvent`, `saveEvent` (upsert), `deleteEvent` (returns deleted for undo), `restoreEvent`.
- **Categories + event types** (5): `addCategory`, `addEventType`, `renameEventType` (cascades into events), `deleteEventType` (cascades).
- **Google Calendar mock** (1): `toggleGoogleCalendar`.
- **AI orchestration** (3): `previewAiUpdate`, `commitAiUpdate`, `runAiUpdate`.

### `AiUpdateService` seam — one adapter today
`lib/src/ai/ai_update_service.dart:4-58`. Returns `AiUpdateResult { summary, contactId, interactions, nextStep }`. Pass 3 PRD adds a *parallel* `MemoryUpdater.update(current, contact, userInput, attachments) → MemoryDocument` plus `MemoryStore` and runs it as a side effect after `AiUpdateResult` is committed.

### `Recommendation` — hardcoded
`lib/src/state/app_state.dart:51-69`. Three constants returning fixed `contactId`s (`mike`, `jessica`, `emily`). Not derived from `bondScore`, `lastContact`, `interactions`, or `knownSince` — even though `AppState.contactInsightFor` (lines 273-307) computes exactly that kind of signal per contact.

### `topicsForContact` / `suggestionsForTopic` — buried in widgets file
`lib/src/widgets/crm_widgets.dart:780-895`. Two pure functions backed by two const maps (`_topicDefaultsByCategory`, `_topicSuggestions`), called only by `_AiInsightsBody` and `_showTopicSuggestionsSheet` in the same file. The PRD explicitly names these as the Pass 3 swap point. Their entire module lives mid-file in a 1328-line widgets dump.

### `InteractionTypeLabel` extension — model → Flutter import
`lib/src/models/social_models.dart:1` imports `package:flutter/material.dart` only so lines 75-93 can attach `.label` (String) and `.icon` (IconData) to the enum. Callers: `ai_update_screen.dart`, `contact_profile_screen.dart`, and `ai_update_service.dart:50` (uses `type.label` inside the AI's *summary string*).

### `query_providers.dart` — recent #026 work
By-id providers are 5-7 lines each, e.g. `contactByIdProvider` builds a `Map<String, Connection>` on every read for a single lookup:

```dart
final contactByIdProvider = Provider.family<Connection?, String>((ref, id) {
  final connections = ref.watch(appControllerProvider.select((s) => s.connections));
  final connectionMap = {for (var c in connections) c.id: c};
  return connectionMap[id];
});
```

`filteredContactsProvider` is the only one with non-trivial logic (filter + sort, keyed by `ContactFilter`).

### `AuthScreen` — UI heavy, logic light
`lib/src/features/auth_screen.dart:50-104` is the entire logic surface: two validators + two submit handlers that call `appControllerProvider.notifier.signIn()` / `signUp(name, email)`. The other 300+ lines are stateless form widgets. The controller methods themselves are one-liners (`signIn() => state = state.copyWith(isAuthed: true)`).

## Architecture

```
main.dart → ProviderScope → ConnectMeApp → routerProvider (GoRouter)
                                                │
        ┌───────────────────────────┬───────────┴───────────┬──────────────────┐
   AuthScreen                ShellScreen              ContactProfileScreen   AiUpdateScreen
                       (Home/People/Planner tabs)
                                │
                ┌───────────────┴────────────────┐
        appControllerProvider              query_providers (5 family providers)
        (AppController + AppState)              │
                │                                └── all read .select((s) => s.<slice>)
                │                                    from appControllerProvider
                │
                ├── direct mutator calls from every modal + tab + screen
                ├── aiUpdateServiceProvider → MockAiUpdateService (only adapter)
                └── AppState.contactInsightFor(id) — derived per-contact insight
                    AppState.recommendations — three hardcoded constants
```

Everything funnels through `appControllerProvider`. Persistence does not exist (no `path_provider`, no shared prefs). `signOut` resets state to `AppState.seeded()`, which is also the seed source.

Tests split cleanly: `test/state/*` use `ProviderContainer` directly (cheap, fast, behavioral). `test/features/*` and `test/widgets/*` pump widget trees. Anything routed through `AppController` or the providers is testable today; anything bundled inside widget build methods (animation timing, topic lookup, recommendation copy) is currently only reachable through a pumped tree.

## Deepening Opportunities

Ordered by impact. Six real candidates plus a tail of "considered but not architectural deepening."

---

### 1. `AppController` is a wide controller hiding two or three deep modules

**Files** — `lib/src/state/app_state.dart` (whole file). Every modal in `lib/src/features/modals/` and every tab. The 18 controller methods listed in Key Code.

**Problem.** The interface is wide (18 mutators across seven concerns). The implementation is mostly pass-through `copyWith`. Apply the deletion test method-by-method:

- `signIn`, `signUp`, `signOut`, `setTab`, `setThemeMode`, `toggleGoogleCalendar`, `updateUser`, `addConnection`, `updateConnection`, `addCategory`, `addEventType`, `logInteraction`, `addEvent`, `saveEvent`, `restoreEvent` — pure `copyWith` adapters. Delete them and 11 callers each open-code the same `copyWith`. Complexity does not reappear; it's already at the call sites in spirit.
- `deleteConnection`, `removeSampleConnections`, `deleteEventType`, `renameEventType` — these earn their keep. They are the only places that own cross-list cascades (delete contact → drop their events + interactions; delete event type → reassign events to `'Plan'`). Delete them and the cascade logic has to be reproduced at ~four call sites in modals.
- `previewAiUpdate` / `commitAiUpdate` / `runAiUpdate` — earn their keep, but they're a different shape: orchestration of an external service and a state mutation, not a single state edit.

So: a 642-line file is doing ~five things deeply (cascades, AI orchestration, derived insight computation, sample-data lifecycle, the AppState seed) and ~thirteen things shallowly. The interface to maintainers (and to tests) is the union of all of it. Understanding "what does adding a contact do?" requires reading the file end-to-end because cascades, sample flags, and AI summary state all coexist.

The hidden module is the *cascade rules* — `deleteConnection` knows to remove related events and interactions; `removeSampleConnections` knows the same; `deleteEventType` knows to retarget events; `renameEventType` knows to rewrite the type string on every event. That is one coherent piece of behaviour spread across four methods.

**Proposed deepening.** Reshape the state layer into three domain-shaped modules whose interfaces describe behaviour, not edits:

- A **Contacts** module that owns the connection list and *its* cascade semantics — deleting a contact doesn't have to be three lines of `copyWith`, it's `contacts.delete(id)`, and that operation's contract is "remove the contact and any owned references in planner/interactions." Other domains subscribe rather than the controller open-coding.
- A **Planner** module owning events + event types with the rename/delete cascade contract internal.
- An **AI update** module owning the preview/commit/run trio (and, when Pass 3 lands, the memory side effect — see candidate 2).
- A thin **Session** layer for auth/theme/tab/user that admits it's thin.

The point is not "more files." The point is that `contacts.delete(id)` is a deeper interface than the four-method chord that produces the same effect today. Cascades stop being a thing tests have to assert per-mutator and become an invariant of the module.

**Dependency category.** In-process. No adapters, all mergeable Dart.

**Benefits.**
- *Locality.* "What happens when I delete a contact?" is one method's contract, not four. The cascade test in `app_state_test.dart:158-176` becomes a property of the Contacts module rather than a controller-level integration test.
- *Leverage.* Modal callers stop knowing the shape of `copyWith` and call domain operations. Sample-data lifecycle becomes a Contacts concern, not a top-level method.
- *Tests.* `test/state/app_state_test.dart` already drives `ProviderContainer` directly, so this refactor lands without rewriting test infrastructure. Tests get more focused (one module per file). The cascade test simplifies from "controller delete then assert across three lists" to "contacts delete then assert one observable."

**Risks / counters.**
- Pass 3 PRD assumes `AppController.runAiUpdate` is the integration point for memory. If we split AI orchestration off, the PRD's wiring instructions point at a different module — that's fine but worth flagging. Aligns naturally if candidate 2 happens together.
- Riverpod's `Notifier<AppState>` is currently the consumer-visible seam. Splitting state means either multiple notifiers (more providers to watch) or one notifier with composed sub-states. Either is reasonable; the latter is closer to what's there now.
- The biggest risk is overcorrection: turning every shallow method into a separate module. The deletion test says most of those methods *should not survive* the split — they are not modules, they are noise.

---

### 2. The AI seam is shaped wrong for Pass 3 and will fight the PRD

**Files** — `lib/src/ai/ai_update_service.dart`, `lib/src/state/app_state.dart:546-636` (`previewAiUpdate` / `commitAiUpdate` / `runAiUpdate`), `docs/prd/2026-05-16-per-contact-memory-files-prd.md`.

**Problem.** Today there is one adapter (`MockAiUpdateService`) behind one interface (`AiUpdateService.categorizeAndUpdate`). One adapter is a hypothetical seam. The PRD adds a *second*, *parallel* seam (`MemoryUpdater` + `MemoryStore`) and runs it as a side effect after the existing AI flow:

> "After it produces an `AiUpdateResult` (the existing interaction-creation flow), it calls `MemoryUpdater.update()` as a side effect."

That gives Pass 3 two boundaries doing similar agentic work, neither of them deep:

- `AiUpdateService.categorizeAndUpdate` — input → categorized interaction(s).
- `MemoryUpdater.update` — input + current memory + contact → new memory document.

Both will, when LLM-backed, hit the same provider with overlapping prompts. Both have a Mock adapter for evaluation runs. The orchestration of "run the LLM, parse, update interactions, update memory, persist, invalidate providers" is split across `AppController` and a new memory module. The seam is shallow on both sides because each piece does one specialized thing while the *real* concept the user has — "the AI updated my notes about Sarah" — is the union.

There's also a model leak that grows under Pass 3: `MockAiUpdateService` reads `type.label` (a UI string) into its `summary`. Pass 3's mock updater is described as deterministic with topic extraction. If both implementations grow, both will keep importing UI labels for their narrative outputs unless we redirect.

**Proposed deepening.** Before Pass 3 builds the parallel structure, treat agentic update as one deep module: input + contact context → (interactions, memory, summary). The interface owns the contract that the side effects are consistent (you can't get a memory update without interactions, or vice versa) and the Mock/LLM swap is one adapter substitution, not two. Persistence of memory is a separate concern (a `MemoryStore`-style seam stays — but it's an implementation collaborator, not a parallel public boundary).

The shape of the external interface is the user-level operation: "given this user input on this contact, produce the full updated state." Internally the module can call a small `LlmClient` and a `MemoryDocument` parser; those are private and mockable.

**Dependency category.** Local-substitutable today (Mock adapter); true external once an LLM provider is wired. The persistence collaborator is local-substitutable (in-memory + file).

**Benefits.**
- *Locality.* One module owns "what does Update with AI mean." Today it's stitched across `AiUpdateService`, `AppController.previewAiUpdate` (which marks every interaction `aiSuggested` after the fact, line 568-578), `AppController.commitAiUpdate` (which bumps `bondScore` by 3 and updates `lastContact`), and — under Pass 3 — `MemoryUpdater` + `MemoryStore` + a provider invalidate.
- *Leverage.* The screen calls one method. Tests for "preview shows N edits" stay; tests for memory and interaction consistency become one test instead of two.
- *Tests.* `test/features/ai_update_preview_test.dart` and the proposed memory tests collapse into one module-level test surface. The deterministic mock guarantee the PRD wants for evaluation runs is one mock to control, not two.

**Risks / counters.**
- This *would supersede* the Pass 3 PRD's two-interface design (`MemoryUpdater` + `MemoryStore` as separate public boundaries with the existing `AiUpdateService` left alone). The PRD argues for parallel boundaries to keep scope small; the counter-argument is that we're paying the integration tax twice (once for Pass 3, again when LLM lands).
- Pass 3 PRD lists 18 user stories tied to memory specifically. A unified module still needs an internal `MemoryDocument` type and storage; nothing about the *data model* changes, only the *seam shape*.
- If the team would rather minimize Pass 3 scope, the smaller fix is to keep two interfaces but route both through a shared `AiOrchestrator` module so the controller doesn't see two side effects. That's a half-measure but avoids re-litigating the PRD.

---

### 3. There's a missing `RecommendationEngine` module — `state.recommendations` is a stub

**Files** — `lib/src/state/app_state.dart:51-69` (the hardcoded getter), `lib/src/state/app_state.dart:273-307` (`contactInsightFor`, which already computes the kind of signal a recommender would use), `lib/src/features/tabs/home_tab.dart`, `lib/src/features/recommendations_screen.dart`.

**Problem.** `AppState.recommendations` is three hardcoded `Recommendation` constants pointing at three of the seed connections by id. If the user adds, deletes, or grows close to a contact, recommendations don't change. If they delete `mike`, the `RecommendationCard` for `mike` silently disappears (handled by `contactByIdProvider == null`) but the other two stay frozen. There is also test-coverage hardcoded around this: `test/features/recommendations_screen_stale_id_test.dart` exercises the deletion branch.

Apply the deletion test: delete the getter entirely. Two screens lose their list. Complexity does not reappear at the call sites — the constants are *static seed data*, not behaviour. So this isn't a pass-through module; it's a missing module wearing a getter's clothing.

Meanwhile `contactInsightFor` already derives `daysSinceContact`, `frequencyTotal`, `_potentialGain` based on bond + recency. The "who needs outreach" cross-contact ranking is exactly the same kind of signal, applied across the connection list and sorted. This is a deep module hiding in plain sight.

**Proposed deepening.** A `RecommendationEngine` module that, given `connections` + `interactions` + `now`, returns a ranked list of `Recommendation` (or its renamed successor). The interface is "give me today's outreach picks"; the implementation owns the ranking heuristic (already half-written in `_potentialGain`), the priority bucketing, and the "why this one" copy. `contactInsightFor` either becomes a method on this module or shares helpers with it.

The product question hidden in this candidate: *is recommendations real product, or is it placeholder for Pass 4+ AI work?* If placeholder, the right move may be to delete the screen + getter (apply the deletion test for real) rather than build a fake engine. Worth confirming with product before building. The Pass 3 PRD does not mention recommendations.

**Dependency category.** In-process. Pure function over current state.

**Benefits.**
- *Locality.* Outreach signal logic lives in one place, not split between a per-contact insight method and three frozen constants.
- *Leverage.* Home tab and recommendations screen call one method. Adding/deleting/growing connections updates recommendations automatically. The `aiSuggested` source on interactions becomes a usable signal.
- *Tests.* The current `recommendations_screen_stale_id_test.dart` covers "deleted contact's card disappears" — a defensive UI test for a problem the engine wouldn't have. Replaceable with engine-level tests: "deleted contact never appears in output", "drifting contacts surface before close ones", etc. Pure-function tests.

**Risks / counters.**
- If this is product placeholder waiting for real AI, building a heuristic engine now is sunk cost. Confirm intent first.
- The current hardcoded copy ("Mike's been quiet for a while.", "Jessica is starting to drift.") is hand-written narrative. A heuristic engine produces templated copy — possibly less warm. The Pass 3 memory work could eventually feed the engine its narrative; this is one place where waiting is the right call if Pass 3 is committed.

---

### 4. Topic + suggestion lookup tables are buried inside `crm_widgets.dart`

**Files** — `lib/src/widgets/crm_widgets.dart:780-895` (two const maps + `topicsForContact` + `suggestionsForTopic`), `lib/src/widgets/crm_widgets.dart:1027` and `:1191` (only callers, both in the same file), `docs/prd/2026-05-16-per-contact-memory-files-prd.md` (names them as the Pass 3 swap point explicitly).

**Problem.** `crm_widgets.dart` at 1328 lines is a *file-organizational* problem at first glance, not architectural. Most of its 19 widgets are independent stateless display components that don't share state. They can co-locate in one file without losing locality. That's organizational drift, not shallowness.

The architectural problem is different: a non-widget module — `topicsForContact` / `suggestionsForTopic` plus the two static maps `_topicDefaultsByCategory` and `_topicSuggestions` — lives mid-file inside the widgets dump. The PRD says exactly this:

> "Pass 3 changes one line in the topics widget: from `_categoryDefaults(connection.category)` to `ref.watch(memoryTopicsProvider(connection.id))` with `_categoryDefaults` as the empty-state fallback."

The swap site is buried in a 1328-line widget file. Anyone trying to understand the topics surface has to grep across `crm_widgets.dart` — past `HeatmapCard`, `CardBox`, `EventTile`, `ConnectionScoreHero` — to find the actual data layer.

Apply the deletion test to `crm_widgets.dart`: the widgets relocate into individual files, but their behavior is unchanged. The functions and maps, however, *want* to be a module on their own — they are the only non-widget logic in there.

**Proposed deepening.** Pull the topics module out as `lib/src/state/conversation_topics.dart` (or somewhere outside `widgets/`). Its external interface is two functions: "topics for a connection" and "suggestions for a topic." The category-keyed constants are private. When Pass 3 swaps in memory-derived topics, the module's signature stays the same and only its implementation changes. Pass 3's `memoryTopicsProvider` then shadows or wraps this module rather than threading through widget code.

The widget file size is a separate, lower-impact organizational cleanup. Extract `HeatmapCard` (orphan), `AppHeader` (orphan), and the deprecated `ScoreRing` per `docs/issues/037` — that's housekeeping not architecture.

**Dependency category.** In-process.

**Benefits.**
- *Locality.* Pass 3's swap-point docs become accurate at file level. "Where do conversation topics come from?" → one file, three functions.
- *Leverage.* The Pass 3 `memoryProvider`-backed topics surface becomes a one-import change; today it's a textual edit in `_AiInsightsBody`.
- *Tests.* Today these functions are only reached through pumping the AI Insights card. Pulled out, they get pure-function tests in `test/state/`. The static maps get a single round-trip test.

**Risks / counters.**
- Touching the file ahead of Pass 3 means Pass 3's PRD instructions (which reference inline names) need updating. Cheap.
- Don't conflate this with splitting `crm_widgets.dart` into N widget files. That's an organizational call, defensible either way.

---

### 5. `InteractionType` extension methods leak Flutter into the model layer

**Files** — `lib/src/models/social_models.dart:1` (the `flutter/material.dart` import), `:75-93` (the extension), call sites in `ai_update_screen.dart`, `contact_profile_screen.dart`, and `ai_update_service.dart:50` (the model leak compounding into the AI service's narrative output).

**Problem.** The extension attaches `.label` (String) and `.icon` (IconData) to the enum. To do that, the model file imports Flutter. Three things follow:

1. The model layer is no longer Flutter-free. Any test wanting to use `InteractionType` pulls in the framework.
2. The AI service uses `type.label` inside the user-facing summary string (`'Mock AI sorted this into ${type.label}...'`). UI vocabulary leaks into the AI's *output*. When `LlmMemoryUpdater` lands, it inherits this expectation.
3. The "type owns its rendering rules" reading sounds deep — but the rules are actually `IconData` (a Flutter class) and an English-only label. That's not "owned"; that's *coupled*.

Apply the deletion test: delete `.label` and `.icon`. Three callers each need access to a label and an icon for a given `InteractionType`. Where do they get it? A small presentation registry (or pair of pure functions) in `lib/src/widgets/` keyed on the enum. The model goes back to pure data. The "owns its rendering" depth was illusory because the rendering wasn't really part of the data type — it was a UI dictionary glued onto it.

**Proposed deepening.** Move presentation off the enum. The enum stays pure (no Flutter import). A small presentation module — `interaction_type_presentation.dart` near the widgets — exposes `labelFor(InteractionType)` and `iconFor(InteractionType)`. The AI service stops using `type.label` for its narrative summary and either uses a pure-data string or returns a structured result the UI labels later.

**Dependency category.** In-process.

**Benefits.**
- *Locality.* Model file is data-only. Presentation lives with presentation.
- *Leverage.* Localization later (if it happens) is one swap in the presentation module, not a model-layer change.
- *Tests.* Today no test exercises `.label` / `.icon` directly; they are tested transitively through widget pumps. Pulled out, they become a one-line unit test per case.

**Risks / counters.**
- Smaller in impact than candidates 1-4; defensible to defer until the AI service refactor (candidate 2) anyway, since both touch the AI service's summary string.

---

### 6. `query_providers.dart` by-id providers are shallow Riverpod hats — the family-provider shape is at risk of expanding

**Files** — `lib/src/state/query_providers.dart` (1-109), the consumers in `home_tab.dart`, `people_tab.dart`, `planner_tab.dart`, `contact_profile_screen.dart`, `recommendations_screen.dart`, `ai_update_screen.dart`.

**Problem.** Issue #026 was a real perf win for `filteredContactsProvider` (filter+sort under a stable `ContactFilter` key — that's a genuinely deep module: meaningful logic behind a small interface). The other four — `contactByIdProvider`, `eventByIdProvider`, `interactionsByContactProvider`, `selectedDayEventsProvider` — are each 5-7 lines of `state.connections.firstWhere(...)` (or `.where(...).toList()`) wearing a Riverpod hat.

Apply the deletion test: delete the by-id providers. Callers re-inline `state.connections.firstWhereOrNull((c) => c.id == id)`. The `.select((s) => s.connections)` slicing is the leverage — it stops widget rebuilds on unrelated state changes — and that's worth keeping. But the leverage is the slicing, not the providers. The providers themselves are pass-through wrappers earning their keep only by being a place to stick the `.select` call.

`contactByIdProvider` also rebuilds an entire `Map<String, Connection>` on every read for one lookup, then throws the map away. That's not memoization — it's per-read amortization that doesn't amortize. The PRD that birthed this wanted O(1) lookup; the code is O(n) per lookup, dressed up as O(1).

The shallowness is fine *today* — five family providers is manageable. The risk is trajectory: Pass 3 adds `memoryProvider` (family) and `memoryTopicsProvider` (family). Future ranking, search, and filter work each tend to add another. If they keep this shape — one provider per call site — the file becomes a phonebook of thin wrappers.

**Proposed deepening.** Keep `filteredContactsProvider` (genuinely deep). Reconsider the by-id ones. Two paths:

- **Path A (small):** Replace by-id providers with one shared, memoized read model — a `connectionsIndexProvider` returning `Map<String, Connection>` that *is* recomputed only when `connections` changes. By-id lookups become `ref.watch(connectionsIndexProvider)[id]`. Same `.select` leverage; one map, not five.
- **Path B (broader):** Roll the by-id, by-day, by-contact lookups into the domain modules from candidate 1. The Contacts module exposes `byId`, the Planner module exposes `eventsOn(date)`, etc. Riverpod providers stay as the integration glue but stop being the thing that owns the indexing.

**Dependency category.** In-process.

**Benefits.**
- *Locality.* "Where do contact lookups live?" → one module, not five providers.
- *Leverage.* O(1) lookup actually achieved (one map built when connections change, reused). When candidate 1 lands, the providers get thinner naturally.
- *Tests.* `test/state/query_providers_test.dart` has 19 tests, half of which are "exists" / "not exists" smoke tests for the by-id providers. Those collapse into a few index-level tests.

**Risks / counters.**
- Borderline candidate. The current shape works and was just shipped. Unless candidate 1 or 2 motivates touching this layer, "leave it" is defensible.
- If candidate 1 happens, this gets reshaped naturally as a side effect — list it but don't act on it independently.

---

## Considered but not architectural deepening today

- **Persistence absence.** No `path_provider` / shared prefs / sqflite dependency exists. `signOut` literally returns to `AppState.seeded()`. Pass 3 introduces `FileMemoryStore` and `InMemoryMemoryStore` (two adapters — a real seam, scoped to memories). Generalizing persistence across all state now would be *one adapter* (in-memory) — a hypothetical seam, premature. **Recommendation: let Pass 3 ship its scoped `MemoryStore`, watch what shape the second persisted thing wants, then generalize.**
- **Auth flow.** `auth_screen.dart` is 412 lines, almost entirely form UI. Logic is two validators + `signIn()` / `signUp()`. The screen *is* shallow and bundled with logic, but the logic is also shallow (one-liner `copyWith`s). One adapter today (in-memory). Future Firebase work will need a session module — but introducing it now is a hypothetical seam. **Recommendation: defer until Firebase decision is real, or fold under candidate 1 as the Session module.**
- **`crm_widgets.dart` size (1328 lines).** Organizational, not architectural. Splitting widgets into per-file is fine but doesn't improve depth. The architectural piece inside the file is the topics module — captured as candidate 4.
- **`BondRing` animation logic mixed with widget.** The animation state is local to the widget and self-contained. Pulling animation into a separate controller class would add modules without adding depth. Skip.
- **`profile_screen.dart` + `HeatmapCard` orphans.** `docs/issues/037` already captures this. Housekeeping, not architectural deepening.
- **`Connection` getter aliases** (`role`, `company`, `closeness`, `tags`, `avatarSeed`). Look like residue from a previous refactor. Code hygiene, not architectural.

## Start Here

Open `lib/src/state/app_state.dart` first. The `AppController` class (line 354 onward) is the highest-leverage surface to discuss because (a) it is the central pile, (b) candidates 1, 2, 3, and 6 all touch it, and (c) the deletion test applied method-by-method makes the shallow vs. deep split immediately visible. The `recommendations` getter at line 51-69 is a fast warm-up: three constants where a module should be.

After that, read `docs/prd/2026-05-16-per-contact-memory-files-prd.md` end-to-end and decide whether candidate 2 (collapse the AI seam shape now) is worth opening before Pass 3 starts implementation, or whether the PRD's parallel-boundary plan is preferred.

## Supervisor coordination

Not blocked. Returning the completed scout findings normally.

---

## Resolution (2026-05-18, post-grilling)

The grilling loop resolved each candidate as follows:

| Candidate | Verdict | Where it lives now |
|---|---|---|
| 1 — `AppController` split | Defer to Pass 3 design | Pass 3 PRD (to be discussed during grilling) |
| 2 — AI seam reshape | Defer to Pass 3 design | Pass 3 PRD (to be discussed during grilling) |
| 3 — RecommendationEngine | **Absorbed into Pass 3** as B-flavored (AI-narrative recommendations grounded in memory). Hardcoded `state.recommendations` getter removed; new `recommendationsProvider` reads connections + memory and produces ranked output with LLM-generated copy in the LLM path, deterministic copy in the mock path. | `docs/prd/2026-05-16-per-contact-memory-files-prd.md` (Absorbed scope section) |
| 4 — Conversation topics module extract | **Absorbed into Pass 3.** The extract from `crm_widgets.dart` to `lib/src/state/conversation_topics.dart` happens as the same change that swaps the data source from category-keyed defaults to memory-derived topics via `memoryTopicsProvider`. Static-map fallback stays as the empty-state path. | `docs/prd/2026-05-16-per-contact-memory-files-prd.md` (Absorbed scope section) |
| 5 — `InteractionType` Flutter leak | Defer | `docs/issues/039-architecture-deferred-cleanup-candidates.md` |
| 6 — By-id query providers shallow | Defer (path A or path B depending on whether candidate 1 lands) | `docs/issues/039-architecture-deferred-cleanup-candidates.md` |

### Decisions worth preserving for future architecture reviews

- **"Recommendations" is real product, not placeholder.** The product direction is B (AI-narrative copy grounded in memory), not A (heuristic-only) or C (cross-device push notifications). C is acknowledged as eventual future work tied to Firebase, but is post-Pass-3.
- **Five of six candidates pointed at Pass 3.** That trajectory is the signal that Pass 3 is the right time to design the deeper modules. Doing them piecemeal before Pass 3 would design in a vacuum; doing them as part of Pass 3 grilling grounds each architectural decision in concrete user stories.
- **Conversation topics module move is bundled with the data-source swap.** Doing the move-only refactor before Pass 3 would mean two touches (move now, replace later) instead of one cohesive change.
- **No ADR was filed.** The deferrals are *timing* decisions, not load-bearing design decisions — a future reviewer who re-surfaces these candidates would be correct to surface them, and the answer would be the same as today ("do it as part of Pass 3" or "small cleanup, see #039").

### What this means for Pass 3 grilling

When Pass 3 grilling opens, the conversation should explicitly cover candidate 1 (state-layer modularization), candidate 2 (AI seam shape — one deep `AiUpdate` module vs the PRD's parallel `MemoryUpdater`/`MemoryStore` plan), candidate 3 (where `RecommendationEngine` lives and how it composes with `MemoryUpdater`), and candidate 4 (the topics module extract as part of memory-driven topics). Candidates 5 and 6 stay deferred and should not be re-litigated in that conversation.
