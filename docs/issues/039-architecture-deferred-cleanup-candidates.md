# Architecture deepening review \u2014 deferred cleanup candidates

Labels: enhancement, needs-triage, refactor

> *Created 2026-05-18 from the architecture-deepening review session.*

## Parent

- Review notes: `docs/context/2026-05-18-architecture-deepening-scout.md`
- Pass 3 PRD: `docs/prd/2026-05-16-per-contact-memory-files-prd.md` (absorbs candidates 3 and 4)

## Background

The architecture-deepening review on 2026-05-18 surfaced six candidates.
Four were resolved during the review:

- **Candidate 3** (RecommendationEngine) \u2014 absorbed into Pass 3 (B-flavored: AI-narrative recommendations grounded in memory)
- **Candidate 4** (Conversation topics module extract) \u2014 absorbed into Pass 3 (the topics extract happens as the same change that swaps to memory-derived topics)
- **Candidate 1** (`AppController` split) \u2014 best designed during Pass 3 grilling
- **Candidate 2** (AI seam reshape) \u2014 best designed during Pass 3 grilling

Two remaining candidates are small, real, and not blocking anything.
They live here so they don't get lost.

## Candidate 5 \u2014 `InteractionType` extension methods leak Flutter into the model layer

### Files

- `lib/src/models/social_models.dart:1` (the `flutter/material.dart` import that exists *only* for the extension)
- `lib/src/models/social_models.dart:75-93` (the extension itself)
- Call sites: `lib/src/features/ai_update_screen.dart`, `lib/src/features/contact_profile_screen.dart`, `lib/src/ai/ai_update_service.dart:50`

### Problem

`InteractionType` has an extension attaching `.label` (String) and
`.icon` (IconData) to the enum. To do that, the model file imports
`package:flutter/material.dart`. Three follow-on issues:

1. The model layer is no longer Flutter-free. Any test wanting
   `InteractionType` pulls in the framework.
2. `MockAiUpdateService` uses `type.label` inside its `summary` string
   (`'Mock AI sorted this into ${type.label}...'`) \u2014 UI vocabulary
   leaking into AI output. This will compound when `LlmMemoryUpdater`
   lands.
3. The "type owns its rendering rules" reading is illusory. The rules
   are `IconData` (a Flutter class) and an English-only label \u2014 not
   data the model legitimately owns.

Apply the deletion test: delete `.label` and `.icon`. Three callers
need access to a label and an icon. They get it from a small
presentation registry (or pair of pure functions) in
`lib/src/widgets/`. The model goes back to pure data.

### Proposed fix

Move presentation off the enum. Introduce
`lib/src/widgets/interaction_type_presentation.dart` with `labelFor`
and `iconFor` pure functions. The AI service stops using `type.label`
for its narrative summary; it returns a structured result the UI
labels later, or uses a pure-data string.

### Acceptance criteria

- [ ] `lib/src/models/social_models.dart` no longer imports
      `package:flutter/material.dart`
- [ ] `InteractionTypeLabel` extension is removed
- [ ] New presentation module exposes `labelFor(InteractionType)` and
      `iconFor(InteractionType)`
- [ ] `MockAiUpdateService.summary` no longer references UI labels
- [ ] All call sites updated; existing widget tests stay green
- [ ] `flutter analyze` clean

### Blocked by

None \u2014 can be done any time. Naturally aligns with candidate 2 (AI
seam reshape) since both touch `MockAiUpdateService` summary strings;
worth bundling if candidate 2 happens.

## Candidate 6 \u2014 By-id query providers are shallow Riverpod hats

### Files

- `lib/src/state/query_providers.dart` (the four 5-7 line by-id
  providers)
- Consumers in `home_tab.dart`, `people_tab.dart`, `planner_tab.dart`,
  `contact_profile_screen.dart`, `recommendations_screen.dart`,
  `ai_update_screen.dart`

### Problem

`filteredContactsProvider` from #026 is genuinely deep \u2014 filter+sort
under a stable `ContactFilter` key, real logic behind a small
interface. The other four (`contactByIdProvider`, `eventByIdProvider`,
`interactionsByContactProvider`, `selectedDayEventsProvider`) are
each 5-7 line `state.connections.firstWhere(...)` wrappers.

Specifically, `contactByIdProvider` rebuilds an entire
`Map<String, Connection>` on every read for one lookup, then throws
the map away. It's claimed O(1) but is actually O(n) per read,
dressed up as O(1).

The shallowness is fine *today*. Five family providers is manageable.
Pass 3 will add `memoryProvider` and `memoryTopicsProvider` as
families. Future ranking, search, filter work each tend to add more.
If the file keeps growing one provider per call site, it becomes a
phonebook of thin wrappers.

### Proposed fix (two paths)

**Path A (small):** Replace by-id providers with one shared, memoized
read model: `connectionsIndexProvider` returning `Map<String, Connection>`
that's recomputed only when `connections` changes. By-id lookups
become `ref.watch(connectionsIndexProvider)[id]`. Same `.select`
leverage; one map, not five.

**Path B (broader):** Roll the by-id, by-day, by-contact lookups into
the domain modules from candidate 1. The Contacts module exposes
`byId`, the Planner module exposes `eventsOn(date)`. Riverpod
providers stay as integration glue but stop owning the indexing.

### Acceptance criteria

- [ ] Decision made between path A (this issue's scope) or path B
      (folded into candidate 1's scope during Pass 3)
- [ ] If path A: `connectionsIndexProvider` exists, by-id providers
      either deleted or rewritten as one-line wrappers
- [ ] O(1) lookup actually achieved (one map built when connections
      change, reused across all reads)
- [ ] `test/state/query_providers_test.dart` updated; existing
      coverage preserved or simplified

### Blocked by

None directly. If candidate 1 (`AppController` split) goes ahead,
this gets reshaped naturally as a side effect of the domain modules
exposing their own indexing \u2014 in that case path B applies and this
issue closes without separate work. Otherwise path A is the small
local fix.

## Notes

Both candidates are nice-to-have. Neither blocks Pass 3 implementation
nor any current product feature. Pickable independently when the team
wants a small architectural cleanup, or absorbed naturally if
candidate 1 lands as part of Pass 3.
