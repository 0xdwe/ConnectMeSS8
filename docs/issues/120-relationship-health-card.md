# #120 — Relationship Health Card for No-Recommendation Contacts

**Parent PRD:** N/A (standalone polish, follow-up to #119)  
**Branch:** `feat/120-relationship-health-card`

---

## What to build

When a contact has `MaintenanceNeed.none` (healthy, within cadence) and
is therefore absent from the top-3 recommendations, the Recommendation
callout section in `AiInsightsCard` currently renders nothing
(`SizedBox.shrink()`).

Replace that empty state with a **"Relationship Health" card** — same
visual shape as the existing recommendation callout, green/success
palette, showing:

1. **Qualitative recency** — "Chatted recently" / "Recently connected"
   phrasing that never exposes a numeric day count (anti-shame guardrail).
2. **Memory summary snippet** — 1–2 lines truncated from
   `MemoryDocument.summary`, giving the user a quick AI-written context
   snapshot for the person.

The card only appears when `memorySummary` is non-empty. If the contact
has no memory yet (no AI Updates run), the slot stays empty — no
fallback generic copy.

---

## Trigger conditions

| Condition | Show health card? |
|---|---|
| Contact not in top-3 recommendations AND `memorySummary` non-empty | ✅ Yes |
| Contact not in top-3 AND `memorySummary` null / empty | ❌ No (stays empty) |
| Contact IS in top-3 (has recommendation, normal or completed) | ❌ No (recommendation wins) |

The "you're in a good place" post-AI-Update completed card (#119) is
NOT replaced by this — that completed card appears immediately after
commit and persists until the next refresh (provider recompute). After
the next refresh, if the contact is still `none`-need and has memory,
the health card renders.

---

## Visual design

- Same `Container` + `BoxDecoration` shape as the recommendation callout.
- Background: `tokens.success.withValues(alpha: 0.08)` (lighter than the
  isCompleted card's 0.1 to feel more neutral / informational than
  celebratory).
- Border: `tokens.success.withValues(alpha: 0.25)`.
- Leading icon: `Icons.favorite_outline` in `tokens.success`.
- **Header**: `"Relationship healthy"` in `AppTypography.h2` with
  `tokens.success`.
- **Body line 1**: Qualitative recency string (see copy spec below).
- **Body line 2**: First 120 characters of `memorySummary`, truncated with
  ellipsis, in `AppTypography.body` with `tokens.success.withValues(alpha: 0.8)`.

### Recency copy

Use `RelationshipMaintenancePolicy.evaluate` to get `latestTouchAt`,
then bucket qualitatively:

| Days since latest touch | Label |
|---|---|
| ≤ 3 | "You two connected very recently." |
| ≤ 14 | "You've been in touch recently." |
| > 14 | "You've kept in touch regularly." |

Never expose a numeric day count (anti-shame guardrail).

---

## Implementation

### `lib/src/widgets/crm_widgets.dart`

In `_AiInsightsBody._build`, inside the `Consumer` that watches
`recommendationsProvider`:

```dart
if (recForThisContact == null) {
  // NEW: show health card if memorySummary is available
  return _buildRelationshipHealthCard(
    context: context,
    connection: widget.connection,
    interactions: ref.watch(interactionsByContactProvider(widget.connection.id)),
    memorySummary: widget.memorySummary,
    tokens: tokens,
  );
}
```

Add a private function `_buildRelationshipHealthCard(...)` (or small
widget) that:
1. Returns `SizedBox.shrink()` when `memorySummary` is null/empty.
2. Computes qualitative recency from `RelationshipMaintenancePolicy.evaluate`.
3. Renders the styled card.

### Imports needed in crm_widgets.dart

`relationship_maintenance_policy.dart` is already used in the engine;
needs to be imported in `crm_widgets.dart` as well, or the recency
bucket can be computed via a helper function that lives locally in the
widget file to avoid the import.

**Preferred:** inline the recency bucket as a local helper in
`crm_widgets.dart` — no new import dependency on the policy class from
the widget layer.

---

## Acceptance criteria

- [ ] When a contact has `MaintenanceNeed.none` and a non-empty
      `memorySummary`, a green health card renders in the Recommendation
      callout slot.
- [ ] Card shows a qualitative recency string (no numeric day counts).
- [ ] Card shows a truncated memory summary snippet.
- [ ] When `memorySummary` is null or empty, the slot stays empty
      (unchanged from current behavior).
- [ ] When the contact has an active recommendation (any priority), the
      health card does NOT render (recommendation wins).
- [ ] When the contact has a completed card (#119 isCompleted), the
      completed card renders (health card does NOT override it).
- [ ] Anti-shame check: no digits appear in the health card copy.
- [ ] Widget test covering: health card shown when no-rec + has memory;
      health card hidden when no-rec + no memory; health card hidden
      when rec exists.

---

## Blocked by

Nothing. Can be developed against `main` directly.

---

## Notes

- Do NOT add this card to the `rankRecommendations` engine — it lives
  purely in the widget layer as a display fallback.
- The card's recency string must never contain digits (anti-shame).
- `memorySummary` is already passed to `_AiInsightsBody` from
  `AiInsightsCard` → no new provider reads needed.
- Use `interactionsByContactProvider` which is already read elsewhere
  in the widget file to compute recency.
