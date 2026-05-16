# Pass 2 — AI Insights collapsible card with Recommendation, Person Summary, Conversation Topics

Labels: enhancement, needs-triage

> *Created 2026-05-16 from the Pass 2 contact-profile-redesign grilling
> session.*

## Parent

Pass 2 slice 2 of 4. See #033 for the tokens and header. Supersedes the
old `InsightCard` widget on this screen.

## What to build

A new collapsible "AI Insights" card on the contact profile screen,
inserted between the new header (#033) and the existing history list.
The card renders three subsections with distinct visual treatments:

1. **Recommendation callout** — cream/yellow surface, gold border,
   lightbulb icon, bold "Recommendation" title in dark gold/brown,
   body text derived from `BondTier.from(connection.bondScore)`.
2. **Person Summary** — purple person outline icon, bold heading,
   paragraph body = `ContactInsight.why`.
3. **Conversation Topics** — orange chat outline icon, bold heading,
   four pill-shaped buttons with terracotta fill (`tokens.topicAccent`
   from #033) and white labels, sourced from a category-keyed map.
   Tapping a pill opens a bottom sheet with 3–5 static suggestions
   keyed by `(category, topic)`.
4. **Footer caption** — "Click any topic to see AI suggestions." in
   muted caption text.

The card itself sits on `tokens.surfaceRaised` with a thin
`tokens.border` outline. Header row: small purple sparkle (four-point
diamond) icon, bold "AI Insights" heading, an upward chevron on the
far right indicating collapse.

### Collapse behavior

- Default: expanded
- State: session-only (a single `bool` in the widget's state, no
  persistence)
- Animation: `AnimatedSize` (or equivalent) with the project's standard
  curve and duration; collapses to instant under
  `MediaQuery.disableAnimations`
- Tap target: the entire header row (sparkle + label + chevron)

### Recommendation copy helper

```
String _bondEncouragement(BondTier tier) => switch (tier) {
  BondTier.close    => 'Strong bond! Keep up the regular communication.',
  BondTier.steady   => 'Steady ground — a quick check-in keeps it warm.',
  BondTier.drifting => 'It\'s been a while. A short hello goes a long way.',
};
```

### Conversation Topics map

A new constant — likely in `lib/src/widgets/crm_widgets.dart` next to
the `categoryColor` helper, or in a new small file
`lib/src/state/topic_defaults.dart`. Shape:

```
const Map<String, List<String>> _topicDefaultsByCategory = {
  'Family':      ['Family updates', 'Shared memories', 'Daily life', 'Future plans'],
  'Friends':     ['Recent meetups', 'Inside jokes', 'Plans together', 'Life updates'],
  'College':     ['Old classes', 'Mutual friends', 'Career', 'Reunions'],
  'High School': ['Old times', 'Mutual friends', 'Where they are now', 'Reunions'],
  'Work':        ['Projects', 'Career', 'Industry news', 'Team updates'],
};
```

Surface up to 4 topics per contact. Fall back to a generic list if the
category is unknown.

This map is the **Pass 3 swap point**: the per-contact memory PRD
(`docs/prd/2026-05-16-per-contact-memory-files-prd.md`) replaces this
read with `ref.watch(memoryTopicsProvider(connection.id))`. Keep the
helper signature small and easy to redirect.

### Topic suggestions bottom sheet

Triggered by tapping any topic pill. A small static map (same file as
the topic defaults) keyed by `(category, topic)` returns 3–5
suggestions. Sheet anatomy:

- Top: drag handle
- Title: the topic name with the orange chat icon
- Body: a list of suggestion strings rendered as plain text rows (no
  pills, no card chrome)
- Dismiss: swipe-down or backdrop tap

No state mutation — the sheet is read-only. No navigation.

### Removed in this slice

- `RelationshipFactsCard` instantiation on the contact profile screen.
  The widget class stays in `crm_widgets.dart` for any other caller.
  Its data (relationship label, known since, last contact) already
  lives in the header facts strip from #033.
- The existing `InsightCard` instantiation on this screen. The class
  stays in `crm_widgets.dart` for now (other surfaces may still use it),
  but the contact profile no longer renders it.

## Acceptance criteria

- [ ] AI Insights card renders on the contact profile screen between
      the header card and the history list
- [ ] Card shows the four subsections in order: Recommendation
      callout, Person Summary, Conversation Topics, footer caption
- [ ] Recommendation callout uses `tokens.recommendationSurface` and
      `tokens.recommendationBorder` from #033
- [ ] Recommendation body text matches `BondTier` (close / steady /
      drifting) per the helper above
- [ ] Person Summary body renders `ContactInsight.why` (no longer the
      one-line `summary`, no longer hidden behind a tap)
- [ ] Up to four Conversation Topics pills render, filled with
      `tokens.topicAccent`, white text
- [ ] Tapping a pill opens a bottom sheet with 3–5 suggestions
- [ ] Card collapses on header tap, expanded by default, animated
      with reduced-motion fallback
- [ ] `RelationshipFactsCard` is no longer instantiated on the contact
      profile screen
- [ ] The old `InsightCard` is no longer instantiated on this screen
- [ ] Long topic labels truncate with ellipsis (the Figma example shows
      "Future pla..." cut off — that should not crash, just truncate)
- [ ] New tests for: recommendation copy mapping, topic pill rendering
      and tap-opens-sheet, collapse toggle, animation skip under
      `disableAnimations`
- [ ] `flutter analyze` clean
- [ ] Per-commit verification bar: targeted tests pass, full sweep
      ≤ 12 baseline failures

## Blocked by

- #033 — needs `tokens.recommendationSurface`,
  `tokens.recommendationBorder`, `tokens.topicAccent`

## Notes

The "card with internal subsection icons" pattern is new on this
screen. If you prefer to extract the three subsections (Recommendation,
Person Summary, Conversation Topics) as private widgets inside
`crm_widgets.dart`, that's encouraged — keeps the screen file lean.

The Pass 3 PRD's "swap one line" promise depends on the topics widget
reading from a single helper that can be redirected to a Riverpod
provider. Keep that seam clean: the topics widget should not inline the
category-defaults map, but call a helper that owns the lookup.
