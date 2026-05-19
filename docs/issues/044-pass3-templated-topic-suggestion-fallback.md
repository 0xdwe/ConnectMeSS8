# Pass 3: templated suggestion fallback for memory-extracted topics with no curated entry

Labels: enhancement, needs-triage

## Parent

- Pass 3 PRD: `docs/prd/2026-05-19-per-contact-memory-files-v2-prd.md`
  (Q13 — templated fallback)

## What to build

`ConversationTopics.suggestionsForTopic` gains the three rotating
templates from Q13 so that personal memory-extracted topics like
`violin lessons` or `kindergarten` get useful prompts rather than the
generic fallback list.

Templates:

- `"How's the {topic} going?"`
- `"Last time you mentioned {topic} — anything new?"`
- `"Curious how {firstName}'s {topic} is going."`

Templates use `{topic}` and `{firstName}` slots only. The function
signature already takes `contactName` from #043; first name is the
leading whitespace-split token of `contactName`.

Behavior order:

1. Static `_topicSuggestions` map hit returns the curated list.
2. Miss falls back to the three templates with slots rendered.

Tap-to-suggestions sheet now produces useful prompts for arbitrary
memory-extracted topics with the same visual treatment as curated
suggestions.

## Acceptance criteria

- [ ] Three template strings defined in the `ConversationTopics`
      module with `{topic}` and `{firstName}` placeholders.
- [ ] `suggestionsForTopic` returns curated suggestions when the
      static map has a hit; otherwise returns three templated
      suggestions with slots rendered.
- [ ] First-name extraction takes the first whitespace-split token of
      `contactName`.
- [ ] Tap-to-suggestions sheet renders the templated suggestions with
      the same visual treatment as curated ones.
- [ ] Unit tests for `suggestionsForTopic` covering: curated-map hit;
      templated fallback for unknown topic; single-name contacts (no
      whitespace); empty-topic edge case.
- [ ] Integration test: tap a memory-extracted topic with no curated
      entry, see three template suggestions in the sheet.
- [ ] `flutter analyze` clean. `flutter test` passes.

## Blocked by

- #043 (needs the `ConversationTopics` module to exist and
  `suggestionsForTopic` to be the public surface)
