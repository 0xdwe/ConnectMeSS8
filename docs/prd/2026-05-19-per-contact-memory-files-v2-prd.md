# Per-Contact Memory Files with Agentic AI Updates — v2 (Pass 3, post-grilling)

Labels: prd, needs-triage

> Supersedes: `docs/prd/2026-05-16-per-contact-memory-files-prd.md`
> Grilling outcomes: Q1–Q13 from 2026-05-19 design conversation.
> Architecture context: `docs/context/2026-05-18-architecture-deepening-scout.md`

## Problem Statement

The v1 PRD shipped the right *idea* — per-contact narrative memory the AI accumulates and the profile screen reads — but the wrong *seam shape*. It introduced `MemoryUpdater` and `MemoryStore` as parallel public boundaries alongside the existing `AiUpdateService`, paying the integration tax twice (once for Pass 3, again when a real LLM lands) and splitting one user-level operation ("Update with AI on Sarah") across three coordinating modules. The grilling on 2026-05-19 also pulled adjacent absorbed scope into focus: the hardcoded `state.recommendations` getter needs a real engine grounded in memory, the buried topic helpers in `crm_widgets.dart` need to move during the same change that swaps their data source, and the v1 "memory failures don't block interactions" rule is the wrong default for an agent loop. v2 collapses the AI seam into a single `AiUpdate` module that returns interactions, memory, and summary together; promotes recommendations and conversation topics to first-class memory consumers; and replaces the soft-failure rule with all-or-nothing atomic updates. The data model, file format, and out-of-scope list from v1 carry through largely unchanged.

## Solution

A four-layer system, built bottom-up, each layer testable in isolation. The architectural pivot from v1 is at layer 3.

1. **Memory document layer.** `MemoryDocument` is a parsed representation of a per-contact markdown file with YAML frontmatter and narrative sections. Parses from string, renders back to string, round-trips losslessly. The new `Upcoming` section captures time-bound events the engine reads to surface "just got back" / "trip starts tomorrow" recommendations.

2. **Memory store layer.** `MemoryStore` owns persistence. Files live at `<app_documents>/memories/<contactId>.md`. Atomic temp-file-then-rename writes are what make layer 3's all-or-nothing contract real on disk. A name-shaped view exposes "Sarah Chen.md" semantics at the agent prompt boundary while disk uses stable contact ids. Two adapters today (file + in-memory); a third Firebase adapter is post-Pass-3.

3. **Unified `AiUpdate` layer (the v1→v2 pivot).** One public method, `run`, takes a contact + user input + current memory + attachments and returns an `AiUpdateResult` carrying `interactions`, `memoryDocument`, and `summary` together. This replaces v1's parallel `AiUpdateService` and `MemoryUpdater` boundaries. `MemoryDocument` and `MemoryStore` are still real types, but they are *private collaborators* of `AiUpdate`, not parallel public boundaries. One Mock adapter today; one future LLM adapter; one prompt to keep coherent. The user-level operation is what the seam shapes around, not the internal split between "categorize an interaction" and "write a memory file."

4. **UI integration layer.** Riverpod providers — `memoryStoreProvider`, `aiUpdateProvider`, `memoryProvider` (family, async, lazy), `memoryTopicsProvider` (family, derived), and `recommendationsProvider` (lazy with dual invalidation) — surface the data layer to the existing screens. The Pass 2 contact profile redesign already places the memory consumer surfaces (Person Summary, Conversation Topics pills) on the screen with category-keyed placeholder content; Pass 3 swaps the data source. The Pass 2 AI Update preview screen gains a read-only "About <Name> ✨" delta section so the user sees the memory append before committing.

A migration writes a seed memory file for every existing connection on first run. Statefulness is *filesystem-inferred*: empty memories directory means seed; non-empty means skip. No `shared_preferences` flag. The hardcoded `state.recommendations` getter is removed; Home and the recommendations screen read from `recommendationsProvider`. The `topicsForContact` and `suggestionsForTopic` helpers move out of `crm_widgets.dart` into a `ConversationTopics` module, with category-keyed defaults preserved as the empty-memory fallback and a templated fallback for memory-extracted topics with no curated suggestions.

## User Stories

