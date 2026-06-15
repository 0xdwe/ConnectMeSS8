# Widget Rebuild / State Retention Investigation — AiInsightsCard Banner

## Files Examined

1. `lib/src/widgets/crm_widgets.dart` (lines 1111–1514) — full AiInsightsCard / _AiInsightsBody hierarchy
2. `lib/src/features/contact_profile_screen.dart` (lines 1–400) — contact profile screen build + AiInsightsCard usage
3. `lib/src/app/connect_me_app.dart` (lines 1–100) — GoRouter configuration
4. `lib/src/state/memory/memory_providers.dart` (lines 1–313) — recommendationsProvider, memoryEpochProvider, caching
5. `lib/src/features/ai_update_screen.dart` (lines 400–420) — save flow + Navigator.pop
6. `lib/src/features/tabs/home_tab.dart` (lines 1–180) — recommendation card navigation
7. `lib/src/features/shell_screen.dart` (full) — no ShellRoute (plain tabs)

## Architecture Overview

```
GoRouter stack:
  /app (ShellScreen → HomeTab/PeopleTab/PlannerTab/YouTab)
  /contact/:id (ContactProfileScreen → AiInsightsCard → _AiInsightsBody)
  /ai-update/:id (AiUpdateScreen)

Data flow for recommendation banner:
  memoryEpochProvider bump
    → recommendationsProvider invalidates (FutureProvider, 6h freshness cache)
      → Consumer inside _AiInsightsBodyState.build() rebuilds
        → maybeWhen(data: list.filter(contactId), orElse: null)
```

Navigation preserves state: GoRouter without ShellRoute keeps pushed pages alive in the Navigator stack. When returning from AI Update to contact profile, the existing `ContactProfileScreen` and its child widget states survive.

---

## Issues Found

### 🔴 ISSUE 1: `_selectedTopic` never updates on `didUpdateWidget` (stale state bug)

**File:** `lib/src/widgets/crm_widgets.dart`, line 1340

```dart
class _AiInsightsBodyState extends State<_AiInsightsBody> {
  late String? _selectedTopic = widget.initialSelectedTopic;
```

**Problem:** `_selectedTopic` is a `late` field initialized once from `widget.initialSelectedTopic`. There is **no `didUpdateWidget` override** in `_AiInsightsBodyState`. When the parent rebuilds with a new `initialSelectedTopic` (e.g., navigating from Home recommendation card to `/contact/123?topic=Travel`), the existing state receives the new widget via `didUpdateWidget`, but `_selectedTopic` remains at its old value.

**Impact:** If the user navigates to the same contact profile with a different `initialSelectedTopic` query parameter, the selected topic pill won't reflect the new initial value. In normal usage `initialSelectedTopic` is null, so this is low-severity but a genuine stale-state bug.

**Fix:** Add a `didUpdateWidget` override that resets `_selectedTopic` when `initialSelectedTopic` changes, or remove the `late` and derive from widget:

```dart
String? get _selectedTopic => _stateSelectedTopic ?? widget.initialSelectedTopic;
```

**No `didUpdateWidget` exists at all** in either `_AiInsightsCardState` or `_AiInsightsBodyState`. The build methods read from `widget.xxx` directly, which works for most props (Flutter updates `this.widget` before calling `build`). But `_selectedTopic` is local state — it's the one field that would need resetting.

---

### 🟡 ISSUE 2: Recommendation banner disappears during async recomputation (flash)

**File:** `lib/src/widgets/crm_widgets.dart`, lines 1349–1360

```dart
Consumer(
  builder: (context, ref, child) {
    final recommendationsAsync = ref.watch(recommendationsProvider);
    final recForThisContact = recommendationsAsync.maybeWhen(
      data: (list) => list
          .where((r) => r.contactId == widget.connection.id)
          .firstOrNull,
      orElse: () => null,
    );
    if (recForThisContact == null) {
      return const SizedBox.shrink();  // <-- hides banner during loading
    }
```

**Problem:** `recommendationsProvider` is a `FutureProvider`. When it's invalidated (e.g., after AI Update bumps `memoryEpochProvider`), it enters `AsyncLoading` state. The `maybeWhen(data: …, orElse: () => null)` pattern returns `null` during loading, and the Consumer renders `SizedBox.shrink()`. The banner **disappears briefly** before the async recomputation completes and the banner re-appears with updated data.

**Impact:** After returning from AI Update, the user sees the recommendation banner flash out and back in. This is standard async behavior but may be perceived as a glitch or "not updating" if the user isn't looking at the exact moment the new data arrives.

**Mitigation:** Consider showing a `loading` branch in `maybeWhen` that renders a skeleton/shimmer instead of `SizedBox.shrink()`, or use `maybeWhen(loading: () => _SkeletonBanner(), data: …, orElse: …)`.

---

### 🟡 ISSUE 3: No key on `AiInsightsCard` in `ContactProfileScreen`

**File:** `lib/src/features/contact_profile_screen.dart`, line 314

```dart
AiInsightsCard(
  connection: person,
  insight: insight,
  memorySummary: memorySummary,
  memory: memory,
  initialSelectedTopic: initialSelectedTopic,
),
```

