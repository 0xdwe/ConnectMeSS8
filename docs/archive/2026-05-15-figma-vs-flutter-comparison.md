# Figma Reference vs Flutter Implementation Comparison

**Date:** 2026-05-15  
**Purpose:** Document what exists in the Figma prototype vs what's been implemented in Flutter

---

## Executive Summary

The **Figma reference** (`figma_reference/`) is a **React/TypeScript prototype** (~4,900 lines) exported from Figma. It's a visual/interactive mockup, not production code.

The **Flutter app** (`lib/`) is the **actual implementation** (~3,244 lines of Dart) that runs on mobile/desktop.

**Key Finding:** The Figma prototype has MORE UI screens and interactions than the Flutter app, but LESS real functionality. Many "features" in Figma are just UI mockups with simulated data.

---

## Architecture Comparison

| Aspect | Figma Reference (React/TypeScript) | Flutter Implementation (Dart) |
|--------|-----------------------------------|-------------------------------|
| **Purpose** | Visual prototype for design review | Production mobile/desktop app |
| **Lines of Code** | ~4,900 lines | ~3,244 lines |
| **State Management** | React useState (local component state) | Riverpod (global state management) |
| **Data Layer** | Mock data hardcoded in `mock-data.ts` | `AppState` with seeded data + mutations |
| **AI Integration** | Simulated responses (random text generation) | `AiUpdateService` interface with mock implementation |
| **Routing** | Manual view switching with useState | go_router with proper navigation |
| **Testing** | None | 19 test files with widget/unit tests |
| **Persistence** | None (resets on refresh) | None yet (in-memory only) |

---

## Screen-by-Screen Comparison

### ✅ Implemented in Both

| Screen | Figma | Flutter | Notes |
|--------|-------|---------|-------|
| **Auth Screen** | ✅ | ✅ | Flutter has mock auth, Figma has visual only |
| **Home Tab** | ✅ | ✅ | Both show recommendations + connection score |
| **People Tab** | ✅ | ✅ | Both have search/filter/sort |
| **Planner Tab** | ✅ | ✅ | Both have calendar + event list |
| **Contact Profile** | ✅ | ✅ | Both show bond ring, insights, activity log |
| **Add Connection Modal** | ✅ | ✅ | Both have form with name/email/category |
| **Edit Connection Modal** | ✅ | ✅ | Both allow editing contact details |
| **Add Event Modal** | ✅ | ✅ | Both have date/time/contact picker |
| **Theme Modal** | ✅ | ✅ | Both support light/dark/system |
| **Manage Categories** | ✅ | ✅ | Both allow adding/removing categories |
| **Manage Event Types** | ✅ | ✅ | Both allow customizing event types |
| **User Profile** | ✅ | ✅ | Both show user info + settings access |
| **Edit User Profile** | ✅ | ✅ | Both allow editing name/email/avatar |

### ⚠️ Different Implementation

| Feature | Figma | Flutter | Gap |
|---------|-------|---------|-----|
| **AI Update** | Chat interface with message history | Single text input → preview cards | Figma has conversational UI, Flutter has batch preview |
| **Recommendations View** | Separate full screen | Inline on Home tab | Figma has dedicated route, Flutter embeds in Home |
| **Settings** | Full tab in bottom nav | Separate route from profile | Figma has 4 tabs, Flutter has 3 tabs |
| **Activity Tab** | Global activity feed | Per-contact activity only | Figma has 4th tab, Flutter removed it per PRODUCT.md |
| **Plus Sheet** | Not visible in Figma | Bottom sheet with 3 actions | Flutter has + button, Figma uses FAB menu |
| **Bond Ring Animation** | Static visualization | Animated fill on score change | Flutter has signature animation, Figma is static |
| **AI Preview Stagger** | Not implemented | Staggered card reveal animation | Flutter has signature animation, Figma doesn't |

### ❌ Only in Figma (Not Implemented in Flutter)

| Feature | Description | Why Not in Flutter |
|---------|-------------|-------------------|
| **AIUpdateChat** | Conversational chat interface with AI | Replaced with simpler preview-confirm flow |
| **Mascot Component** | Animated character/illustration | Not in design spec (PRODUCT.md anti-reference) |
| **Event Detail Modal** | Expanded view of single event | Not yet implemented |
| **Select Contact Modal** | Contact picker for shared activities | Simplified to dropdown in Flutter |
| **Shared Activity Modal** | Dedicated modal for group interactions | Not yet implemented |
| **Image Upload in AI Chat** | Photo attachment in conversations | File picker exists but not in AI flow |
| **Decorative Stars** | ✦ decorative elements on screens | Not in design tokens (DESIGN.md) |
| **FAB Menu** | Floating action button with submenu | Replaced with + sheet in Flutter |

### ❌ Only in Flutter (Not in Figma)