1. As a busy professional, I want the app to remember context across "Update with AI" sessions, so that the second time I update Sarah's record the AI knows about the first conversation.
2. As a user with ADHD, I want a single readable narrative per person that I can scan on the profile screen, so that I am not piecing together history from a list of interaction tiles.
3. As any user, I want the Conversation Topics on a contact's profile to reflect things I have actually told the app about that person, so that the pills feel personal rather than generic.
4. As any user, I want every contact to start with a memory on first run, so that I am not staring at empty narrative cards on day one.
5. As any user, I want my memory files to survive app restarts, so that the AI's accumulated understanding of my relationships is durable.
6. As any user, I want to rename a contact without losing or scrambling their memory, so that "Sarah" becoming "Sarah Chen" does not break their accumulated history.
7. As any user, I want my memory files to be plain markdown I could open in any editor, so that nothing about the format is locked behind the app.
8. As any user, I want the app to gracefully tolerate a malformed or missing memory file, so that a parse error on one contact does not break the rest of the app.
9. As any user, I want deleting a contact to remove their memory file, so that stale memory does not linger on disk.
10. As any user, I want tapping a Conversation Topic pill to show suggested ways to continue that conversation, so that the topic surface earns its place on the screen.
11. As any user, I want suggestions on memory-extracted topics that the curated map doesn't cover, so that a personal topic like "violin lessons" still gets a useful prompt rather than going silent.
12. As any user, I want to see what the AI is about to add to my notes about a contact before saving, so that I can cancel if the parse looks wrong. *(Q5 — preview delta)*
13. As any user, I want canceling an AI update to discard both the interaction and the memory append, so that nothing leaks through after I said no. *(Q5 — preview cancels both)*
14. As any user, I want an AI update to either fully succeed or fully fail, so that I never end up with an interaction logged but the memory un-updated, or vice versa. *(Q4 — all-or-nothing)*
15. As any user, I want recommendations to reflect who I'm actually drifting from based on bond tier and recency, so that the Home screen stays useful as my real relationships change. *(Q11)*
16. As any user, I want the app not to re-recommend someone I just contacted yesterday, so that the recommendation list doesn't feel stale or repetitive. *(Q11 — 24h cooldown)*
17. As any user, I want a recommendation when a friend's trip is wrapping up or just ahead, so that "welcome back from the Iceland trip" is the kind of nudge the app actually catches. *(Q12 — upcoming events)*
18. As any user, I want recommendations to refresh after I update a contact, so that adding new memory immediately shifts who shows up next without me having to restart the app. *(Q2 — memory-change invalidation)*
19. As any user, I want recommendations to feel current even if I haven't updated anyone in a while, so that the list doesn't go stale on a quiet week. *(Q2 — 6h elapsed-time invalidation)*
20. As any user, I want my Conversation Topics pills to fall back to sensible category-default suggestions when a contact has no memory yet, so that day-one and day-one-thousand both feel populated. *(Q13 — empty-state fallback)*
21. As an evaluator (course grading), I want the prototype to demonstrate the agentic memory architecture even without a real LLM key configured, so that the design is visible regardless of network/API access. *(Mock determinism)*
22. As a developer, I want the AI seam shaped as one user-level operation (input + contact → interactions + memory + summary), so that swapping the deterministic mock for a real LLM later is a single adapter substitution rather than two coordinated swaps. *(Q1 — unified AiUpdate seam, the v1→v2 pivot)*
23. As a developer, I want memory file persistence behind an interface, so that swapping local files for a Firebase-backed store later is a one-class change. *(Firebase readiness)*
24. As a developer, I want recommendations behind a pure-function engine reading connections + interactions + memory, so that ranking changes are unit-testable and adding new signals doesn't require pumping a widget tree. *(Q11 — engine module)*
25. As a developer, I want conversation topics extracted from `crm_widgets.dart` into their own module *as part of the same change* that swaps the data source to memory, so that the move and the swap are one cohesive landing instead of two churny refactors. *(Absorbed candidate 4)*
26. As a developer, I want unit-test coverage on the parser, the store, the mock AI update, and the recommendation engine, so that changes to memory format or ranking heuristics do not silently regress.
27. As a developer, I want migration to be filesystem-inferred (empty memories directory means seed) rather than gated on a `shared_preferences` flag, so that there's one source of truth for "are memories seeded yet" and no risk of a flag and a directory disagreeing. *(Q9)*
28. As a developer, I want memory writes capped by size (per-contact and global), so that an unbounded agent update cannot fill the device.

