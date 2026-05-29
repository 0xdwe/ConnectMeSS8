/// Image attachment preparation for the [LlmAiUpdate] adapter
/// (Pass 4.3, PRD §Q7).
///
/// Turns a list of [AttachmentRef] values into the inputs that the
/// adapter in #080 will hand to Gemini: a bounded set of image bytes
/// for vision-enabled inputs, plus the names of every other
/// attachment for the prompt's name-only section.
///
/// What this module DOES:
///
/// - Detects image attachments by file extension (jpg, jpeg, png,
///   webp, heic).
/// - Reads the bytes, decodes them, downscales to a max bounding
///   box, and re-encodes as JPEG quality ~85 — small enough to keep
///   per-call image-token cost bounded, large enough for Gemini to
///   extract specific signal.
/// - Caps the per-call image set at [kMaxImagesPerCall] (PRD §Q7
///   default 4). Overflow images degrade to name-only.
/// - Soft-fails individual images: if a file is missing, unreadable,
///   undecodable, or too small to resize, that one image becomes a
///   name-only entry tagged with a short reason. The run continues.
/// - Produces a deterministic shape the adapter can hand to the
///   prompt builder + the SDK call site without further branching.
///
/// What this module does NOT do:
///
/// - It does not pick attachments from the camera roll. That's
///   `image_picker` already wired into the AI Update modal.
/// - It does not call Gemini. The SDK call lives in `LlmAiUpdate`
///   (#080). This module is a pure-Dart input pipeline.
/// - It does not persist images. Per PRD §Q7 the bytes leave the
///   device only as part of the in-flight Gemini request; the
///   *textual signal* extracted from the image is what gets
///   persisted into the MemoryDocument and CrmInteraction.
/// - It does not enforce a hard byte ceiling on the encoded JPEG.
///   The downscale + JPEG-85 path produces images well under
///   typical per-image token caps; if real-Gemini integration tests
///   in #082 surface a size issue, tighten here.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/social_models.dart';

/// Maximum number of images sent inline per AI Update call. Per PRD
/// §Q7 default 4. Additional images degrade to name-only.
const int kMaxImagesPerCall = 4;

/// Maximum bounding box (px) for the longest edge of an image after
/// downscale. Square 1024 keeps per-image token cost bounded
/// (Gemini Flash-Lite tokenizes images by tile; ~1024 sits around
/// 1k tokens worst case) and is enough resolution for the model to
/// pick out faces, places, and text.
const int kImageMaxDimension = 1024;

/// JPEG quality used by the re-encoder. 85 is the conventional
/// "indistinguishable from original" quality for natural images and
/// produces ~1/4 the byte size of quality 95.
const int kImageJpegQuality = 85;

/// Image attachment ready to be sent to Gemini as inline image
/// bytes. The MIME is always JPEG because the preparer re-encodes
/// regardless of source format — keeps the SDK call site uniform.
class PreparedImageAttachment {
  const PreparedImageAttachment({
    required this.name,
    required this.bytes,
    this.width,
    this.height,
  });

  final String name;
  final Uint8List bytes;
  final int? width;
  final int? height;

  /// Always JPEG — the preparer re-encodes every image regardless of
  /// source format. The SDK call site can hardcode the MIME without
  /// branching.
  String get mimeType => 'image/jpeg';
}

/// Reason an [AttachmentRef] was not promoted to inline image bytes.
/// Surfaced in [PreparedAttachment.softFailReason] so the prompt
/// builder can decide whether to mention it (today: it doesn't —
/// non-image attachments are listed name-only without distinguishing
/// "you didn't attach this as image" from "we tried and couldn't
/// read it"; PRD §Q7 leaves that wording detail open).
enum AttachmentDegradeReason {
  /// File extension does not match a supported image type.
  notAnImage,

  /// Per-call image cap [kMaxImagesPerCall] was already hit.
  perCallImageCap,

  /// File path was null or the file did not exist on disk.
  fileNotFound,

  /// File existed but could not be read (permissions, IO error).
  readError,

  /// Bytes loaded but the image package could not decode them.
  decodeError,
}

/// Name-only attachment entry. Either a non-image, an overflow image
/// past the per-call cap, or an image whose bytes couldn't be
/// resolved.
class PreparedAttachment {
  const PreparedAttachment({
    required this.name,
    required this.softFailReason,
  });

  final String name;
  final AttachmentDegradeReason softFailReason;
}

/// Result of a single preparation pass: the bounded image set and
/// the name-only entries.
class PreparedAttachments {
  const PreparedAttachments({
    required this.images,
    required this.nameOnly,
  });

  /// Inline image attachments, ordered by input order, capped at
  /// [kMaxImagesPerCall].
  final List<PreparedImageAttachment> images;

  /// Everything else — non-images, cap overflow, soft-failed images.
  /// Ordered by input order so the prompt reads consistently.
  final List<PreparedAttachment> nameOnly;
}

