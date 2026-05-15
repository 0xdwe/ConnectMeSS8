# UI Polish and Design System PRD

## Problem Statement

ConnectMe is functionally complete but visually fails the principles set in `PRODUCT.md`. The current UI scores 6.5/20 on a five-dimension audit (accessibility, performance, theming, responsive, anti-patterns) and reads as AI-generated on first inspection. Eleven specific anti-patterns are present, including a hero-metric `BigScoreCircle`, drenched orange "Recommended Action!" card, gamified user-level XP/points, "priority" pills on relationship recommendations, a 94×94 floating action button, and a teal-block header on every secondary screen.

The result is a tonal mismatch with the app's purpose. The product is meant to be a memory aid for two audiences who share one trait — limited working memory for relationship maintenance — busy professionals and people with ADHD. The current visual layer grades the user, gamifies friendships, and creates high cognitive load. Both audiences abandon apps that do these things.

This PRD captures the audit findings and breaks them into independently-shippable issues that bring the running app in line with `PRODUCT.md` and `DESIGN.md`.

## Solution

A staged refactor in four waves. Each wave is independently mergeable; later waves depend on earlier ones.

**Wave 1 — Foundation (parallelizable):**
- Design token system + tri-state theme (`system` / `light` / `dark`).
- Typography system: load Inter via `google_fonts`, cap weights at 700, define type scale.
- Remove user-level XP/levels (`totalPoints`, `currentLevel`, `nextLevelPoints`) from `AppUser`.

**Wave 2 — Components (depends on Wave 1):**
- New `BondRing` component (replaces `ScoreRing` and `BigScoreCircle`).
- Remove `TealPageHeader` from all secondary screens.
- New `+ sheet` UX (replaces FAB-menu).

**Wave 3 — Surfaces (depends on Wave 2):**
- Recommendation card rewrite: conversational, no priority pills, no highlighted-card border, no warning icons.
- Shell IA: three primary tabs (Home / People / Plan), Settings behind avatar tap.
- Contact profile redesign: cut redundant cards, lean into bond ring + insight + history.
- AI Update preview-and-confirm flow.
- Calendar accessibility + restyle.

**Wave 4 — Onboarding & polish (depends on Wave 3):**
- Sample-friend tagging + warm empty-state copy.
- Bond ring fill animation (signature motion).
- AI preview stagger animation (signature motion).

Each wave is gated on running tests passing before the next begins.

## User Stories

1. As a busy professional, I want to open ConnectMe and not feel graded by a "Connection Score" hero card, so that the app feels supportive instead of judgmental.
2. As a user with ADHD, I want a predictable three-tab layout, so that I do not pay a cognitive-load tax on every entry.
3. As a user with ADHD, I want every AI-driven change to show a preview before saving, so that I never see surprise state changes.
4. As a busy professional, I want the app to use words instead of "high priority" / "low priority" labels for my friendships, so that the experience does not feel like a CRM.
5. As any user, I want bond scores shown as filled rings around avatars, so that I can read relationship state at a glance without seeing a number.
6. As any user, I want to tap a bond ring to reveal the underlying score, so that I have access to precision when I want it.
7. As any user, I want the app to follow my system theme (light/dark) by default, so that 9:47pm in bed and 11am in sun both work.
8. As a user with ADHD, I want sample friends visibly tagged on first run, so that I know what's real and what I can sweep away.
9. As any user, I want empty states to feel like a positive moment ("you're in touch with everyone right now") instead of an absence ("no data"), so that the app does not invent friction.
10. As a user with reduced motion enabled, I want all animations to collapse to instant cuts, so that the interface respects my OS preferences.
11. As a screen reader user, I want the bond ring to announce "Sarah, close, trending up" instead of "75 percent," so that I get meaning instead of a number.
12. As a user on iPhone SE, I want every interactive element to be at least 44pt tall, so that calendar day cells, filter chips, and small buttons are all reliably tappable.
13. As a user, I want primary text to use `#1A1A1A` (not pure black), and surfaces to be off-white (not pure white), so that the interface does not look garish.
14. As a developer, I want every color and spacing value to flow through a token system, so that future updates do not require global search-and-replace.
15. As a developer, I want existing widget and state tests to continue passing through the refactor, so that I can ship each wave with confidence.
16. As a developer, I want each wave's PR to be reviewable in under thirty minutes, so that the team can land changes incrementally.
17. As an evaluator (course grading), I want the running app to look distinctively designed (not generic AI-template), so that the project demonstrates intentional design thinking.

## Implementation Decisions

**Foundation:**
- Introduce `AppTokens` as an extension on `ThemeData` (or a `ThemeExtension`), exposing semantic color roles per `DESIGN.md`. No raw hex outside the token definition file.
- Tri-state theme stored as `enum AppThemeMode { system, light, dark }` on `AppState`. Existing `darkMode: bool` field becomes `themeMode: AppThemeMode`. Default: `system`. Resolved theme reads `MediaQuery.platformBrightness` when `system`.
- Typography: load Inter (and Inter Display ≥24pt) via `google_fonts`. Define seven type tokens (`display`, `h1`, `h2`, `bodyLg`, `body`, `caption`, `monoTabular`). Cap weight at 700 for display, 600 for headings, 500 for body emphasis. Replace all `FontWeight.w900` usages.
- Remove `AppUser.totalPoints`, `currentLevel`, `nextLevelPoints` and any UI surface that reads them. Update seed data and tests.