## Implementation Decisions

The decisions below capture Q1–Q13 as binding implementation constraints. Module sketches are at the granularity needed for slicing into issues; concrete file paths and code structure are deliberately omitted.

**New dependencies.** Two pubspec entries land with Pass 3, both pinned to exact versions per the project's dependency policy:
- `yaml` — read-only YAML frontmatter parser for `MemoryDocument.parse`. Renderer is hand-written.
- `path_provider` — resolves `<app_documents>/memories/` for `FileMemoryStore`.

No other new dependencies. `shared_preferences` is explicitly not added (Q9). `firebase_core` is explicitly not added (Pass 4+).

### Q1 — AI seam shape (the v1→v2 pivot)

A single `AiUpdate` module replaces v1's parallel `AiUpdateService` + `MemoryUpdater` plan. One public interface, one method (`run`), one return type (`AiUpdateResult`) carrying `interactions`, `memoryDocument`, and `summary` together. `MemoryDocument` and `MemoryStore` still exist as data + persistence types, but they are private collaborators of `AiUpdate`, not parallel public boundaries. Two adapters: a deterministic `MockAiUpdate` for Pass 3, and a future `LlmAiUpdate` reserved for Pass 4. One Mock, one future LLM, one prompt to keep coherent.

### Q2 — Recommendations invalidation

Lazy with dual invalidation. `recommendationsProvider` caches a `(computedAt, List<Recommendation>)` tuple. Recompute on read when **either** any contact's memory has changed since `computedAt` **or** `now - computedAt > 6h`. Reads on Home and the recommendations screen are what trigger the freshness check. No background scheduler. The 6h window is the starting knob; 2h–24h is a reasonable range to tune within.

### Q3 — State-layer split scope

Carve out only `AiUpdate`. Contacts, Planner, and Session stay inside `AppController`. The 18-method controller shrinks by exactly the three AI methods (`previewAiUpdate`, `commitAiUpdate`, `runAiUpdate`), which move into the new `AiUpdate` module. `AppController.deleteConnection` gains one line: it cascades the delete to the memory store. `AppController` accordingly imports the memory store boundary for that one cascade — accepted trade. No Contacts/Planner module split lands in Pass 3; revisit when Firebase actually motivates it.

The `deleteConnection` cascade inherits the Q4 all-or-nothing contract: if `MemoryStore.delete` fails, the in-memory connection delete is reverted (or never applied) and the user sees a retryable error. We do not tolerate orphaned memory files; the contract is symmetric with `AiUpdate.run`'s save path.

`AppController.updateConnection` is responsible for keeping the memory file's `displayName` frontmatter in sync when a connection's display name changes. The rewrite is a no-op if no memory file exists yet (the lazy-creation path in `memoryProvider` will write the correct name on first observe). This satisfies user story 6 (rename safety) at the prompt-boundary level — when `LlmAiUpdate` lands and the prompt boundary substitutes `<Name>.md`, the frontmatter agrees with the contact record.

### Q4 — Failure contract

All-or-nothing. If any part of an `AiUpdate.run` fails — LLM call, memory parse, memory write, or interaction append — nothing persists and the user sees an error to retry. This *replaces* the v1 PRD's "memory failures don't block interactions" rule. In the Mock path, failures are essentially impossible; the contract earns its keep in Pass 4 once a real LLM is on the other end. The atomic temp-file-then-rename in the file store is what makes the contract real on disk: if the rename fails, neither memory nor interactions update.

**Ordering inside the commit path.** `AiUpdate` is responsible for both the disk write and the in-memory state delta. Order is: (1) compute the new memory document, (2) save via `MemoryStore.save` (atomic temp-rename), (3) on save success, apply the state delta that appends the new interactions. If step 2 fails, step 3 is skipped and the user sees an error. If step 3 throws after step 2 succeeded, the file rename has committed but the in-memory state hasn't — this is treated as a programmer error (covered by tests asserting step 3 does not throw under any state shape), not a recoverable failure mode.