**Problem:** No explicit `key` is provided. Flutter matches by widget type and position in the tree. In current navigation patterns, this works correctly — each contact profile is a separate GoRouter page entry, so navigating between contacts creates new widget instances. However, if the widget's position in the tree ever changes (e.g., conditional rendering above it), Flutter could mismatch the state.

**Severity:** Low risk in current codebase. `AiInsightsCard` is always present at the same position in the `ListView` children list.

---

### 🟡 ISSUE 4: `_AiInsightsCardState` is a `ConsumerState` but doesn't watch providers in `build()`

**File:** `lib/src/widgets/crm_widgets.dart`, line 1140

```dart
class _AiInsightsCardState extends ConsumerState<AiInsightsCard> {
  // ...
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    // No ref.watch here — only widget.xxx
```

**Observation:** The state extends `ConsumerState` (which gives it access to `ref`) but only uses `ref` in `_handleRefresh()`. The build method relies entirely on parent-to-child prop passing (`widget.connection`, `widget.insight`, etc.). The actual `ref.watch` for `recommendationsProvider` happens inside the `Consumer` widget nested inside `_AiInsightsBodyState.build()`.

**This is architecturally mixed but not a bug.** The data flow is:
1. `ContactProfileScreen` (ConsumerWidget) watches `contactByIdProvider`, `memoryProvider`, `appControllerProvider`, `interactionsByContactProvider`
2. When these change, `ContactProfileScreen` rebuilds → passes updated props to `AiInsightsCard`
3. `_AiInsightsCardState.build()` reads updated props → passes to `_AiInsightsBody`
4. Consumer inside `_AiInsightsBodyState.build()` independently watches `recommendationsProvider`

The two watch mechanisms (parent ConsumerWidget + child Consumer widget) are independent but both function correctly.

---

### ✅ VERIFIED: Consumer scope is correct

**File:** `lib/src/widgets/crm_widgets.dart`, line 1352

```dart
Consumer(
  builder: (context, ref, child) {
    final recommendationsAsync = ref.watch(recommendationsProvider);
```

The Consumer is scoped to just the recommendation banner. When `recommendationsProvider` changes, only this subtree rebuilds — the Person Summary and Conversation Topics sections do not rebuild unnecessarily. This is the correct, localized Riverpod pattern.

---

### ✅ VERIFIED: No `GlobalKey`, `PageStorageKey`, or `AutomaticKeepAliveClientMixin`

Searches across `lib/` found zero instances in `crm_widgets.dart`, `contact_profile_screen.dart`, or any other file. No artificial state preservation mechanisms interfere with the natural widget lifecycle.

---

### ✅ VERIFIED: `setState` usage doesn't block rebuilds

**File:** `lib/src/widgets/crm_widgets.dart`

Three `setState` calls exist:
- Line 1149: `setState(() => _isRefreshing = true)` — inside `_handleRefresh()`, guarded by `if (_isRefreshing) return`
- Line 1184: `setState(() => _isRefreshing = false)` — in `finally` block
- Line 1204: `setState(() => expanded = !expanded)` — toggle expand/collapse

None of these prevent parent-triggered rebuilds or block the Consumer from reacting to provider changes.

---

### ✅ VERIFIED: GoRouter navigation preserves state correctly

The GoRouter configuration (`connect_me_app.dart`, lines 18–46) uses plain `GoRoute` entries without `ShellRoute` or `StatefulShellRoute`. When navigating from `/contact/:id` to `/ai-update/:id` via `context.push()`:

1. The contact profile page stays alive in the Navigator stack (hidden behind AI Update)
2. `ContactProfileScreen`'s `ref.watch` subscriptions remain active
3. When `memoryEpochProvider` is bumped by AI Update commit, all watchers (including `recommendationsProvider`) are invalidated
4. On `Navigator.pop()`, the contact profile is revealed — it either already rebuilt (while hidden) or rebuilds on the next frame with fresh data

---

## Recommendations

1. **Fix `_selectedTopic` stale state** (Issue 1): Add `didUpdateWidget` override or use a pattern that derives from widget.

2. **Add a loading state for the recommendation banner** (Issue 2): Replace `orElse: () => null` with an explicit loading branch to avoid the flash:
   ```dart
   loading: () => const _RecommendationSkeleton(),
   data: (list) => { /* current logic */ },
   error: (_, __) => const SizedBox.shrink(),
   ```

3. **Consider adding a `Key` to `AiInsightsCard`** (Issue 3): Add `key: ValueKey('ai-insights-${person.id}')` for safety, though not strictly necessary with current navigation patterns.

4. **Consider consolidating provider watches** (Issue 4): Either move `recommendationsProvider` watch to `ContactProfileScreen` and pass the filtered recommendation as a prop, or convert `_AiInsightsBody` to a `ConsumerWidget` to simplify the architecture. Not a blocking issue.

---

## Start Here

Open `lib/src/widgets/crm_widgets.dart` at line 1339 (`class _AiInsightsBodyState`) — this is the core of the stale-state issue and the recommendation banner rendering.
