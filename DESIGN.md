# Design

The visual system for ConnectMe. Read alongside `PRODUCT.md`. Where they conflict, `PRODUCT.md` wins.

This document captures the *target* design system, not the current implementation. The current `lib/src/theme/app_theme.dart` and `lib/src/widgets/crm_widgets.dart` predate this spec; they will be migrated.

## Theme

**Tri-state**: `system` (default) / `light` / `dark`. State lives on `AppState.themeMode`. Rendering reads `MediaQuery.platformBrightness` when set to `system`. Both light and dark are first-class — neither is a default, both ship.

**Physical scenes that justify shipping both:**
- *9:47pm in bed, lights dim, glancing at "did I forget anyone this week."* → forces dark.
- *11am on a bus in full sun, logging the coffee with Sarah before the moment slips.* → forces light.

## Color

### Strategy

**Full palette with assigned roles.** Vibrant accents on a calm surface. Saturated color covers ≤25% of any screen's pixels. The vibrant palette is paint, not walls.

### Tokens (light)

All values OKLCH-tuned away from `#000` and `#fff`. Surfaces carry a tiny purple chroma (≤0.005) so neutrals are not garish.

| Token | Value | Role |
|---|---|---|
| `surface` | `oklch(0.985 0.003 295)` ≈ `#FAF9FC` | App background. Slight purple tint, not pure white. |
| `surface-raised` | `oklch(1.000 0.000 0)` ≈ `#FFFFFF` | Cards, sheets. Pure white only on raised surfaces. |
| `surface-sunken` | `oklch(0.965 0.003 295)` ≈ `#F2F1F4` | Input fields, sunken regions. |
| `ink` | `#1A1A1A` | Primary text. ~17:1 contrast on `surface`. |
| `ink-muted` | `oklch(0.420 0.010 290)` ≈ `#5C5A66` | Secondary text. ≥4.5:1. |
| `ink-subtle` | `oklch(0.580 0.008 290)` ≈ `#8C8995` | Tertiary text on raised surfaces only. ≥4.5:1 against white. |
| `border` | `oklch(0.920 0.005 290)` ≈ `#E7E4EB` | Hairline dividers, card borders when needed. |
| `primary` | `#7C3AED` | Primary action, primary nav, bond ring at "close" tier, AI ✨. |
| `primary-on` | `#FFFFFF` | Text/icons on `primary` fills. |
| `primary-tint` | `oklch(0.965 0.018 295)` ≈ `#F1ECFA` | Hover/pressed background, soft selection. |
| `secondary` | `#FF8C00` | "Drifting" tier, soft warning, one category accent. |
| `secondary-tint` | `oklch(0.962 0.025 70)` ≈ `#FAEEDC` | Soft warning surface, never with text on it. |
| `tertiary` | `#FF71CF` | Birthdays, celebration, family-tier warmth, one category accent. |
| `tertiary-tint` | `oklch(0.953 0.030 340)` ≈ `#FAE0EE` | Soft celebration surface. |
| `success` | `oklch(0.640 0.150 155)` ≈ `#3B9D6E` | "Trending up", recently strengthened bond. Used sparingly. |
| `danger` | `oklch(0.555 0.220 25)` ≈ `#C53030` | Destructive confirmations only. **Never** for "overdue." |

### Tokens (dark)

Surfaces derived from `#1A1A1A`, slightly tinted purple. Ink inverted but never to pure white.

