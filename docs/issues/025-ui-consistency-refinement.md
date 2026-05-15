# UI Consistency Audit and Refinement

Labels: enhancement, ready-for-agent, wave-3, design-system

> *Created 2026-05-15 per user request.*

## AI Triage Brief

**Category**: enhancement. Comprehensive UI consistency pass to ensure all screens, modals, and components follow the design system established in Wave 1 and Wave 2.

**State**: ready-for-agent. After implementing #009-#014 and #024, the codebase has a mix of migrated components (using tokens/typography) and inconsistent spacing, sizing, and layout patterns that need harmonization.

**Problem**:
- Wave 1 migrated colors and typography to tokens, but spacing, radius, and elevation are still inconsistent
- Some screens use raw `EdgeInsets.fromLTRB(26, 26, 26, 126)`, others use `EdgeInsets.all(24)`
- Border radius varies: `circular(22)`, `circular(28)`, `circular(18)`, `circular(40)` with no pattern
- Modal padding inconsistent across `plus_sheet.dart`, `theme_modal.dart`, `add_connection_modal.dart`, etc.
- Icon sizes vary: `34`, `32`, `38`, `24` with no semantic meaning
- Some widgets still have raw `SizedBox(height: 22)`, `SizedBox(height: 20)`, `SizedBox(height: 12)` instead of consistent spacing
- Card shadows use raw hex colors in 6 locations (flagged in Wave 1 review but deferred)

**Goal**: 
Create a single-pass refinement that brings all UI surfaces into alignment with `DESIGN.md` spacing, radius, elevation, and layout principles. This is NOT a feature addition — it's a consistency sweep.

**Codebase notes**:
- `DESIGN.md` defines spacing scale (space-1 through space-8: 4px to 48px) but no `AppSpacing` tokens exist
- `DESIGN.md` defines radius scale (radius-sm: 8, radius-md: 14, radius-lg: 18, radius-xl: 24, radius-pill: 999) but no `AppRadius` tokens exist
- `DESIGN.md` defines elevation levels (e0, e1, e2) with specific shadow values but no `AppElevation` tokens exist
- Current inconsistencies found via `rg "EdgeInsets\.|SizedBox\(|BorderRadius\."` across 20+ files

**Implementation notes for the agent**:

### Phase 1: Add Missing Token Systems

**1. Spacing tokens** (`lib/src/theme/app_spacing.dart` or add to `app_tokens.dart`):
```dart
class AppSpacing {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double space7 = 40;
  static const double space8 = 48;
}
```

**2. Radius tokens** (add to `app_tokens.dart` or separate file):
```dart
class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}
```

**3. Elevation tokens** (add to `app_tokens.dart`):
```dart
// In AppTokens class:
static List<BoxShadow> elevation0() => [];
static List<BoxShadow> elevation1(bool dark) => [
  BoxShadow(
    color: dark ? Color(0x0FFFFFFF) : Color(0x1F000000),
    blurRadius: 7,
    offset: Offset(0, 2),
  ),
];
static List<BoxShadow> elevation2(bool dark) => [
  BoxShadow(
    color: dark ? Color(0x14FFFFFF) : Color(0x22000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  ),
];
```

### Phase 2: Systematic Migration

**Spacing migration** (20+ files):
- Replace `EdgeInsets.fromLTRB(26, 26, 26, 126)` → `EdgeInsets.fromLTRB(AppSpacing.space6, AppSpacing.space6, AppSpacing.space6, 126)` (or define a `pageBottomPadding` constant for the 126 nav clearance)
- Replace `EdgeInsets.all(24)` → `EdgeInsets.all(AppSpacing.space5)`
- Replace `SizedBox(height: 22)` → `SizedBox(height: AppSpacing.space5)` (round 22 to 24)
- Replace `SizedBox(height: 20)` → `SizedBox(height: AppSpacing.space5)`
- Replace `SizedBox(height: 12)` → `SizedBox(height: AppSpacing.space3)`
- Replace `SizedBox(width: 14)` → `SizedBox(width: AppSpacing.space3)` (round 14 to 12)

**Radius migration**:
- Replace `BorderRadius.circular(22)` → `BorderRadius.circular(AppRadius.lg)` (round 22 to 18)
- Replace `BorderRadius.circular(28)` → `BorderRadius.circular(AppRadius.xl)` (round 28 to 24)
- Replace `BorderRadius.circular(18)` → `BorderRadius.circular(AppRadius.lg)`
- Replace `BorderRadius.circular(40)` → `BorderRadius.circular(AppRadius.pill)` (for avatar circles)

