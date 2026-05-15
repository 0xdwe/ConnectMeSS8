# Code Context

## Files Retrieved
1. `lib/main.dart` (lines 1-7) - app entry; global `ProviderScope`.
2. `lib/src/app/connect_me_app.dart` (lines 1-35) - router/theme root; routes bind UI directly.
3. `lib/src/state/app_state.dart` (lines 1-520) - central Module: seeded data, derived data, mutations, AI orchestration.
4. `lib/src/models/social_models.dart` (lines 1-260) - data types + UI-ish labels/icons mixed into model layer.
5. `lib/src/ai/ai_update_service.dart` (lines 1-55) - lone Interface/Implementation seam for AI.
6. `lib/src/features/shell_screen.dart` (lines 1-220) - shell/nav, action menu, modal launches.
7. `lib/src/features/tabs/home_tab.dart` (lines 1-36) - UI reads whole state, derives rec cards inline.
8. `lib/src/features/tabs/people_tab.dart` (lines 1-78) - search/filter/sort in widget state.
9. `lib/src/features/tabs/planner_tab.dart` (lines 1-218) - calendar/query/edit/delete/undo coupled in UI.
10. `lib/src/features/contact_profile_screen.dart` (lines 1-260) - profile UI + insight/history lookup.
11. `lib/src/features/modals/add_event_modal.dart` (lines 1-292) - form state + event construction + persistence.
12. `lib/src/features/ai_update_screen.dart` (lines 1-68) - file picker Adapter missing; UI calls platform API direct.
13. `lib/src/features/modals/shared_activity_modal.dart` (lines 1-156) - form + AI suggestion text + mutation direct.
14. `lib/src/features/auth_screen.dart` (lines 1-55) - mock auth in UI.
15. `test/state/app_state_test.dart` (lines 1-169) - controller unit tests cover central mutations only.
16. `test/widget_test.dart` (lines 1-268) - broad widget tests via real app/provider; limited seams.

## Key Code
- `lib/src/state/app_state.dart`:
  - `AppState` = all session state: auth/theme/tab/user/connections/interactions/events/categories/eventTypes/calendar/AI summary.
  - `AppState.seeded()` hardcodes demo DB + `DateTime.now()` → low reproducibility, no persistence Adapter.
  - `recommendations` hardcoded list, not domain service → shallow feature Module.
  - `contactInsightFor()` computes analytics inside state object; uses `DateTime.now()`, `firstWhere` throws on bad id.
  - `AppController extends Notifier<AppState>` owns every command: auth, nav tab, profile, contact CRUD, event CRUD, category/type mgmt, shared activity, AI update.
  - `runAiUpdate()` only real seam: `ref.read(aiUpdateServiceProvider).categorizeAndUpdate(...)` then mutates contacts/interactions.
- `lib/src/ai/ai_update_service.dart`:
  - `abstract class AiUpdateService` good Interface.
  - `MockAiUpdateService` keyword classifier; no real Adapter boundary for LLM/config/network.
- `lib/src/models/social_models.dart`:
  - Domain models import `package:flutter/material.dart`; `InteractionType.icon` returns `IconData` → model/UI coupling.
  - Manual immutable-ish classes; no serialization/equality; test assertions rely fields only.
- UI coupling examples:
  - `PeopleTab.build()` filters/sorts inline from `ref.watch(appControllerProvider)`.
  - `PlannerTab.build()` queries selectedEvents, contact lookup, delete+undo, calendar state all in widget.
  - `AddEventModal` builds `PlannerEvent` + calls `saveEvent()` directly; static `Uuid` duplicated.
  - `AiUpdateScreen.pick()` calls `openFiles()` direct; hard to fake in widget tests.

## Architecture
- Current shape: single deep-ish `AppController` + many shallow feature widgets. Leverage centralized mutations, but low Locality: unrelated domains change same file (`app_state.dart`).
- Modules: `models`, `state`, `ai`, `features`, `widgets`, `theme`. Most feature Modules are presentation-only; business rules live in global state or widget build methods.
- Interfaces/Adapters: only `AiUpdateService` Provider exists. Missing seams for clock, UUID, storage/repository, auth, calendar sync, file picker, recommendations/insights engine.
- Depth opportunities:
  - Split domain services: `ContactsService`, `PlannerService`, `InsightsService`, `RecommendationsService` behind providers.
  - Add repository Interface for persistence; seeded data becomes `DemoRepository` Implementation.
  - Add `Clock` + `IdGenerator` Interfaces → deterministic tests.
  - Move UI labels/icons to presentation adapters/extensions, keep domain model Flutter-free.
  - Derived selectors/providers for filtered people, selected-day events, contact lookup, insight/recs → less rebuild/coupling.
- Hard-to-test seams:
  - Platform file picker direct in `AiUpdateScreen`.
  - Modal form logic not extracted; tests must pump UI to exercise validation/construction.
  - Navigation direct `context.push/go` in screens; no route guard despite `isAuthed`.
  - `DateTime.now()` scattered in seed/logic; tests time-dependent.
- Shallow modules:
  - `auth_screen.dart`: mock auth only, no auth Interface.
  - `recommendations` state getter: static data, not linked to interactions/events.
  - `PlannerTab` calendar grid local impl; no reusable calendar domain abstraction.
- Risks:
  - `firstWhere` in profile/home/insights can crash after stale route/id deletion.
  - AppState copyWith cannot set `lastAiSummary` to null intentionally.
  - `selectedTab` global session state couples nav UI to domain state.

## Start Here
Open `lib/src/state/app_state.dart` first. It is the high-leverage seam: global state, seeded DB, domain rules, mutations, AI orchestration. Refactor outward from there into Interfaces/Implementations/Adapters while preserving Riverpod API for UI.

## Supervisor coordination
Not needed.