| Token | Value | Role |
|---|---|---|
| `surface` | `oklch(0.165 0.005 295)` ≈ `#191820` | App background. |
| `surface-raised` | `oklch(0.215 0.006 295)` ≈ `#23222B` | Cards, sheets. |
| `surface-sunken` | `oklch(0.140 0.005 295)` ≈ `#15141B` | Input fields. |
| `ink` | `oklch(0.965 0.003 295)` ≈ `#F4F2F7` | Primary text. ≥15:1 against `surface`. |
| `ink-muted` | `oklch(0.760 0.008 290)` ≈ `#BFBCC8` | Secondary text. ≥7:1. |
| `ink-subtle` | `oklch(0.640 0.008 290)` ≈ `#979398` | Tertiary text. |
| `border` | `oklch(0.310 0.006 295)` ≈ `#39373F` | Hairline dividers. |
| `primary` | `oklch(0.700 0.200 295)` ≈ `#9B6BF0` | Lighter purple on dark — pure `#7C3AED` is too dim. ≥4.5:1 against dark surface. |
| `primary-on` | `#FFFFFF` | |
| `primary-tint` | `oklch(0.260 0.020 295)` ≈ `#2A2235` | |
| `secondary` | `oklch(0.760 0.150 60)` ≈ `#FFA240` | Slightly lighter for dark surface contrast. |
| `tertiary` | `oklch(0.780 0.130 340)` ≈ `#FF94D8` | |
| `success` | `oklch(0.730 0.150 155)` ≈ `#5BC094` | |
| `danger` | `oklch(0.660 0.200 25)` ≈ `#E25555` | |

### Hard rules