**Components:**
- `BondRing`: `StatefulWidget`, sizes 56/64/96. Avatar circle wrapped by a tier-colored arc (close ≥80 / steady 50-79 / drifting <50). Optional trend arrow (`success` up, `secondary` down). Tap toggles a small caption beneath: `"73 · close"`. Score gain animation (Wave 4).
- `TealPageHeader` deleted. Affected screens use a plain Material `AppBar`.
- `+ sheet`: `showModalBottomSheet` triggered by `IconButton` in the shell `AppBar` (top-right). Three actions: `Add Connection` / `Update Connection` / `Plan Event`. The existing FAB-menu in `_BottomNav` is removed; the bottom nav becomes a clean three-tab strip.

**Surfaces:**
- `RecommendationCard` rewritten. No `priority` text, no warning icon, no highlighted-border on index 1, no 💬 quote bubble. Headline `body-lg` second-person. Soft context line `body` `inkMuted`. Two actions row: primary "Update Connection" filled, secondary "Open" text.
- Shell IA: `_tabs` becomes `[HomeTab, PeopleTab, PlannerTab]`. Bottom nav has three items. `SettingsTab` is removed; settings reachable via avatar tap on the shell `AppBar` (already exists, route stays at `/me` or new `/settings`).
- Contact profile screen: header (avatar + 96pt bond ring + name + category dot + edit icon button), insight summary card, relationship facts row, history list. `_BondScorePanel`, `RecommendedActionCard`, `InsightCard` (yellow), `BigScoreCircle`, `CommunicationChannelsCard`, `InteractionFrequencyCard` removed from this screen. (Frequency and channels can return as collapsed sections in a future wave; keep the page simple now.)
- AI Update flow: refactor `runAiUpdate()` so the AI service produces a `proposed result` object that the UI shows for editing. New screen state: `inputting → previewing → saving → done`. Save commits via a new controller method `commitAiUpdate(...)`. Add ✨ chip on saved interactions.
- Calendar: enforce 44pt minimum cell, today indicator (filled `primary` circle behind date number), selected state (`primaryTint` background, 2px `primary` ring), event dots use `primary` (multi-event up to 3 dots).

**Onboarding & polish:**
- `Connection.isSample: bool` (defaults `false`). Seeded contacts set `isSample: true`. List rows render a small `sample` tag in `inkSubtle`. Settings has a "Remove sample friends" action.
- Empty states adopt warm copy. New per-context strings: planner empty, home empty, contact-history empty, AI-failed-to-parse.
- Bond ring fill animation: 600ms ease-out-quart on bond score change. AI preview cards stagger-fade-in 240ms each, 80ms offset. Both collapse to instant under `MediaQuery.disableAnimations`.

**Cross-cutting:**
- All `firstWhere` calls in UI add `orElse: () => null` and handle the null case (route back / show empty profile / show "contact removed" toast).
- `Colors.black54` / `Colors.black38` replaced everywhere with `inkMuted` / `inkSubtle` tokens.
- The "🔗" emoji in `AppHeader` replaced with a small Material icon or wordmark per `DESIGN.md`.

## Testing Decisions

- Each wave's PR ships with widget tests covering the visible behavior change.
- Existing tests in `test/state/app_state_test.dart` and `test/widget_test.dart` are kept passing. If a behavior change requires a test update (e.g. removing `currentLevel` from `AppUser`), the test is updated in the same PR with a note.
- New test surfaces:
  - `AppTokens` resolves to expected values in light and dark mode.
  - `themeMode == system` follows `MediaQuery.platformBrightness`.
  - `BondRing` renders tier color matching score band; tap toggles caption.
  - `RecommendationCard` renders no `priority` text.
  - `+ sheet` opens with three actions; FAB-menu is removed (the old key `plus-action-button` may stay for test compatibility).
  - AI Update flow: input → preview → confirm saves; cancel discards.
  - Calendar: day cell has min 44×44 hit area; today indicator visible.
- Accessibility checks: `flutter test --tags a11y` runs `meetsGuideline(textContrastGuideline)` and `meetsGuideline(tapTargetGuideline)` on key surfaces (Home, People row, Plan day cell, contact profile header).
- Reduced motion: tests assert that the bond ring and AI preview animations are not triggered when `MediaQuery.disableAnimations == true`.

## Out of Scope

- Real backend, real AI, real persistence. The MockAiUpdateService stays.
- Push notifications implementation (PRODUCT.md commits to weekly digest as future work).
- "Paste your contacts" bulk-import flow (deferred — onboarding wave only adds sample tagging + sweep).
- Internationalization. Copy is English-only.
- Re-doing the auth flow (the recent `mock-auth-form-prd.md` work stays as-is).
- Re-introducing the global Activity tab.
- Re-adding `currentLevel` / `totalPoints` in any visible position.
- Designing illustrations for empty states. Empty states are copy-only per `DESIGN.md`.
- Making the existing `HeatmapCard` work with real data; if it stays in any form, it uses the new category palette only.

## Further Notes

This PRD turns the audit into shippable work. The first wave (foundation) intentionally has zero visible change — it only introduces tokens, theme tri-state, typography, and removes XP from the data model. The second and third waves are where the visible transformation happens. Onboarding polish lands last so it inherits the correct visual language from the earlier waves.

The 17 user stories above explicitly cover both audiences (busy professionals, ADHD users), the developer experience (token system, test continuity), and the evaluation context (the project should look intentionally designed, not generic AI-template). Each story maps to one or more issues created from this PRD.