/// Strategy for reading bytes off an [AttachmentRef]. Defaults to
/// [_diskFileReader] which uses `dart:io` directly. Tests override
/// with an in-memory map so they don't have to touch the filesystem
/// or stub `dart:io`.
typedef AttachmentBytesReader = Future<Uint8List?> Function(String path);

Future<Uint8List?> _diskFileReader(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

const Set<String> _kImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.heic',
};

bool _hasImageExtension(String name) {
  final lower = name.toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot >= 0 ? lower.substring(dot) : '';
  return _kImageExtensions.contains(ext);
}

/// Encodes [decoded] as JPEG-[kImageJpegQuality] after downscaling
/// to fit within an [kImageMaxDimension] bounding box if necessary.
/// Returns null if the source image was empty.
Uint8List? _downscaleAndEncode(img.Image decoded) {
  if (decoded.width == 0 || decoded.height == 0) return null;

  img.Image working = decoded;
  if (working.width > kImageMaxDimension ||
      working.height > kImageMaxDimension) {
    if (working.width >= working.height) {
      working = img.copyResize(
        working,
        width: kImageMaxDimension,
      );
    } else {
      working = img.copyResize(
        working,
        height: kImageMaxDimension,
      );
    }
  }

  final encoded = img.encodeJpg(working, quality: kImageJpegQuality);
  return Uint8List.fromList(encoded);
}

/// Pure-async preparation pipeline. Reads attachment bytes via
/// [reader] (defaults to disk), decodes images, downscales, and
/// re-encodes; returns the bounded image set + name-only entries.
///
/// Per PRD §Q7 individual image failures are soft-fails: the run
/// continues with that one image bumped to name-only. The adapter
/// in #080 owns the "all-images-failed AND no useful text" hard
/// fail; this preparer always returns a result.
Future<PreparedAttachments> prepareAttachments(
  List<AttachmentRef> attachments, {
  AttachmentBytesReader reader = _diskFileReader,
  int maxImages = kMaxImagesPerCall,
}) async {
  final images = <PreparedImageAttachment>[];
  final nameOnly = <PreparedAttachment>[];

  for (final ref in attachments) {
    if (!_hasImageExtension(ref.name)) {
      nameOnly.add(PreparedAttachment(
        name: ref.name,
        softFailReason: AttachmentDegradeReason.notAnImage,
      ));
      continue;
    }

    final path = ref.path;
    if (path == null || path.isEmpty) {
      nameOnly.add(PreparedAttachment(
        name: ref.name,
        softFailReason: AttachmentDegradeReason.fileNotFound,
      ));
      continue;
    }

    Uint8List? bytes;
    try {
      bytes = await reader(path);
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      nameOnly.add(PreparedAttachment(
        name: ref.name,
        softFailReason: AttachmentDegradeReason.fileNotFound,
      ));
      continue;
    }
    if (bytes.isEmpty) {
      nameOnly.add(PreparedAttachment(
        name: ref.name,
        softFailReason: AttachmentDegradeReason.readError,
      ));
      continue;
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      nameOnly.add(PreparedAttachment(
        name: ref.name,
        softFailReason: AttachmentDegradeReason.decodeError,
      ));
      continue;
    }

    // Bake EXIF orientation BEFORE resize. Phone-camera JPEGs ship
    // with an orientation tag rather than physically-rotated pixels;
    // without baking, a portrait iPhone photo lands sideways at
    // Gemini and any spatial reasoning the model attempts ("the
    // person on the left") goes wrong. `bakeOrientation` is a
    // no-op when no orientation tag is present.
    decoded = img.bakeOrientation(decoded);

    final encoded = _downscaleAndEncode(decoded);
    if (encoded == null) {
      nameOnly.add(PreparedAttachment(
        name: ref.name,
        softFailReason: AttachmentDegradeReason.decodeError,
      ));
      continue;
    }

    // Cap check fires *after* successful preparation so soft-failed
    // images never consume a cap slot. The trade is one extra
    // decode+encode per overflow image; realistic attachment lists
    // are small enough that the cost is irrelevant.
    if (images.length >= maxImages) {
      nameOnly.add(PreparedAttachment(
        name: ref.name,
        softFailReason: AttachmentDegradeReason.perCallImageCap,
      ));
      continue;
    }

    final resizedWidth = decoded.width > kImageMaxDimension ||
            decoded.height > kImageMaxDimension
        ? (decoded.width >= decoded.height
            ? kImageMaxDimension
            : (decoded.width * kImageMaxDimension / decoded.height).round())
        : decoded.width;
    final resizedHeight = decoded.width > kImageMaxDimension ||
            decoded.height > kImageMaxDimension
        ? (decoded.width >= decoded.height
            ? (decoded.height * kImageMaxDimension / decoded.width).round()
            : kImageMaxDimension)
        : decoded.height;

    images.add(PreparedImageAttachment(
      name: ref.name,
      bytes: encoded,
      width: resizedWidth,
      height: resizedHeight,
    ));
  }

  return PreparedAttachments(images: images, nameOnly: nameOnly);
}