**Elevation migration** (6 locations flagged in Wave 1 review):
- `crm_widgets.dart:38` → `AppTokens.elevation1(tokens == AppTokens.dark())`
- `crm_widgets.dart:236` → `AppTokens.elevation1(...)`
- `shell_screen.dart:162` → `AppTokens.elevation1(...)`
- `shell_screen.dart:214` → `AppTokens.elevation2(...)`
- `contact_profile_screen.dart:213` → `AppTokens.elevation1(...)`
- `auth_screen.dart:255` → `AppTokens.elevation1(...)`

**Icon size standardization**:
- Small icons (list row, inline): 20-24pt
- Medium icons (buttons, headers): 28-32pt
- Large icons (hero, empty state): 40-48pt
- Audit all `Icon(size: X)` and round to nearest standard size

**Modal consistency**:
- All modals use `AppSpacing.space5` (24pt) padding
- All modal titles use `AppTypography.h1()`
- All modal action buttons use consistent height (48pt)
- All bottom sheets use `AppRadius.lg` top corners

### Phase 3: Layout Pattern Consistency

**Card spacing**:
- All `CardBox` children use `AppSpacing.space5` padding (already default, verify)
- All cards have `AppSpacing.space4` (16pt) bottom margin (currently hardcoded as `16`)

**List row spacing**:
- All list items (contacts, events, recommendations) use consistent internal padding
- Gap between list items: `AppSpacing.space3` (12pt)

**Page padding**:
- All tab screens use `EdgeInsets.fromLTRB(AppSpacing.space6, AppSpacing.space6, AppSpacing.space6, 126)` for bottom nav clearance
- All modal/sheet screens use `EdgeInsets.all(AppSpacing.space5)`

**Button sizing**:
- All primary action buttons: min height 48pt (WCAG touch target)
- All icon buttons: 44×44pt touch target (already enforced in BondRing, apply everywhere)

### Phase 4: Verification

- Run `rg "EdgeInsets\.(fromLTRB|all|symmetric|only)\([0-9]" lib/` → should return zero raw numbers (all via tokens)
- Run `rg "SizedBox\((width|height): [0-9]" lib/` → should return zero raw numbers
- Run `rg "BorderRadius\.circular\([0-9]" lib/` → should return zero raw numbers
- Run `rg "Color\(0x[0-9A-F]{8}\)" lib/src/widgets lib/src/features` → should return zero (all shadows via tokens)
- `flutter analyze` clean
- Visual smoke test: all screens render correctly with new spacing/radius

## What to build

A comprehensive consistency pass that tokenizes spacing, radius, and elevation, then migrates all UI surfaces to use those tokens. The result is a codebase where every spacing/sizing decision is intentional and documented.

## Acceptance criteria

- [ ] `AppSpacing` class exists with space1-space8 constants (4px to 48px)
- [ ] `AppRadius` class exists with sm/md/lg/xl/pill constants
- [ ] `AppTokens.elevation0/1/2` static methods exist, returning light/dark-aware shadows
- [ ] All `EdgeInsets` in `lib/src/features` and `lib/src/widgets` use `AppSpacing.*` (zero raw numbers)
- [ ] All `SizedBox` dimensions use `AppSpacing.*` (zero raw numbers)
- [ ] All `BorderRadius.circular` use `AppRadius.*` (zero raw numbers)
- [ ] All `BoxShadow` color values use `AppTokens.elevation*` (zero raw hex in shadows)
- [ ] Icon sizes standardized to 20/24/28/32/40/48pt semantic scale
- [ ] All modals use consistent padding (`AppSpacing.space5`)
- [ ] All cards use consistent bottom margin (`AppSpacing.space4`)
- [ ] `flutter analyze` clean
- [ ] Existing widget tests pass (spacing changes should not break structural tests)
- [ ] Visual smoke test: no layout regressions, everything looks tighter and more consistent

## Blocked by

- #009 (design tokens): needs `AppTokens` infrastructure
- #010 (typography): needs `AppTypography` for modal titles

## Wave

Wave 3 (polish). Should be done after all other Wave 3 features (#015-#019, #024) are complete, as the final consistency pass before Wave 4 animations.

## Notes

This is a **large but mechanical** change. Consider using a script or regex-based refactor for the migration phase. The agent should:
1. Add the token systems first
2. Migrate one file at a time, commit frequently
3. Verify `flutter analyze` after each batch
4. Do NOT change behavior, only spacing/sizing values

If any spacing/radius value doesn't fit the scale (e.g., `26` doesn't map cleanly to `space6: 32`), round to the nearest token value and note the change in the commit message. The goal is consistency, not pixel-perfect preservation of arbitrary values.
