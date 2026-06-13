# Topic-scoped Conversation Topic panel

Labels: enhancement, ready-for-agent, pass-4.3-follow-up

## Parent

- PRD: `docs/prd/2026-06-13-memory-topic-backfill-prd.md`

## What to build

Make a selected Conversation Topic bubble show only recommendations scoped to that selected topic. The topic details panel should render all available prepared Topic Suggestions for the selected topic, keep deterministic topic-template fallback behavior, and remove generic/unfiltered content that can make topic A show context from topic B.

This is the visible bug-fix slice: it does not add backfill. It makes existing prepared suggestions trustworthy and removes hardcoded placeholder content from the topic panel.

## Acceptance criteria

- [ ] Tapping a topic bubble shows all available non-expired prepared suggestions for that exact topic, capped by the existing Topic Suggestions shape.
- [ ] Selecting topic A does not display prepared suggestions for topic B.
- [ ] Topic-template fallback remains available when no prepared suggestion exists for the selected topic.
- [ ] The topic details panel no longer renders hardcoded related-news placeholder copy.
- [ ] The topic details panel no longer renders unfiltered memory history or whole-person summary under a selected topic.
- [ ] Topic suggestions remain gentle and non-shaming; no numeric day-count guilt copy is added.
- [ ] Widget tests cover all-suggestions rendering, topic A/topic B mismatch prevention, placeholder removal, and removal of unfiltered context.
- [ ] Targeted widget test file(s) pass.

## Blocked by

None - can start immediately
