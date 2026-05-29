# #079 Image attachment preparation for AI Update

Labels: issue, needs-triage

**Status: shipped on `main` (commit `34928d2`, 2026-05-29).**

## Parent

docs/prd/2026-05-27-llm-ai-update-pass-4-3-prd.md

## What to build

Pure-Dart preparation pipeline that turns a list of `AttachmentRef` values into the inputs `LlmAiUpdate` will hand to Gemini in #080: image-type detection, downscale + JPEG re-encode, per-call cap, and soft-fail fallbacks for unreadable / unsupported / oversize attachments.

This issue does not yet call Gemini. It produces a tested module the adapter will consume.

Per PRD §Q7:
- Supported image MIME types (jpeg, png, webp, heic) become inline image parts.
- Non-image attachments stay name-only and are mentioned in the prompt.
- Per-call cap is 4 images; additional images degrade to name-only.
- Image-read or resize failure soft-fails that one image; the run continues with that attachment treated as name-only.
- All-images-failed-with-no-useful-text is the only hard-fail path; that hard-fail is wired into `LlmAiUpdate` in #080.

## Acceptance criteria

- [x] New module under `lib/src/ai/` (e.g. `attachment_preparer.dart`) exposes a small interface that takes a list of `AttachmentRef` and returns prepared image parts + name-only references.
- [x] Image format detection uses MIME / extension; supported set: jpeg, png, webp, heic.
- [x] Image downscale to max 1024×1024 with JPEG quality ~85 before encoding to bytes. Implementation may use the `image` Dart package or platform image APIs — exact dependency choice is left to the worker. — **Used `image: ^4.5.4` (pure Dart, runs under `flutter test` without platform channels).** EXIF orientation is baked before resize so portrait phone photos don't reach Gemini sideways.
- [x] Per-call cap of 4 images enforced; additional images are returned as name-only entries. — **Cap fires AFTER successful prepare so soft-failed images don't consume cap slots.**
- [x] Image-read or resize failure on an individual image returns it as name-only with a soft-error tag the caller can surface in the prompt context (e.g. "Attempted to attach garden_photo.jpg but couldn't read the file"). — **`AttachmentDegradeReason` enum: notAnImage, perCallImageCap, fileNotFound, readError, decodeError.**
- [x] Module is purely synchronous-or-async-Dart; no Firebase, no Riverpod, no Flutter `BuildContext`.
- [x] Unit tests cover: 0 attachments, 1 image, 4 images, 5+ images (cap), mixed image + non-image, unsupported image type, unreadable file path, oversize image (resize succeeds), corrupt image (resize fails → soft-fail).
- [x] Tests live under `test/state/ai/attachment_preparer_test.dart`. — **20 tests.**
- [x] No production behavior change yet; AI Update still uses `MockAiUpdate`.
- [x] `flutter analyze` clean for new files.
- [x] If a new dependency is added to `pubspec.yaml`, it is pinned and vendor-checked per AGENTS.md conventions.

## Test baseline

`flutter test test/state/`: **312 passed + 2 skipped** (was 292+2; +20 new tests).

## Reviewer notes for #080 follow-up

Reviewer (`.agent-runs/079-attachment-preparer-review.md`) flagged two nice-to-haves not blocking #079 merge:

1. Width/height post-resize math is duplicated between the main loop and `_downscaleAndEncode`. Could be tightened by returning `(bytes, width, height)` from the encoder. Defer until #080 touches this file.
2. `AttachmentDegradeReason.readError` only fires on empty bytes; reader-IO-throw flows into `fileNotFound`. Renaming to `emptyFile` (or splitting reader-throw into its own case) gives #081 modal UX better copy options. Defer until #081 actually needs it.

## Blocked by

#078
