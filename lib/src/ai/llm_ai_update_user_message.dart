/// Pure function that builds the per-call user message for the
/// [LlmAiUpdate] adapter (Pass 4.3, PRD §Q5).
///
/// Sent to Gemini after the [kLlmAiUpdatePromptV1] system prompt.
/// Contains everything the model needs to produce a structured
/// memory update for one contact: today's date, contact metadata,
/// the current MemoryDocument, the most recent interactions, the
/// user's text input, and attachment information.
///
/// This file deliberately holds no SDK dependency. It returns a
/// `String` (the assembled prompt body). The adapter in #080 will
/// concatenate this with image parts at the multipart-request layer
/// — that's where Firebase AI Logic enters; here, it does not.
///
/// The order and section labels below are part of the prompt
/// contract: changing them is equivalent to bumping the prompt
/// version, because Gemini's behavior depends on layout. If a layout
/// change is needed, bump [kLlmAiUpdatePromptVersion] in
/// `llm_ai_update_prompt.dart` so persisted results remain traceable.
library;

import '../models/social_models.dart';
import '../state/memory/memory_document.dart';
import 'attachment_preparer.dart';

/// How many recent interactions are sent to the model alongside the
/// MemoryDocument. PRD §Q5 chose 5 — enough for tonal continuity,
/// cheap on tokens. Tunable here if dogfooding shows we want more
/// or less context.
const int kRecentInteractionsLimit = 5;

/// Bond-tier copy fed to the model so it can tonally calibrate
/// without interpreting raw 0..100 scores. Matches [BondTier.from]
/// in `lib/src/widgets/bond_ring.dart` exactly: ≥80 close, 50-79
/// steady, <50 drifting. Keeping the AI's mental model aligned with
/// the visual tier the user sees prevents subtle voice mismatches
/// (the LLM treating "medium" while the ring shows "close").
String _bondTierLabel(int bondScore) {
  if (bondScore >= 80) return 'close — regular touch, the relationship is healthy';
  if (bondScore >= 50) return 'steady — stable, periodic touch';
  return 'drifting — contact has thinned, gentle re-entry helps';
}

/// Splits a list of [AttachmentRef] into image-typed and non-image
/// references by file extension. Pass 4.3 sends image bytes for the
/// image set (subject to the per-call cap and resize pipeline in
/// #079) and name-only for the rest. The cap is enforced inside the
/// adapter; this builder only labels the surface for the prompt.
class _AttachmentSplit {
  const _AttachmentSplit(this.images, this.nonImages);
  final List<AttachmentRef> images;
  final List<AttachmentRef> nonImages;
}

const Set<String> _kImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.heic',
};

_AttachmentSplit _splitAttachments(List<AttachmentRef> attachments) {
  final images = <AttachmentRef>[];
  final nonImages = <AttachmentRef>[];
  for (final a in attachments) {
    final lower = a.name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot >= 0 ? lower.substring(dot) : '';
    if (_kImageExtensions.contains(ext)) {
      images.add(a);
    } else {
      nonImages.add(a);
    }
  }
  return _AttachmentSplit(images, nonImages);
}

String _isoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String _interactionLine(CrmInteraction i) {
  final date = _isoDate(i.date.toUtc());
  final title = i.title.isEmpty ? '(no title)' : i.title;
  return '- $date — ${i.type.name} — "$title"';
}

/// Human-readable label for a name-only attachment entry. Used in
/// the prompt's attachments section so the model knows whether the
/// entry is a non-image, an image past the per-call cap, or an
/// image whose bytes couldn't be resolved.
String _nameOnlyLabel(AttachmentDegradeReason reason) {
  switch (reason) {
    case AttachmentDegradeReason.notAnImage:
      return 'non-image, name only';
    case AttachmentDegradeReason.perCallImageCap:
      return 'image, name only — over per-call image cap';
    case AttachmentDegradeReason.fileNotFound:
      return 'image, name only — file unavailable';
    case AttachmentDegradeReason.readError:
      return 'image, name only — file empty';
    case AttachmentDegradeReason.decodeError:
      return 'image, name only — could not decode';
  }
}

