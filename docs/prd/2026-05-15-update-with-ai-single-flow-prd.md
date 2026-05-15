# Update with AI as the single update flow PRD

## Problem Statement

The usability test script asks the participant to "record the interaction by uploading a shared activity using the Update with AI feature." Today the app exposes two parallel flows that overlap in purpose: a Share Activity bottom sheet (note or photo path, plus a static AI Suggestion blurb) and an Update with AI full screen (free text and generic file attachments routed through a mock AI service). Participants have to discover and reason about both, the wording does not match the script, and only one of them actually runs the AI mock. Photos cannot be uploaded as part of an AI update either, even though the script implies image upload.

## Solution

Make Update with AI the only update flow. Remove the Share Activity bottom sheet and its entry points. Promote the Update with AI entry on the Personal Connection Dashboard from a tooltip-only icon to a labeled primary button. Inside the Update with AI screen, let the participant type their activity, story, or note, and upload images alongside any other file. The submitted text and image attachments are routed through the existing mock AI service, which sorts the input into a structured interaction and updates the dashboard. The Plus menu's Update Connection picker continues to land directly on the chosen contact's Update with AI screen (no behaviour change there).

## User Stories

1. As a usability test participant, I want a single update flow, so that I do not have to choose between Share Activity and Update with AI.
2. As a usability test participant, I want to type my activity or story freely, so that I can describe what happened with the contact.
3. As a usability test participant, I want to upload images alongside my note, so that I can attach photos from a meet-up.
4. As a usability test participant, I want to see image previews of what I attached, so that I can confirm I picked the right photos.
5. As a usability test participant, I want the Update with AI button on a contact's profile to be obvious, so that I can find it without hunting through icons.
6. As a usability test participant, I want the Plus menu's Update Connection action to take me to the chosen contact's Update with AI screen, so that I can update someone from anywhere in the app.
7. As a usability test participant, I want my submitted note and images to update the contact's history, so that I can see the result of the AI update.
8. As a project evaluator, I want the wording on the contact profile to match the script's "Update with AI" terminology, so that scripted task success can be measured fairly.
9. As a developer, I want the Share Activity surface and modal to be removed, so that there is one place to maintain update behaviour.
10. As a developer, I want widget tests covering the AI update flow with text and with images, so that this scripted task is regression-protected.
11. As a developer, I want existing tests that referenced Share Activity to be replaced with equivalent Update with AI tests, so that the test suite reflects current behaviour.

## Implementation Decisions

- The Share Activity modal and its bottom-sheet entry points are removed. Affected entry points include the Plus menu and the Personal Connection Dashboard.
- The Personal Connection Dashboard surfaces a single, labeled "Update with AI" button as its primary action, replacing the AI Update tooltip-only icon and the Share Activity icon.
- The Plus menu retains Add Connection and Update Connection. Update Connection continues to open the existing person picker which routes to the chosen contact's Update with AI screen.
- The Update with AI screen accepts free-form text and any combination of attachments. Attached images render as image previews; non-image attachments render as labeled chips, as today.
- Image picking reuses the existing file selector mechanism. No new platform integration is added in this slice.
- Submission continues to route through the existing mock AI categorization service, which writes a structured interaction to the contact's history and may update the dashboard.
- After submission, the screen returns to the previous screen, matching today's behaviour.
- Domain models for interactions and attachments are reused. No schema changes.
- Routing is unchanged: the Update with AI screen is reached via `/ai-update/:id`.

## Testing Decisions

- Good tests verify external behaviour through the public UI: navigating from a contact, entering content, optionally attaching an image, submitting, and observing the contact's history update.
- Existing widget tests that exercise Share Activity are replaced by widget tests that exercise the equivalent Update with AI flow.
- New widget tests cover the labeled Update with AI button on the Personal Connection Dashboard, the text-only AI update path, and the path with at least one image attachment showing as a preview.
- Plus-menu Update Connection picker behaviour stays covered by the existing widget test.
- Image picking is covered by injecting attachment values through the same seam used in current tests where possible. If platform-specific picking blocks tests, attach data is exercised at the screen level rather than through the OS picker dialog.
- Prior art exists in the current widget tests that pump the app, sign in, and navigate through the bottom navigation, modals, and routes.

## Out of Scope

- Real AI service integration. The mock AI categorization service stays in place.
- Real image storage, upload to a backend, EXIF parsing, or compression.
- Camera capture. Only the existing file/image selector is used.
- Voice or video attachments.
- Editing or deleting submitted AI updates.
- Changes to recommendations, planner, heatmap, settings, or auth flows.
- Changes to the Plus menu Add Connection flow.

## Further Notes

This PRD supports usability test task 3: "Imagine you just finished a meet-up with a friend named Emily. Go to the People section, find Emily, and record the interaction by uploading a shared activity using the Update with AI feature." The script's wording is preserved by surfacing the Update with AI label clearly on the contact profile and by allowing image upload alongside the note.

Work is sequenced into multiple commits, one per slice, to keep history reviewable.
