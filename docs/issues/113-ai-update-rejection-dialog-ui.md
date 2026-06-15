# #113 — AI Update Rejection Dialog UI

**Parent PRD:** Bot Guardrails / RAG-style Content Filtering (grilled 2026-06-14)

**Blocked by:** #112 (needs `AiUpdateRejected` exception class)

---

## What to build

Wire the new `AiUpdateRejected` exception into `AiUpdateScreen` and show a dialog when the
classifier rejects the user's input.

### UI changes

1. **New loading phase label**: `AiUpdateScreen` gains a local `_loadingLabel` state string.
   - Initial value: `"Checking your input…"` (phase 1, classifier running).
   - Updated to `"Reading what you've shared with $firstName…"` when `LlmAiUpdate` fires
     `onClassifierPassed`.
   - The existing loading view `Text(...)` renders `_loadingLabel` instead of the hardcoded string.

2. **Rejection dialog**: When `submit()` catches `AiUpdateRejected`, it:
   - Returns the screen to `AiUpdateState.inputting`.
   - Shows `showDialog(...)` with:
     - **Title**: "Not quite a relationship update"
     - **Body**: `e.reason` (the LLM's warm, specific explanation).
     - **Single action**: "Got it" dismisses the dialog. User's typed text and attachments are
       preserved exactly as-is.
   - Does NOT show a snackbar (unlike the existing `AiUpdateFailure` path).

3. **Cancel button availability**: the Cancel button in the loading view must remain accessible
   during phase 1 (classifier) and phase 2 (main call). No change needed if it already listens to
   `cancelGenerating()`.

### Catch arm in `submit()`

```dart
} on AiUpdateRejected catch (e) {
  if (mounted) {
    setState(() => currentState = AiUpdateState.inputting);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not quite a relationship update'),
        content: Text(e.reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
```

(Insert this catch arm **before** the `on AiUpdateFailure` arm so the more specific class is
caught first.)

---

## Acceptance criteria

- [ ] Loading view label is `"Checking your input…"` at the start of `submit()`.
- [ ] Label updates to `"Reading what you've shared with $firstName…"` when
      `onClassifierPassed` fires.
- [ ] `AiUpdateRejected` is caught before `AiUpdateFailure` in `submit()`.
- [ ] Rejection shows a dialog with title "Not quite a relationship update" and body = `e.reason`.
- [ ] Dialog has a single "Got it" button that dismisses back to the input screen.
- [ ] User's typed text and attachments are preserved after dismissing the dialog.
- [ ] Cancel button remains functional during the classifier phase (phase 1).
- [ ] Widget test: `failOnRelevanceCheck = true` on `MockAiUpdate` → dialog appears with the
      injected reason string.
- [ ] Widget test: `onClassifierPassed` fires → label transitions from "Checking…" to "Reading…"
      before the result appears. (Can be tested via a slow-mock that delays.)
- [ ] `flutter test test/features/ai_update_preview_test.dart` green (no regressions).
- [ ] `dart analyze` clean on touched files.

---

## Blocked by

#112 — `AiUpdateRejected` exception and `MockAiUpdate.failOnRelevanceCheck` must exist first.