### Q5 — Preview UX

The Pass 2 AI Update preview screen gains a new section below the interaction cards: **"About <Name> ✨"**. The section shows additions only — newly extracted topics highlighted, a 1–2 line summary of what's being appended to the History section. Read-only. No inline editing of the memory delta. The Pass 5 surface that does allow editing is explicitly out of scope (no memory editor UI ships in Pass 3).

Cancel on the preview screen discards the entire run — interactions and memory delta both. This is what the all-or-nothing contract from Q4 looks like at the UI seam, and it satisfies PRODUCT.md's preview-and-confirm principle without violating the "no memory editor UI" out-of-scope rule.

**Visual + motion spec.** The ✨ tag uses `primary` icon on `primary-tint` background, matching the existing AI marker convention from Pass 2. Newly extracted topics render as chips with `primary-tint` background and `ink` text plus a small `primary` left-accent dot — same color pair as the ✨ tag, contrast verified ≥4.5:1 against the surface. No vibrant secondary or tertiary fills carry text. The "About <Name> ✨" section participates in the existing AI preview stagger as the final card in the sequence (240ms ease-out-quart, 80ms offset per DESIGN.md → Motion → Budget). No separate highlight pulse, no new motion concept. Under reduced motion (`MediaQuery.disableAnimations`), all preview cards including this one appear instantly.

**Accessibility.** The section announces as "About <Name>, AI suggested" with a heading semantic. Each highlighted topic chip announces its label plus "newly added." Touch targets ≥44pt for any tappable affordance, though the section itself is read-only.

**Empty-additions edge case.** If a run produces zero topic additions and a no-op History append, the section is suppressed (not rendered as an empty card). Implementation may render a one-line placeholder instead at its discretion.

### Q6 — Memory file format

Markdown body with YAML frontmatter, parsed via the `yaml` package (new dependency in `pubspec.yaml`, read-only parser). The renderer is hand-written — no YAML writer dependency.

Frontmatter fields: `contactId`, `displayName`, `lastUpdated`, `version`.

Body sections, all delimited by H2 headers:
- `## Summary` — narrative paragraph for Person Summary on the profile.
- `## History` — longer narrative, append-only across updates.
- `## Preferences` — optional preferences and channel notes.
- `## Topics` — bullet list of strings; deduped on parse, lowercased for matching, original case preserved for display. Capped at 8 entries; `MemoryDocument.render` truncates to the most-recent 8 deduped topics, dropping the oldest first.
- `## Upcoming` (new — see Q12) — bullet list of `{startDate, endDate?, description}` entries.

**Cap behavior.** Per-contact files are capped at 64KB. When a write would exceed the cap, the oldest History bullets are dropped until the file fits. If the file still exceeds 64KB with zero History bullets remaining (e.g., a pathologically large `## Summary`), the write fails with a cap-exceeded error and `AiUpdate.run` reports failure under the Q4 contract. Global cap is 16MB across all memory files combined; hitting it surfaces the same cap-exceeded error. Pass 3 does not auto-evict across contacts.

Parse is total — `MemoryDocument.parse` never throws. Malformed frontmatter or unparseable sections populate a `parseErrors` list on the document for debugging without breaking the UI. `render` round-trips every parseable document.

### Q7 — Mock topic extraction

Roughly 40 hand-curated keywords with substring matching. Categories the keyword list covers: family, career, location, health, hobbies, milestones. Deterministic — same input always produces the same extracted topics. The keyword list is owned by the Mock adapter and goes away when the LLM lands.

### Q8 — Dependency injection

Riverpod providers. New providers:
- `memoryStoreProvider` — returns the file-backed store in production, overridable to the in-memory store in tests.
- `aiUpdateProvider` — returns `MockAiUpdate` in Pass 3, overridable to `LlmAiUpdate` later (and to a stub in tests).
- `memoryProvider` — family by `contactId`, async; lazy-creates an empty document via the store on null.
- `memoryTopicsProvider` — family by `contactId`, derived from `memoryProvider`; returns memory topics or the empty list.
- `recommendationsProvider` — lazy with the Q2 dual invalidation (memory-change OR 6h elapsed).

