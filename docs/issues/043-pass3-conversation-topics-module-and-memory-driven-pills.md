# Pass 3: extract ConversationTopics module, mock topic extraction (~40 keywords), pills read from memory

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q7 keyword list, absorbed candidate 4 module extract)

## What to build

Bundles three changes into one cohesive landing per the absorbed-
candidate-4 decision: do the module extract as the same change that
swaps the data source to memory, so the move and the swap aren't two
churny refactors.

1. **Mock topic extractor.** `MockAiUpdate` gains a ~40-keyword
   substring extractor covering family, career, location, health,
   hobbies, and milestones. Deterministic — same input always
   produces the same extracted topics. Newly extracted topics merge
   into `MemoryDocument.topics`, deduped (case-insensitive on the
   matching key, original case preserved on display) and capped at 8
   with oldest-first eviction.

2. **`ConversationTopics` module extract.** `topicsForContact` and
   `suggestionsForTopic` plus their static maps move out of
   `lib/src/widgets/crm_widgets.dart` (~lines 780–895) into the new
   module. The static maps become file-private. Two public functions:
   `topicsForContact(connection, memory)` and
   `suggestionsForTopic(category, topic, contactName)`.

3. **Memory-driven pills.** `memoryTopicsProvider` (family by
   `contactId`) is added, derived from `memoryProvider`. The contact
   profile Conversation Topics pills read from it. The static
   category-default map is preserved as the empty-memory fallback
   only.

Templated suggestion fallback for memory-extracted topics with no
curated entry is deferred to #044 — this slice keeps the existing
static suggestion map for tap-to-suggestions sheet behavior.

## Acceptance criteria

- [ ] `MockAiUpdate` topic extractor: ~40 hand-curated keywords across
      family / career / location / health / hobbies / milestones;
      substring matching; deterministic.
- [ ] Extracted topics merged into `MemoryDocument.topics`, deduped
      (case-insensitive on the matching key, original case preserved
      on display), capped at 8 with oldest-first eviction.
- [ ] `ConversationTopics` module extracted from `crm_widgets.dart`.
      Two public functions: `topicsForContact(connection, memory)` and
      `suggestionsForTopic(category, topic, contactName)`.
- [ ] `topicsForContact` returns memory topics when present; falls
      back to category defaults when memory topics is empty.
- [ ] Static `_topicDefaultsByCategory` and `_topicSuggestions` maps
      move with the module and become file-private.
- [ ] `memoryTopicsProvider` (family by `contactId`) derived from
      `memoryProvider`.
- [ ] Contact profile Conversation Topics pills read from
      `memoryTopicsProvider`.
- [ ] Tap-to-suggestions sheet still functions for static-map topics
      (templated fallback for memory-extracted topics is in #044).
- [ ] Unit tests for `ConversationTopics` pure functions, including
      empty-memory fallback to category defaults.
- [ ] Integration test: an AI update with input mentioning a known
      keyword (e.g., "promotion") causes the topic to appear on the
      contact profile.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #042 (needs `MockAiUpdate` to have a place to add the keyword
  extractor; needs the unified seam)
