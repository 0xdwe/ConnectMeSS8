# Contact AI Insights Design

## Summary
Add an AI Insights section to the personal connection dashboard. The feature uses a hybrid design: mock rule-generated insights now, shaped as a future AI response so a real agent can replace the generator later without redesigning the UI.

The chosen layout is the Insight-First Hybrid: the contact header remains at the top, then the dashboard shows Bond Score and Recommended Action side by side, followed by the primary AI Insight card.

## Goals
- Make each contact profile feel like a relationship dashboard, not only a profile page.
- Show why the user should reconnect, how much bond score they may gain, and which channel to use.
- Keep the UI close to the provided Figma reference while improving hierarchy for mobile.
- Keep all data local/mock for now, but define model seams for future real AI output.

## Data Model
Extend `Connection` with:
- `knownSince`: DateTime or year-based field for known-since display.
- `preferredChannels`: ordered list of strings, such as `Instagram`, `Text`, `FaceTime`.

Add `ContactInsight` model:
- `contactId`
- `summary`: primary AI insight text.
- `why`: expandable reasoning/detail text.
- `recommendedAction`: user-facing suggested action.
- `potentialScoreGain`: integer percent gain, such as `8`.
- `relationshipLabel`: display category/relationship label.
- `knownSinceYears`: computed/display integer.
- `frequencyByMonth`: 12 integer values for interaction frequency.
- `aiConfidence`: optional future field, not shown in v1 unless useful.

Add `AppState.contactInsightFor(contactId)`:
- Computes a mock insight from the selected contact and interactions.
- Uses last-contact gap, bond score, next step, notes, channels, and monthly interaction counts.
- Returns future-AI-shaped data so later AI service can replace the generator.

## UI Design
Contact profile screen should become screenshot-like:
- Teal header with avatar, name, and email.
- First content row: Bond Score card and Recommended Action card showing `+X%` gain.
- Primary yellow `AI Insight` card below the top row.
- AI Insight card expands/collapses to show `why` details.
- Relationship facts card: category, known since, last contact.
- Top Communication Channels card: channel chips from `preferredChannels`.
- Interaction Frequency card: 12-month bar row from `frequencyByMonth`.
- Existing history remains lower on the page as secondary content.

## Behavior
- Insight recalculates when contact history changes through AI Update.
- `potentialScoreGain` mock rule gives higher gain to stale contacts with lower/medium scores, and lower gain to recent strong bonds.
- Recommended action uses `nextStep` first, then falls back to generated reconnect copy.
- Frequency bars count local interactions by month now. Future AI can override with richer intensity data.
- No real AI API, backend, or persistence in this feature.

## Testing
- State test: `contactInsightFor('jessica')` returns a primary insight, gain, channels, known-since data, and 12 monthly frequency values.
- Widget test: contact profile renders AI Insight, Recommended Action gain, channel chips, and frequency bars.
- Widget test: tapping AI Insight expands/collapses `why` details.
- Existing auth, nav, profile, plus-flow, and state tests continue passing.

## Explicit Defaults
- Layout choice: Insight-First Hybrid.
- AI source: hybrid mock generator now, future AI-compatible model.
- AI Insight count: one primary insight with expandable reasoning.
- Recommended gain: future-AI field mocked now.
- Channels: profile field now, future AI-updatable later.
- Frequency: computed from history now, future AI-overridable later.