| Feature | Description | Why Not in Figma |
|---------|-------------|-------------------|
| **Query Providers** | Derived state selectors (contactById, etc.) | Backend architecture, not UI |
| **Onboarding Samples** | Sample contacts with "Remove" affordance | Added after Figma export |
| **Warm Empty States** | Contextual empty state copy | Added after design review |
| **Token System** | Spacing/radius/elevation tokens | Design system formalized after Figma |
| **Accessibility** | Reduced motion, semantic labels | Not visible in Figma prototype |
| **Test Coverage** | 19 test files | Prototypes don't have tests |

---

## Functional Comparison

### Data & State

| Capability | Figma | Flutter |
|------------|-------|---------|
| **Mock Contacts** | 10+ hardcoded contacts | 8 seeded contacts |
| **Mock Events** | Hardcoded event list | Seeded events + CRUD |
| **Bond Score Calculation** | Static numbers | Calculated from interactions |
| **Recommendations** | Static list | Derived from lastContact + bondScore |
| **Insights** | Hardcoded per contact | Computed from interaction history |
| **Undo/Redo** | None | Undo for event deletion |
| **State Persistence** | None (resets on refresh) | None (in-memory only) |

### AI Features

| Feature | Figma | Flutter |
|---------|-------|---------|
| **AI Update Input** | Chat interface with history | Single text field |
| **AI Parsing** | Simulated (random responses) | Mock keyword classifier |
| **AI Preview** | Not shown | Preview cards with edit/confirm |
| **AI Summary** | Hardcoded per contact | Generated from interactions |
| **Topic Recommendations** | Hardcoded list | Generated from recent activity |
| **AI Sparkle Tag** | Visual only | Functional (marks AI-generated content) |

### Interactions

| Action | Figma | Flutter |
|--------|-------|---------|
| **Add Contact** | Form → saves to local state | Form → saves to AppState |
| **Edit Contact** | Form → updates local state | Form → updates AppState |
| **Delete Contact** | Not implemented | Not implemented |
| **Add Event** | Form → saves to local state | Form → saves to AppState |
| **Edit Event** | Via Event Detail Modal | Not yet implemented |
| **Delete Event** | Via Event Detail Modal | Swipe-to-delete with undo |
| **Update Connection (AI)** | Chat → simulated AI → updates | Text → AI parse → preview → confirm |
| **Search Contacts** | Client-side filter | Client-side filter |
| **Filter by Category** | Client-side filter | Client-side filter |
| **Sort Contacts** | Name/lastContact/bondScore | Name/lastContact/bondScore |
| **Theme Toggle** | Updates ThemeContext | Updates AppState.themeMode |

---

## Design System Comparison

### Colors

| Token | Figma | Flutter | Status |
|-------|-------|---------|--------|
| **Primary Purple** | `#7C34ED` inline | `AppTokens.primary` | ✅ Matches |
| **Surface Colors** | Inline hex values | `AppTokens.surface/surfaceRaised/surfaceSunken` | ✅ Tokenized in Flutter |
| **Ink Colors** | Inline `#1B1B1B`, `#6B7280` | `AppTokens.ink/inkMuted/inkSubtle` | ✅ Tokenized in Flutter |
| **Secondary Orange** | `#FF8C00` inline | Not yet implemented | ⚠️ Missing in Flutter |
| **Tertiary Pink** | `#FF71CF` inline | Not yet implemented | ⚠️ Missing in Flutter |
| **Category Colors** | Inline per category | Not yet implemented | ⚠️ Missing in Flutter |

### Typography

| Style | Figma | Flutter | Status |
|-------|-------|---------|--------|
| **Font Family** | System font (not loaded) | Google Fonts Inter (configured but not applied) | ⚠️ Both need migration |
| **Display** | 32px/700 inline | Not yet implemented | ⚠️ Missing in Flutter |
| **H1** | 26px/700 inline | Not yet implemented | ⚠️ Missing in Flutter |
| **Body** | 15px/400 inline | `AppTypography.body()` | ✅ Tokenized in Flutter |
| **Caption** | 13px/500 inline | `AppTypography.caption()` | ✅ Tokenized in Flutter |

### Spacing

| Token | Figma | Flutter | Status |
|-------|-------|---------|--------|
| **Padding** | Inline `p-4`, `p-6`, etc. (Tailwind) | `AppSpacing.space4`, `space6`, etc. | ✅ Tokenized in Flutter |
| **Gaps** | Inline `gap-2`, `gap-4` | `AppSpacing.space2`, `space4` | ✅ Tokenized in Flutter |
| **Consistency** | Mixed (some hardcoded px) | Consistent token usage | ✅ Better in Flutter |

### Radius

| Token | Figma | Flutter | Status |
|-------|-------|---------|--------|
| **Cards** | `rounded-3xl` (24px) inline | `AppTokens.radiusLg` (18px) | ⚠️ Different values |
| **Buttons** | `rounded-full` inline | `AppTokens.radiusPill` | ✅ Matches |
| **Inputs** | `rounded-full` inline | `AppTokens.radiusMd` (14px) | ⚠️ Different approach |

