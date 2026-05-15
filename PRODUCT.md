# Product

## Register

product

## Users

Two overlapping audiences who share one underlying problem: **the working memory needed to maintain relationships exceeds what they have available.**

**Busy professionals.** People with full lives who feel quiet guilt about losing touch with family and friends. They want to be the kind of person who remembers a college friend's job interview or texts their mom on a Tuesday for no reason. They don't have time to be that person without help. They open the app in 30-second windows: a commute, a moment before bed, between meetings.

**People with ADHD or working memory differences.** Same problem, sharper edges. Forgetting isn't a guilt trip, it's a daily structural reality. They benefit from external systems that hold relationship state for them. They abandon any app that punishes them for the bad weeks. Predictability matters more than features — surprise notifications, ambiguous primary actions, and unexplained state changes are catastrophic.

The job to be done, screen by screen: **"who should I reach out to right now, and what was going on with them last time?"**

## Product Purpose

A personal CRM that does the remembering for you, then nudges gently. It tracks relationships, not "deals." It helps you stay connected, it doesn't grade your performance.

**Core loop:** capture (paste a chat, type a quick note) → AI parses into a structured update → app surfaces who's drifting and why → user reaches out → bond ring fills → repeat.

**Success looks like:** a user opens the app, sees one friend they'd forgotten, sends a real message, closes the app. The whole interaction takes under two minutes and the user feels good about themselves, not surveilled by them.

## Brand Personality

Playful, encouraging, with bold accents. Warm voice on a calm surface, with vibrant color and motion reserved for moments that matter.

The app sounds like a thoughtful friend who's good at remembering names, not like Salesforce or Headspace. It uses second-person, never imperative. It says *"Wondering how Mike's job hunt went?"* not *"FOLLOW UP: Mike Chen — high priority."* It celebrates without performing — a bond ring filling is enough; no confetti, no streak counter, no "Level 7 Connector" badge.

Three-word personality: **considerate, present, light**.

## Anti-references

Specific patterns this product must not become:

- **Salesforce / HubSpot CRM.** No "leads," no "deal stages," no "follow-up actions" framed as ticket statuses. Friendships are not pipelines.
- **Generic SaaS dashboard.** No giant gradient hero metrics, no "Welcome back, Alex 👋", no chart-card grids. The dashboard ("Home") is a small, calm set of nudges, not a performance report.
- **Streak-pressure apps** (Snapchat streaks, BeReal countdowns, Duolingo's "you broke your streak" guilt). Predictable cadence, never penalize gaps.
- **Gamified self-help with XP and levels.** No user-facing point totals, no level-ups for the user, no "you're 60 points from Level 8." (Per-friend bond score stays — it's information about the relationship, not a grade for the user.)
- **AI-startup-2025 lookbook.** Vibrant purple primary + AI sparkles is a known cliché. Personality is in the copy, the empty states, and the bond ring — not in personifying the AI.
- **Anthropomorphized AI assistant.** No chat bubbles from an AI character, no "Hi! I noticed you haven't talked to..." — the AI does work silently, then shows the user a preview to confirm.

## Design Principles

1. **Never shame the user.** No streaks, no red overdue badges, no "you haven't contacted X in 67 days" copy, no guilt framing. The app helps you do better; it never tells you you're failing. Every screen passes the test: *would a person feel judged reading this?*

2. **Memory aid, not productivity tool.** The app's job is to offload remembering, not to make you efficient. Features are judged by *does this help someone remember a friend?* not *does this make relationship management more optimal?* Friendships are not workflows.

3. **Quiet by default, warm at peak moments.** The interface is restrained 90% of the time — neutral surfaces, calm copy, no decoration for its own sake. Vibrant color, signature motion, and emotive copy show up only at peak moments: a bond ring filling after an update, an AI preview revealing parsed interactions, an empty state that says *"you're in touch with everyone right now."*

4. **AI is in the input, not the output.** AI parses what the user already wrote; it does not generate suggestions out of thin air, does not speak in an AI character's voice, and never silently mutates state. Every AI-driven change goes through a preview-and-confirm step. AI-generated content carries a small ✨ tag and an undo affordance.

5. **Show relationship state, never grade it.** The per-friend bond score is visible (because it offloads working memory) but it is *visualized*, not announced. A filled ring around an avatar communicates state; a number on a card grades a friendship. Tap to reveal the number for users who want precision; everyone else gets the shape.

## Accessibility & Inclusion

**Target: WCAG 2.1 AA.** Verified at design time, not "we'll check at the end."

**Specific requirements:**

- **Reduced motion.** `MediaQuery.of(context).disableAnimations` (Flutter's `prefers-reduced-motion`) collapses all motion to instant cuts or short fades. Both signature moments (bond ring fill, AI preview stagger) become instant when reduced motion is enabled. Non-negotiable: the audience overlap with motion sensitivity is high.

- **Touch targets ≥ 44x44pt.** Every interactive element. Especially: avatar+ring tap target on dense People rows (the ring is small visually, the tap area must not be), category filter chips, day cells in the calendar.

- **Contrast.** All text-bearing color hits ≥ 4.5:1 against its surface (3:1 for ≥18pt text). The vibrant secondary (#FF8C00) and tertiary (#FF71CF) cannot carry text on light surfaces — they are reserved for fills, large icons, and illustration. Primary text uses #1A1A1A on light, near-white on dark.

- **Screen reader.** Every interactive element has a semantic label. Bond rings announce as "Sarah, close, trending up" not "75 percent." Empty-state copy is the only content of those screens — it must be readable.

- **Predictability for ADHD users.** No surprise modal popups, no auto-saving destructive changes, no actions that happen without an explicit user gesture. Notifications (when implemented) arrive on a single predictable weekly schedule. Undo is available for every state change.

- **Cognitive load ceilings.** Three primary tabs maximum. The + sheet has exactly three actions. Decision points present at most four options at a time. Forms are short — anything longer than four fields gets staged or split.

## Strategic decisions captured

These are the design-shaping decisions made during the teach interview. Listed here so future work can be checked against them:

- **Three tabs:** Home, People, Plan. Settings lives behind a route, not a tab. No global Activity tab — interaction history lives on each contact's profile.
- **Single + sheet:** Add Connection / Update Connection / Plan Event. No FAB-menu sprawl.
- **Update Connection is the single AI door:** free-text input, AI parses and categorizes, preview-and-confirm before save.
- **Onboarding:** hybrid. Sample friends visibly tagged on first run, prominent "paste your contacts" import path, sweep-remove for samples.
- **Theme:** tri-state (system / light / dark), system default.
- **Color strategy:** Full palette with assigned semantic roles. Vibrant accents on a calm surface, ≤25% saturated-color coverage on any screen.
- **Notifications:** opt-in, one weekly digest, predictable schedule. (Strategic commitment; implementation may follow.)
- **Empty states:** warm and resting. Absence is reframed as a positive when possible.
- **Bond score visualization:** filled avatar ring + trend arrow, tap to reveal number, never displayed as "X/100" on a card.
- **Removed entirely:** user-level XP/points/levels, "priority" pills on recommendations, the global Activity tab.