The existing `aiUpdateServiceProvider` is **removed** — it is replaced by `aiUpdateProvider`. Tests use `ProviderScope(overrides: [...])` to swap in test doubles, matching the existing Riverpod test pattern in the codebase.

### Q9 — Migration

Filesystem-inferred state. No `shared_preferences` flag. On startup, the bootstrap path checks the memories directory: if empty, run the seed migration that writes one memory file per existing connection (constructed from the connection's seeded `notes`, category, and a small starter topics list). If non-empty, skip. There is one source of truth for "are memories seeded yet": the directory contents.

User-created connections added between Pass 2 and Pass 3 — i.e., connections without a corresponding memory file at startup — get an empty memory document on first observe via lazy creation in the memory provider.

The seed pass is best-effort, not all-or-nothing. If seeding 6 of 11 connections succeeds and then disk fills, the directory is non-empty on next launch and the seed pass is skipped — but the lazy-creation path in `memoryProvider` produces empty documents for any still-unbacked connection on first observe. The two paths together cover any partial-failure state without a separate retry mechanism.

### Q10 — `ContactInsight` cleanup

Delete `ContactInsight.summary` and `ContactInsight.why`. Person Summary on the contact profile reads from `MemoryDocument.summary`. The "why now" copy on recommendations is generated by the recommendation engine. The remaining `ContactInsight` fields (`daysSinceContact`, `frequencyTotal`, `_potentialGain`, etc.) are audited at implementation time: keep what still has callers, delete what doesn't.

### Q11 — Recommendation ranking

Bond-tier-weighted recency, with a 24-hour cooldown filter. Score formula:

- `score = daysSinceContact * tierWeight`
- `tierWeight = { drifting: 1.5, steady: 1.0, close: 0.8 }`
- Filter out any contact with `daysSinceContact < 1` (the 24h cooldown — don't re-recommend someone you just talked to).
- Top N = 3.

The Mock path uses this exact formula and produces deterministic narrative copy keyed off bond tier and recency. The future LLM path uses the *same* ranking and only generates warmer narrative copy from memory context for the top 3 — the math is shared so swapping adapters does not move the recommendations.

**Anti-shame copy guardrail (PRODUCT.md → Design Principles #1).** Generated copy is question-shaped or wondering-shaped, matching PRODUCT.md's voice (e.g., "Wondering how Mike's job hunt went?"). Numeric day counts are never rendered to the user. Copy uses bond tier and rough recency buckets (e.g., "a few weeks ago," "it's been a while") instead of "67 days." A test asserts no engine-rendered string contains a numeric day count or a guilt-shaped phrase.

### Q12 — Time-bound events

The `## Upcoming` section is part of the memory format. Each entry carries a start date, an optional end date, and a free-text description. The parser, renderer, and round-trip tests all support it.

The Mock updater leaves the `Upcoming` section **empty** — extracting "tomorrow" / "for a week" deterministically is too brittle for the Mock. The LLM populates it in Pass 4.

The `RecommendationEngine` reads `Upcoming` and produces special "just got back" / "trip starts tomorrow" recommendation cards when an entry's `endDate` (or `startDate` if no end) falls in the window `[now - 3d, now + 1d]`. The engine logic ships in Pass 3 even though the Mock path can't trigger it, so Pass 4 doesn't have to revisit the engine when it gains the ability to populate `Upcoming`.

### Q13 — Topic suggestions

A static curated map for known topics (e.g., `promotion`, `wedding`, `kindergarten`) plus a templated fallback for memory-extracted topics that don't hit the static map. The three rotating templates are roughly:

- "How's the {topic} going?"
- "Last time you mentioned {topic} — anything new?"
- "Curious how {firstName}'s {topic} is going."

Templates use `{topic}` and `{firstName}` slots only. The conversation topics module exposes two pure functions: one returning topics for a contact (memory topics if present, category-default fallback if empty), and one returning suggestions for a (category, topic) pair (curated map first, templated fallback otherwise).

### Module sketch

The above decisions land in the following modules. The shape is binding; the concrete file layout is an implementation detail.

- **`MemoryDocument`** — immutable model. Fields: `contactId`, `displayName`, `lastUpdated`, `version`, `summary`, `history`, `preferences`, `topics`, `upcoming` (list of `{startDate, endDate?, description}`), `parseErrors`. `parse(String)` is total. `render() → String` round-trips. `empty(contactId, displayName)` constructor for fresh memories.

- **`MemoryStore`** — async interface. Methods: `load(contactId)`, `save(contactId, doc)`, `delete(contactId)`, `listAll()`. Two adapters today: a file-backed store with atomic temp-file-then-rename writes, contact-id-stable on disk, and name-shaped at the agent prompt boundary; and an in-memory store for tests. Per-contact 64KB cap, global 16MB cap.

- **`AiUpdate`** — unified interface (the Q1 pivot). Single method `run({contact, userInput, currentMemory, attachments}) → AiUpdateResult`. The result carries interactions, memory document, and summary together; all-or-nothing. Adapters: `MockAiUpdate` (deterministic, owns the keyword list and history-append logic) and `LlmAiUpdate` (Pass 4+, not implemented).

- **`RecommendationEngine`** — pure-function shape. Inputs: connections, interactions, per-contact memory map, `now`. Output: ranked list of recommendations. Owns Q11 ranking, Q12 upcoming-event detection, and (for the Mock path) deterministic narrative copy generation. The hardcoded `AppState.recommendations` getter is removed in favor of this engine plus `recommendationsProvider`.

- **`ConversationTopics`** — pure-function module (absorbed candidate 4). Two public functions: topics-for-contact (memory topics with category-default fallback) and suggestions-for-topic (curated map with templated fallback). File-private static maps for category defaults and curated suggestions. The move out of the widgets file happens as the same change that swaps the data source to memory.

- **Riverpod providers** — `memoryStoreProvider`, `aiUpdateProvider`, `memoryProvider` (family, async, lazy-creates an empty document on null), `memoryTopicsProvider` (family, derived from `memoryProvider`), `recommendationsProvider` (lazy with the Q2 dual invalidation).

- **`AppController` changes** — remove the three AI methods (move to `AiUpdate`); `deleteConnection` cascades to the memory store; remove the hardcoded `state.recommendations` getter; remove `ContactInsight.summary` and `.why`.

- **Pass 2 ↔ Pass 3 UI surfaces** — contact profile Person Summary reads memory summary; Conversation Topics pills read from `memoryTopicsProvider` with category-default fallback; AI Update preview gains the "About <Name> ✨" read-only delta section; Home and the recommendations screen read from `recommendationsProvider` instead of the deleted hardcoded getter.

## Testing Decisions

**Good tests verify external behavior, not implementation details.** A memory document parses, renders, and round-trips. A store loads what it saves. A `MockAiUpdate.run` produces deterministic output for a given input, and the result either fully persists or doesn't persist at all. A `RecommendationEngine` ranks correctly given a fixture of connections + interactions + memories. None of these tests should care how the agent loop is structured internally, only what comes out the other side.

Coverage to ship with Pass 3:

**`MemoryDocument` parser/renderer.**
- Round-trip on a full document with every section populated.
- Missing optional sections parse without error.
- Malformed frontmatter populates `parseErrors` and the rest of the document still parses.
- Empty file produces an empty document.
- Topics deduplication and the topic count cap are respected on render.
- The new `## Upcoming` section round-trips, including entries with and without `endDate`.

**`MemoryStore`.**
- In-memory store: save then load round-trips; delete removes; `listAll` returns all saved; `load` on an unknown id returns null. This is the bulk of the store coverage.
- File store: smoke test using a temp directory exercising the atomic write path.

**`MockAiUpdate`.**
- Given an empty memory + a known input, produces an expected `AiUpdateResult` (specific topics extracted, history bullet appended, lastUpdated changed).
- Determinism: same input twice produces the same output.
- Topic count cap of 8 is enforced.
- Per-contact size cap drops oldest history bullets rather than rejecting the write.
- A document that still exceeds 64KB with zero history bullets fails the write with a cap-exceeded error.
- All-or-nothing failure surface is documented at the test level: a failure injected into the Mock causes neither memory nor interactions to be present in the result.

**`RecommendationEngine`.**
- Q11 ranking produces the expected order on a fixture covering all three bond tiers and a range of recencies.
- 24-hour cooldown filter excludes recently-contacted connections.
- Deleted-contact ids never appear in the output (regression coverage for the v1 stale-id behavior).
- An `Upcoming` entry whose endDate falls in the window produces the special "just got back" / "trip starts tomorrow" recommendation card.
- A connection with a parse-errored or empty memory still ranks via tierWeight × daysSinceContact; only the upcoming-event branch is skipped.
- Mock recommendation narrative copy is deterministic for the same input.
- Anti-shame guardrail: no engine-rendered string contains a numeric day count or guilt-shaped phrase (asserted across the fixture set).

**Provider tests.**
- `memoryProvider` lazy-creates an empty document on null and returns the parsed document on a known id.
- `memoryTopicsProvider` derives correctly from `memoryProvider` and returns the empty list when no memory is present.
- `recommendationsProvider` recomputes when any contact's memory changes since the cached `computedAt`.
- `recommendationsProvider` recomputes when more than 6h has elapsed since `computedAt`.
- `recommendationsProvider` returns the cached list without recomputation when neither invalidation condition is met.

**Integration tests** (in `test/features/`).
- AI Update flow on a contact with no prior memory creates memory + interactions atomically.
- A second AI Update appends to history without overwriting prior entries.
- The AI Update preview screen displays the "About <Name> ✨" delta section before save.
- Cancel on the preview discards both interactions and memory changes (the all-or-nothing UI surface).

**`ConversationTopics`.**
- Pure-function tests on both public functions, including the category-default fallback for empty memories and the templated fallback for memory-extracted topics with no curated suggestions.

**Prior art to follow.** `test/state/query_providers_test.dart` is the model for family-provider tests and the `ProviderContainer` pattern. `test/features/ai_update_preview_test.dart` is the model for AI flow integration shape. `test/state/app_state_test.dart` is the model for controller cascade tests.

## Out of Scope

Carried through from v1, with adjustments per the grilling.

- **Real LLM integration.** `LlmAiUpdate` is referenced as a future class but not implemented. API key UX, provider selection, error/retry, and cancellation all land in Pass 4 alongside the LLM adapter.
- **API key management UX.** Where the key is entered, where it lives, how it's rotated. Pass 4 work.
- **Firebase backend, multi-device sync, conflict resolution.** Pass 3 is single-device. The store interface is shaped to make a third Firebase adapter cheap, but no Firebase-backed implementation ships.
- **Memory editor UI.** No screen lets the user hand-edit a memory file inside the app. Pass 3 surfaces memory read-only on the contact profile and read-only in the AI Update preview delta. All memory mutations go through `AiUpdate.run`.
- **Memory export / import / sharing UI.** The files are plain markdown on disk and accessible there, but no in-app surface ships.
- **Structured topic taxonomies.** Topics are flat strings. No hierarchical tags, no topic-based contact filtering, no autocomplete in the AI Update input.
- **Real-time agent loop progress UI.** No "agent is reading memory… agent is updating topics…" indicator. The Mock is fast enough to ignore; the LLM updater can revisit when it lands.
- **Versioned memory history / undo across multiple updates.** `lastUpdated` and `version` are informational. There is no per-revision history and no multi-step undo. The all-or-nothing contract gives single-update undo for free (cancel the preview).
- **Background recommendation scheduling.** The Q2 lazy + 6h dual invalidation is the Pass 3 model. Cron-style or push-notification-style refresh is Pass 4+ Firebase work.
- **`InteractionType` Flutter leak cleanup.** Deferred per `docs/issues/039-architecture-deferred-cleanup-candidates.md`. Not a Pass 3 deliverable.
- **By-id query providers reshape.** Deferred per `docs/issues/039`. Not a Pass 3 deliverable.
- **Splitting `AppController` further.** Per Q3, only `AiUpdate` carves out. Contacts / Planner / Session stay inside `AppController`. Revisit when Firebase actually motivates it.

## Further Notes

The `<Name>Memory.md` semantics the user originally asked about are preserved at the agent prompt boundary. When `LlmAiUpdate` lands and is wired to a real model, the prompt and any tool calls reference "Sarah Chen.md" — which is what the user wanted for clarity in agent reasoning. The compromise is purely about disk durability under renames and collisions: ids on disk, names in the prompt.

The Pass 2 contact profile redesign is the natural visual home for Pass 3's data. Pass 2 ships first with category-keyed topic placeholders. The two passes are deliberately decoupled: Pass 2 is a visual reskin, Pass 3 is an architectural feature. Bundling them would have made both larger and riskier.

Pass 3's Mock-updater path is not throwaway. It exercises the full pipeline (file I/O, parser, agent interface, provider invalidation, UI rebuild, recommendation engine) and gives evaluation runs deterministic behavior. When `LlmAiUpdate` arrives, the only changed surfaces are the AI adapter and its provider override. Every other module — store, document, providers, UI, recommendation engine — stays put.

This PRD does not file a separate ADR. The deferrals captured here (no Contacts/Planner split, no `InteractionType` cleanup, no by-id provider reshape, no Firebase work) are *timing* decisions, not load-bearing design decisions. A future reviewer who re-surfaces these candidates would be correct to surface them; the answer at that point would be "do them when the next persistence shape forces the conversation," not "we already decided no."

### Firebase readiness considerations

Firebase is **Pass 4 or later**, not Pass 3. The Pass 3 scope is in-memory state plus local file persistence for memories only. This section captures what Pass 3 should and should not do to make Pass 4's Firebase integration cheap, without speculatively designing for it. The shape carries through from v1 unchanged.

**Where things actually sit today.**

| Layer | Today (after Pass 1+2) | Pass 3 (this PRD) | Pass 4+ (not designed) |
|---|---|---|---|
| Storage | In-memory; `signOut` resets to `AppState.seeded()` | Per-contact `.md` files via `path_provider`, local device only. Memory is the *first* persisted thing in the codebase. | Firebase Firestore for state; Firebase Storage / Firestore for memory files; cross-device sync. |
| Auth | Mock — any email/password works | Still mock | Firebase Auth replaces the mock |
| AI | `MockAiUpdateService` (string-match categorizer, no LLM) | `MockAiUpdate` deterministic; `LlmAiUpdate` interface ready but not wired | Real LLM (Anthropic/OpenAI/Gemini) with API key UX |

**What Pass 3 does for Firebase readiness (lightly, not speculatively).**

- **First real persistence seam.** Pass 3 introduces `MemoryStore` with two adapters (file + in-memory). That's a real seam by the "two adapters = real seam" rule. When Pass 4 lands, a Firebase adapter is a third implementation satisfying the same interface. One adapter swap; the rest of the system is unaffected.
- **`MemoryStore` is async.** Every method returns a `Future`. The file store could technically be synchronous, but the interface is async so a future Firebase adapter doesn't force a sync→async re-shape at every call site.
- **`MemoryStore` operations are idempotent and atomic.** `save` writes via temp file then rename; `delete` is safe to retry. These properties carry forward as Firebase contract requirements.
- **Memory file path is contact-id stable.** A contact id maps cleanly to a Firestore document key. Renaming a contact does not require any file or document migration.
- **`AiUpdate` is the network-handling seam (Q1 pivot).** When the real LLM lands, retry, timeout, cancellation, and offline behavior all live on one module's surface, not split across two parallel boundaries the way the v1 PRD would have shaped them.

**What Pass 3 does NOT do for Firebase readiness (deliberate restraint).**

- **No generic `Repository` or persistence abstraction.** Pass 3 has two adapters for memory only — that's a real seam scoped to memory. Generalizing across all of `AppState` now would be premature.
- **No pre-async-ifying `AppController`.** Mutators are still synchronous `copyWith` calls. Wrapping them in `Future` now adds boilerplate without payoff.
- **No `firebase_core` dependency added to `pubspec.yaml`.** Adding the SDK before any Firebase code is written is dead weight.
- **No offline-cache design, no security-rules sketch, no Firestore schema.** All of these benefit from real Firebase decisions that haven't been made yet.
- **No multi-device conflict resolution logic.** Pass 3 is explicitly single-device.

**Posture.** Treat "Firebase readiness" as a named constraint on Pass 3 decisions, not as license to add abstractions for hypothetical Pass 4 needs. The Q1 pivot to a unified `AiUpdate` module is itself partly Firebase-readiness motivated: a real LLM call gets one place to add network handling rather than two.