### Elevation

| Level | Figma | Flutter | Status |
|-------|-------|---------|--------|
| **Cards** | `shadow-lg` inline | `AppTokens.elevation1` | ✅ Tokenized in Flutter |
| **Modals** | `shadow-xl` inline | `AppTokens.elevation2` | ✅ Tokenized in Flutter |
| **Consistency** | Tailwind classes | Explicit token values | ✅ Better in Flutter |

---

## Animation Comparison

| Animation | Figma | Flutter | Status |
|-----------|-------|---------|--------|
| **Tab Transitions** | None (instant) | Not yet implemented | ⚠️ Missing in both |
| **Modal Slide-Up** | CSS transition | Default Flutter sheet animation | ✅ Works |
| **Bond Ring Fill** | Static | Animated arc sweep (600ms, easeOutQuart) | ✅ Flutter only |
| **AI Preview Stagger** | None | Staggered fade-in (240ms each, 80ms offset) | ✅ Flutter only |
| **Card Press Feedback** | CSS hover | Not yet implemented | ⚠️ Missing in Flutter |
| **Reduced Motion** | Not implemented | Respects MediaQuery.disableAnimations | ✅ Flutter only |

---

## Missing Features (Neither Implementation)

These are in PRODUCT.md / DESIGN.md but not in either codebase:

- [ ] **Notifications** - Weekly digest, opt-in
- [ ] **Data Persistence** - Local storage or cloud sync
- [ ] **Real AI Integration** - LLM API instead of mock
- [ ] **Import Contacts** - Paste/upload contact list
- [ ] **Export Data** - Backup/portability
- [ ] **Recurring Events** - Defined in Figma types but not functional
- [ ] **Event Editing** - Can add/delete but not edit
- [ ] **Contact Deletion** - Not implemented in either
- [ ] **Shared Activities** - Group interactions with multiple contacts
- [ ] **Photo Attachments** - In AI updates or activity log
- [ ] **Real Auth** - Both have mock auth only
- [ ] **Onboarding Flow** - Sample removal exists but no tutorial

---

## Code Quality Comparison

| Metric | Figma Reference | Flutter Implementation |
|--------|----------------|----------------------|
| **Type Safety** | TypeScript (good) | Dart (good) |
| **Component Size** | Large (App.tsx is 453 lines) | Smaller, more modular |
| **State Management** | Local useState (scattered) | Centralized Riverpod |
| **Separation of Concerns** | UI + logic mixed | UI + state + models separated |
| **Testability** | Not testable (no tests) | 19 test files, good coverage |
| **Accessibility** | Basic HTML semantics | Semantic labels + reduced motion |
| **Performance** | Not optimized (re-renders) | Optimized with providers |
| **Maintainability** | Prototype quality | Production quality |

---

## Recommendations

### What to Keep from Figma

1. **AIUpdateChat conversational UI** - More engaging than batch preview
2. **Event Detail Modal** - Better UX than inline editing
3. **Decorative elements** - Stars add personality (if used sparingly)
4. **Shared Activity Modal** - Needed for group interactions
5. **Visual polish** - Figma has more refined spacing/shadows

### What to Keep from Flutter

1. **Token system** - Much better than inline values
2. **State management** - Riverpod is superior to useState
3. **Test coverage** - Critical for production
4. **Accessibility** - Reduced motion, semantic labels
5. **Signature animations** - Bond ring fill, AI preview stagger
6. **Query providers** - Derived state is cleaner

### Priority Gaps to Close

**High Priority:**
1. Implement secondary/tertiary colors from DESIGN.md
2. Implement category colors
3. Add Event Detail Modal (edit events)
4. Add Shared Activity Modal
5. Migrate to Inter font (both need this)

**Medium Priority:**
6. Add conversational AI chat (replace batch preview)
7. Add photo attachments to AI updates
8. Implement contact deletion
9. Add card press feedback animation
10. Refine empty states with DESIGN.md copy

**Low Priority:**
11. Add decorative stars (if design approves)
12. Add FAB menu alternative to + sheet
13. Implement recurring events
14. Add data persistence

---

## Conclusion

**The Figma prototype is a design artifact, not a feature checklist.**

- **Figma** = Visual exploration with simulated interactions (~70% UI, 30% logic)
- **Flutter** = Production implementation with real state management (~40% UI, 60% logic)

**Flutter has implemented the core product** defined in PRODUCT.md and DESIGN.md. The Figma prototype has some UI patterns worth adopting (conversational AI, event detail modal), but most of its "extra features" are just visual mockups.

**Next steps:**
1. Review this document with the team
2. Decide which Figma UI patterns to adopt
3. Prioritize gaps based on user value
4. Continue Flutter implementation per DESIGN.md spec