- `secondary` (#FF8C00) and `tertiary` (#FF71CF) **never** carry text on light surfaces. Contrast: ~2.2:1 and ~2.5:1 — fails AA. They are reserved for fills, large icons (≥24px), and decorative shapes.
- No `#000` or pure `#fff` for text. Use `ink` and `ink-on-dark`.
- No gradients on text. No `background-clip: text`.
- No side-stripe borders (>1px on a single edge). Tier signals use a small dot or full-border + tint, not a left-stripe.

### Semantic mapping

These are the only places vibrant colors should appear in product UI. If a new use is proposed, check it against this list first.

| Surface | Color | Why |
|---|---|---|
| Primary action button | `primary` fill | One per screen. |
| Active tab indicator | `primary` (4px line) | Single source of truth for "you are here." |
| Bond ring, "close" tier (≥80) | `primary` arc | The marquee visualization. |
| Bond ring, "steady" tier (50–79) | `ink-muted` arc | Quiet state, not graded. |
| Bond ring, "drifting" tier (<50) | `secondary` arc | Warm warning, never red. |
| Trend arrow (up) | `success` | |
| Trend arrow (down) | `secondary` | |
| AI ✨ tag | `primary` icon, `primary-tint` background | |
| Celebration moment (bond ring fill animation) | `primary` | |
| Birthday / anniversary marker | `tertiary` | |
| Destructive confirm dialog | `danger` | Sign-out, delete contact. **Not** for "you missed something." |
| Empty-state copy | `ink-muted` on `surface` | One sentence, no decoration. |

### Category colors

The five contact categories (Family, Friends, Work, College, High School) need distinct color identity. Assigned mapping:

| Category | Color token | Usage |
|---|---|---|
| Family | `tertiary` (pink) | Family is warm, soft. Pink does not mean "girls" here — it means home. |
| Friends | `primary` (purple) | The brand color, central to personal life. |
| Work | `oklch(0.580 0.080 230)` ≈ `#5283A8` (sky blue) | Cooler, professional, distinct from primary. |
| College | `success` (green) | Earthy, growth-y, distinct from work. |
| High School | `secondary` (orange) | Warm, nostalgic. |

Category color appears as: a small filled dot beside the name, an avatar ring tint *only* on the directory tab (not on Home cards — Home uses bond-tier color on the ring), and the category chip background.

## Typography

**Inter** for body, **Inter Display** for headings ≥24pt. Both shipped via `google_fonts: ^8.1.0` (already in `pubspec.yaml`, currently unused). Avenir was set in the existing theme but never loaded — the running app falls back to system. Migrating to Inter is also a *correctness* fix, not just a style choice.

Avoid: Avenir (license + bundling cost), Geist (overused in AI tools, second-order slop), Manrope (too "modern startup"), system font (no design control across platforms).

### Scale (1.25 ratio between steps)

| Step | Size | Line-height | Weight | Use |
|---|---|---|---|---|
| `display` | 32 | 1.15 | 700 | Page hero on Home, profile screens. |
| `h1` | 26 | 1.20 | 700 | Section titles, modal titles. |
| `h2` | 21 | 1.25 | 600 | Card titles, sub-section labels. |
| `body-lg` | 17 | 1.45 | 500 | Primary body, recommendation copy, list rows. |
| `body` | 15 | 1.50 | 400 | Default reading size. |
| `caption` | 13 | 1.40 | 500 | Metadata, dates, "5 days ago." |
| `mono-tabular` | 15 | 1.40 | 500 (tabular-nums) | Numbers in lists (bond score on tap-reveal). |

Never use weight 900. The current code's `FontWeight.w900` everywhere is part of the visual loudness we're correcting. Cap at 700 for display, 600 for headings, 500 for body emphasis.

Body line-length cap: 65–75 characters per line.

## Spacing

8px base. **Vary spacing for rhythm — same padding everywhere is monotony.**

| Token | Value | Use |
|---|---|---|
| `space-1` | 4 | Inline icon-text gaps. |
| `space-2` | 8 | Tight stacking, chip gaps. |
| `space-3` | 12 | List-row internal padding. |
| `space-4` | 16 | Default card padding (was 24, deliberately reduced). |
| `space-5` | 24 | Section vertical rhythm. |
| `space-6` | 32 | Page-level breathing room, hero spacing. |
| `space-8` | 48 | Major section breaks. |

**Cards do not all use the same padding.** A dense list row uses `space-3` vertical, `space-4` horizontal. A featured Home card uses `space-5` all around. A modal sheet uses `space-6` top, `space-5` sides. The variation creates rhythm; uniform padding flattens hierarchy.

## Radius

| Token | Value | Use |
|---|---|---|
| `radius-sm` | 8 | Chips, pills, small inline pills. |
| `radius-md` | 14 | Inputs, secondary buttons. |
| `radius-lg` | 18 | Primary cards, sheet corners. |
| `radius-xl` | 24 | Hero cards on Home only. |
| `radius-pill` | 999 | Bond rings, avatar shapes. |

The current code uses `BorderRadius.circular(28)` on every card. Soften, but vary. 28 is too large for everything.

## Elevation

Three levels. Stop reaching for shadows.

| Level | Light shadow | Dark shadow | Use |
|---|---|---|---|
| `e0` | none | none | Flat surface, default. |
| `e1` | `0 1px 2px oklch(0.20 0 0 / 0.06)` | inset `0 0 0 1px oklch(1 0 0 / 0.04)` | Cards, sheets resting on `surface`. |
| `e2` | `0 8px 24px oklch(0.20 0 0 / 0.10)` | `0 8px 24px oklch(0 0 0 / 0.40)` | Sheets while dragging, popovers. |

**No diffuse glow.** No multi-layered shadows. The current `0x22000000` shadows on every card stack into mush.

## Components

### Bond ring

The signature visualization. Never replace the avatar circle with a number; always wrap the avatar with a ring.

**Anatomy:**
- Avatar (circle, `radius-pill`).
- Ring around avatar: 3px stroke, ~`size + 6px` outer diameter.
- Ring color = bond tier color (close / steady / drifting per Color → Semantic mapping).
- Ring fill arc = `bondScore / 100` of full circle, starting at 12 o'clock, clockwise.
- Background ring (unfilled portion) = `border` token at 40% opacity.
- Trend arrow (small, 12px) sits at 4 o'clock outside the ring. `success` if up, `secondary` if down. Hidden if no recent change.

**On tap:** number reveals beneath the avatar in a small caption (`caption` style, `ink-muted`), e.g. "73 · close" — number, dot, label. Reveal uses a quick fade (200ms). Tap again to hide.

**Sizes:** 64px (default in lists), 96px (contact profile header), 120px (no longer needed; the existing `BigScoreCircle` is removed).

**Animation (signature moment):** when bond score changes (after `aiUpdateProvider.commit` lands its delta), the arc sweeps from old value to new value. ~600ms, ease-out-quart. Dimmed during travel, full saturation at rest. Reduced motion: instant cut.

### Recommendation card (Home)

Conversational, not a CRM ticket.

**Layout (vertical):**
- Bond ring + name on a single row, ring 56px, name `h2`.
- Headline copy, `body-lg`, second-person, question-shaped where natural ("Wondering how Mike's job hunt went?").
- Soft context line, `body`, `ink-muted` ("It's been about 5 weeks since you talked.").
- Two actions on a row: primary "Update Connection" (filled, `primary`), secondary "Open" (text button).
- No "priority" pill, no warning icon, no urgency banner.

The current `RecommendationCard` in `crm_widgets.dart` ships almost the exact opposite of this. It's a complete rewrite, not a tweak.

### Contact list row (People directory)

Dense, scannable.

- Avatar (40px) with tier-colored ring at 3px.
- Name (`body-lg`, 600 weight), category dot inline.
- Subtitle (`caption`, `ink-muted`): "drifting since April" or "in touch this week" — words, not dates.
- Trailing chevron (`ink-subtle`, 16px).
- Row height: 64px. Touch target: full row.
- Group headers (`h2`, `ink-muted`, sticky): "Family · 1", "Friends · 2", etc.

### Empty state

One sentence. No illustration. No icon. No "Add your first ___" button (button lives in the +-sheet, not the empty state).

The sentence does the work. Examples in `PRODUCT.md`. Style: centered, `body-lg`, `ink-muted`, max-width 32ch. Vertical centering on the empty area, with at least `space-8` padding.

### + Sheet

Triggered by the global + button (top-right of shell `AppBar`, not a FAB).

- Bottom sheet, `radius-lg` top corners, `space-6` vertical padding.
- Three actions, stacked vertically:
  - **Add Connection** (icon: person+) — leads to add-connection form.
  - **Update Connection** (icon: ✨ in `primary-tint`) — leads to AI free-text capture.
  - **Plan Event** (icon: calendar+) — leads to add-event form.
- Each action: 56px tall, full-width tappable, label `body-lg`, supporting caption underneath ("Paste a chat, AI will categorize" for Update Connection).
- Cancel: drag-down or tap outside.

### AI preview (Update Connection result)

The flow: free-text input → AI categorizes → preview card → user confirms/edits → save.

**Preview anatomy:**
- Header: "Here's what I found" (`h2`).
- For each parsed item, a card:
  - Contact match: avatar + name. Tappable to swap if AI guessed wrong.
  - Interaction type: chip (Coffee, Phone Call, Reminder, Note).
  - Title field: editable, single-line.
  - Note field: editable, multi-line.
  - Date: defaults to "today," tappable to change.
  - Small ✨ tag (`primary` icon, 14px) in the corner: "AI suggested."
- Footer: "Save these (3)" primary button, "Cancel" text button.

**Signature motion:** preview cards stagger in (~80ms apart, ease-out-quart, 240ms each). Reduced motion: all appear at once, instant.

### Plan tab — calendar

The current `PlannerTab` uses a custom calendar grid with day cells. Keep the structure; restyle.

- Month header: `h1`, plain text. Side arrows (32px touch targets) for prev/next.
- Day cells: 44px touch target minimum (currently smaller — A11y fix).
- Today: filled `primary` circle behind the date number, `primary-on` text.
- Selected day: `primary-tint` background, `primary` 2px ring.
- Days with events: small `primary` dot under the date number. Multiple events = up to 3 dots.
- Below grid: list of selected day's events, `EventTile` style, swipe-left to delete with undo (current behavior).

Category-colored event chips use the category palette above.

## Motion

### Budget

**Quiet by default, two signature moments.**

| Motion | Duration | Curve | Use |
|---|---|---|---|
| Tab transition | 220ms | `ease-out-quart` | Switching Home / People / Plan. |
| Sheet slide-up | 280ms | `ease-out-quart` | + sheet, modals. |
| Sheet drag-down | follows finger | linear | Native dismissal. |
| Card press feedback | 90ms | `ease-out` | Subtle scale to 0.98. |
| Ring fill (signature) | 600ms | `ease-out-quart` | Bond score change after update. |
| AI preview stagger (signature) | 240ms each, 80ms offset | `ease-out-quart` | Preview cards revealing. |
| Number reveal (tap bond ring) | 200ms | `ease-out` | Fade-in caption. |

### Bans

- No `bounce`, `elastic`, `spring` curves anywhere.
- No animation of layout properties (`width`, `height`, `top`, etc.). Use transforms.
- No parallax.
- No "wow" loaders. If something takes >1s, show a quiet skeleton — never a spinner that pulses harder than the bond ring fill.

### Reduced motion

`MediaQuery.of(context).disableAnimations` (Flutter's read of OS reduce-motion):

- Tab transitions, sheet slides → instant.
- Ring fill → instant cut.
- AI preview stagger → all cards appear simultaneously, no fade.
- Number reveal → still allowed (fade is the gentlest motion, 200ms is below most thresholds), but if it causes complaints, fall back to instant.

This applies always, no opt-out. Hard requirement, not a preference.

## Iconography

**Material Symbols Outlined**, weight 400. Already available via Flutter's `Icons`. Consistent stroke, neutral.

- 16px for inline (next to text).
- 20px for tab bar.
- 24px for action buttons.
- 32px for hero / empty contexts.

The current code mixes emoji (👤 👨 🔗 ✨) with Material icons. Decision: **emoji are reserved for two roles** — user/contact avatars (`AppUser.avatar`, `Connection.avatar`), and the literal ✨ AI sparkle marker (rendered as Material Symbol where possible, emoji as fallback). Everywhere else, Material Symbols.

The "🔗" in the existing `AppHeader` goes — replace with a wordmark or a small custom icon during the audit pass.

## Layout

### Shell

- Top: `AppBar`, 56px, `surface` background, no shadow. Title `h2`. Right side: + button (24px), then user avatar (32px, tappable to settings/profile).
- Body: scrollable, `space-4` horizontal padding (`16px`), no fixed `Container` wrappers — the page decides its own structure.
- Bottom: tab bar, 64px, three icons + labels. `surface` background, top hairline border in `border` token. Active tab: `primary` icon + label, 4px line above the active tab. Inactive: `ink-subtle`.

### Page-level structure

- No giant teal header on every screen (the current `TealPageHeader` saturates 22% of the screen with the brand color before any content shows). Replaced by:
  - Plain `AppBar` with title.
  - Optional sub-header *only* on profile/contact screens, using `surface-raised` and `space-5` padding, no color block.

## Removed

The audit will remove these UI surfaces, full stop. Listed here so PRODUCT and DESIGN agree:

- Recommendation `priority` text rendered to user (chip, copy, anywhere).
- `BigScoreCircle` (replaced by avatar bond ring at 96px on profile).
- Connection-score-percentage gain copy ("You can gain 8% Connection Score" — it's a shame mechanic).
- "Recommended Action!" peach-orange card with white text.
- Yellow `InsightCard` (#FFE45C) — color is unrelated to anything else, reads as warning.
- HeatmapCard's standalone bright palette (#A855F7, #22C55E, etc.) — replaced with the category palette above.
- User-level XP / level / nextLevelPoints in any visible position.
- Global Activity tab.
- Settings tab.
- "🔗" emoji in app header.
- The `AppSurface` hardcoded `#F5F6F7` cool gray — replaced with theme `surface` token.
