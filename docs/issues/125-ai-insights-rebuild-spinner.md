# #125 — AI Insights Spinner for Pending Memory Rebuild

**Parent:** #121  
**Branch:** `feat/125-ai-insights-rebuild-spinner`  
**Triage:** `ready-for-agent`

---

## Parent

#121 — Delete Activity Log Entry + Rebuild Memory

## What to build

Make the AI Insights card show the refresh spinner while a memory rebuild is running, using a new provider so the manual refresh path stays unchanged.

End-to-end behavior:
- New `pendingMemoryRebuildProvider` holds the contact ID that needs a rebuild.
- `AppController.deleteInteraction` sets this provider after the undo window expires.
- `AiInsightsCard` watches the provider. When it matches the card's contact, it shows the header refresh spinner and runs the rebuild flow.
- The provider is cleared when the rebuild completes or fails.
- Manual "Refresh AI Insights" continues to use the lighter `MemoryTopicEnricher` path.

## Acceptance criteria

- [ ] `pendingMemoryRebuildProvider` is added and observable.
- [ ] `AppController.deleteInteraction` sets the provider for the affected contact.
- [ ] `AiInsightsCard` shows the refresh spinner when the provider matches its contact.
- [ ] Spinner clears after rebuild completes or fails.
- [ ] Manual refresh still performs topic-only enrichment.
- [ ] Widget tests verify the spinner appears during a pending rebuild.

## Blocked by

- #124 — `MemoryRebuilder` Seam and Full Memory Rebuild on Delete
