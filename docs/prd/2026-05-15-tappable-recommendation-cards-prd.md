# Tappable Recommendation Cards PRD

## Problem Statement

During the usability test, the script asks the participant to find a person in Top Recommendation and "find out why the app thinks you should talk to them." Today the recommendation cards on the Home tab and on the Outreach Recommendations screen are read-only. There is no way to drill into a recommended contact, so the participant has no obvious place to go to confirm the reasoning behind a recommendation.

## Solution

Make each recommendation card tappable. Tapping a card on the Home tab or on the Outreach Recommendations screen opens that contact's Personal Connection Dashboard, which already presents the AI Insight, recommended action, bond score, and history that explain why the relationship was surfaced. A trailing chevron on each card signals that the card is tappable.

## User Stories

1. As a usability test participant, I want to tap a recommended contact on the Home tab, so that I can see why the app suggests I reach out to them.
2. As a usability test participant, I want to tap a recommended contact on the Outreach Recommendations screen, so that I can review their full context before contacting them.
3. As a usability test participant, I want a visual cue on each recommendation card, so that I understand the card is interactive.
4. As a usability test participant, I want tapping a recommendation to land me on the contact's Personal Connection Dashboard, so that I can see the AI Insight and recommended action.
5. As a usability test participant, I want to be able to return to the previous screen, so that I can continue browsing recommendations.
6. As a project evaluator, I want the recommendation flow to match the usability script, so that I can score "find out why" behavior fairly.
7. As a developer, I want a single recommendation card module to handle the tap behavior, so that the Home tab and Recommendations screen share the same interaction without duplication.
8. As a developer, I want widget tests covering the tap behavior in both surfaces, so that this scripted task is regression-protected.

## Implementation Decisions

- The recommendation card module gains an optional tap callback. The Home tab and the Outreach Recommendations screen both pass a callback that navigates to the corresponding contact's Personal Connection Dashboard.
- The card surfaces a trailing chevron to indicate it is interactive.
- Existing card content (reason, AI insight quote, bond score, priority chip, category chip) stays the same.
- Navigation uses the existing contact route. No new routes or screens are added.
- No changes to recommendation data, ordering, or filtering.
- No changes to the Personal Connection Dashboard itself; the AI Insight section already serves the "why" question.

## Testing Decisions

- Good tests verify external behavior visible to a participant: tapping a recommendation opens the right contact's profile.
- The recommendation card module is exercised through the surfaces that use it (Home tab and Outreach Recommendations screen) rather than tested in isolation, because its tap behavior only matters in those contexts.
- New widget tests live alongside the existing widget tests and follow the same pattern: pump the app, sign in, navigate to the surface, tap, and assert the dashboard is showing.
- Prior art for assertions on the contact dashboard exists in the current widget tests that open Jessica Taylor's profile.

## Out of Scope

- Changes to which contacts are recommended or the priority order.
- Real AI-driven reasoning content (the existing static reasoning remains).
- New animations, haptics, or other interactive embellishments.
- Inline expand-in-place "why" panels on the card itself.
- Changes to other tappable surfaces such as People list cards, Planner events, or Heatmap cells.

## Further Notes

This PRD supports usability test task 2: "From the Home Page, find the Top Recommendation area and click on it. Once there, pick one person and try to find out why the app thinks you should talk to them."