/// Pure function: returns the per-call user message for one AI
/// Update run.
///
/// PRD §Q5 layout (order is part of the contract):
/// 1. Today's date.
/// 2. Contact metadata (name, category, bond score + tier copy,
///    current next-step suggestion).
/// 3. Existing MemoryDocument markdown (full; the 64KB cap from
///    Pass 3 §Q5 is the natural ceiling).
/// 4. Recent interactions, most recent first, capped at
///    [kRecentInteractionsLimit].
/// 5. Attachments: image set (names only here; bytes are added by
///    the adapter at the multipart layer) and non-image set
///    (always names only).
/// 6. User input.
///
/// When [prepared] is provided (the Pass 4.3 #079 attachment
/// preparer's output), the attachment section reflects what
/// actually made it into the multipart request: images that
/// successfully decoded land as "image, included" and everything
/// else as "name only" with the preparer's degrade reason. This
/// keeps the prompt text from claiming "image included" for an
/// image whose bytes never reached Gemini (PRD §Q7 + reviewer
/// blocker on #080).
///
/// When [prepared] is null, the builder falls back to a pure
/// extension-based classification on [attachments] for callers
/// that don't run images through the preparer (notably the #082
/// integration tests at the schema level).
String buildLlmAiUpdateUserMessage({
  required DateTime today,
  required Connection contact,
  required MemoryDocument memory,
  required List<CrmInteraction> recentInteractions,
  required List<AttachmentRef> attachments,
  required String userInput,
  PreparedAttachments? prepared,
}) {
  final buffer = StringBuffer();

  buffer.writeln("Today's date: ${_isoDate(today.toUtc())}");
  buffer.writeln();

  buffer.writeln('Contact:');
  buffer.writeln('- Name: ${contact.name}');
  buffer.writeln('- Category: ${contact.category}');
  buffer.writeln(
    '- Bond score: ${contact.bondScore} '
    '(${_bondTierLabel(contact.bondScore)})',
  );
  buffer.writeln(
    '- Current next-step suggestion: '
    '${contact.nextStep.isEmpty ? 'none' : '"${contact.nextStep}"'}',
  );
  buffer.writeln();

  buffer.writeln('Existing memory document:');
  buffer.writeln(memory.render().trim());
  buffer.writeln();

  // Most-recent first; hard-cap per PRD §Q5.
  final sorted = [...recentInteractions]
    ..sort((a, b) => b.date.compareTo(a.date));
  final capped = sorted.take(kRecentInteractionsLimit).toList(growable: false);
  if (capped.isEmpty) {
    buffer.writeln('Recent interactions: none yet.');
  } else {
    buffer.writeln(
      'Recent interactions (most recent first, up to '
      '$kRecentInteractionsLimit):',
    );
    for (final i in capped) {
      buffer.writeln(_interactionLine(i));
    }
  }
  buffer.writeln();

  if (prepared != null) {
    if (prepared.images.isEmpty && prepared.nameOnly.isEmpty) {
      buffer.writeln('Attachments: none.');
    } else {
      buffer.writeln('Attachments:');
      for (final img in prepared.images) {
        buffer.writeln('- ${img.name} (image, included)');
      }
      for (final entry in prepared.nameOnly) {
        buffer.writeln(
          '- ${entry.name} (${_nameOnlyLabel(entry.softFailReason)})',
        );
      }
    }
  } else {
    final split = _splitAttachments(attachments);
    if (split.images.isEmpty && split.nonImages.isEmpty) {
      buffer.writeln('Attachments: none.');
    } else {
      buffer.writeln('Attachments:');
      for (final img in split.images) {
        buffer.writeln('- ${img.name} (image, included)');
      }
      for (final other in split.nonImages) {
        buffer.writeln('- ${other.name} (non-image, name only)');
      }
    }
  }
  buffer.writeln();

  buffer.writeln('User input:');
  buffer.writeln(userInput.isEmpty ? '(empty)' : userInput);

  return buffer.toString();
}
