import 'package:connect_me/src/ai/attachment_preparer.dart';
import 'package:connect_me/src/ai/llm_ai_update_user_message.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

Connection _connection({
  String id = 'sarah',
  String name = 'Sarah Johnson',
  String category = 'Friends',
  int bondScore = 73,
  String nextStep = 'Send the article she mentioned',
}) {
  return Connection(
    id: id,
    name: name,
    email: '$id@example.com',
    category: category,
    avatar: '👱‍♀️',
    bondScore: bondScore,
    nextStep: nextStep,
    lastContact: DateTime.utc(2026, 5, 1),
    notes: '',
    knownSince: DateTime.utc(2020, 6, 1),
    preferredChannels: const ['Text'],
  );
}

MemoryDocument _emptyMemory({String id = 'sarah', String name = 'Sarah'}) =>
    MemoryDocument.empty(
      contactId: id,
      displayName: name,
      now: DateTime.utc(2026, 5, 19),
    );

CrmInteraction _interaction({
  required String id,
  required DateTime date,
  String title = 'Coffee',
  InteractionType type = InteractionType.sharedActivity,
  String contactId = 'sarah',
}) {
  return CrmInteraction(
    id: id,
    contactId: contactId,
    type: type,
    title: title,
    note: 'note',
    date: date,
  );
}

void main() {
  group('buildLlmAiUpdateUserMessage — top-level layout', () {
    test('emits sections in the PRD §Q5 order', () {
      final today = DateTime.utc(2026, 5, 27);
      final out = buildLlmAiUpdateUserMessage(
        today: today,
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: 'short note',
      );

      // The order is part of the prompt contract: today's date first,
      // contact, memory document, interactions, attachments, user
      // input. Use index ordering rather than line-by-line literals so
      // the assertion survives small wording tweaks.
      final iDate = out.indexOf("Today's date");
      final iContact = out.indexOf('Contact:');
      final iMemory = out.indexOf('Existing memory document:');
      final iInteractions = out.indexOf('Recent interactions');
      final iAttachments = out.indexOf('Attachments');
      final iInput = out.indexOf('User input:');

      expect(iDate, greaterThanOrEqualTo(0));
      expect(iContact, greaterThan(iDate));
      expect(iMemory, greaterThan(iContact));
      expect(iInteractions, greaterThan(iMemory));
      expect(iAttachments, greaterThan(iInteractions));
      expect(iInput, greaterThan(iAttachments));
    });

    test("formats today's date as ISO YYYY-MM-DD", () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains("Today's date: 2026-05-27"));
    });
  });

  group('contact section', () {
    test('renders all contact fields the model needs', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(
          name: 'Sarah Johnson',
          category: 'Friends',
          bondScore: 73,
          nextStep: 'Send the article she mentioned',
        ),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('- Name: Sarah Johnson'));
      expect(out, contains('- Category: Friends'));
      expect(out, contains('- Bond score: 73'));
      expect(out,
          contains('- Current next-step suggestion: "Send the article'));
    });

    test('emits "none" for empty next step', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(nextStep: ''),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('- Current next-step suggestion: none'));
    });

    test('describes high bond tier with calibration copy', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(bondScore: 92),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('close'));
      expect(out, contains('regular touch'));
    });

    test('describes medium bond tier', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(bondScore: 65),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('steady'));
      expect(out, contains('stable, periodic touch'));
    });

    test('describes low bond tier', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(bondScore: 30),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('drifting'));
      expect(out, contains('contact has thinned'));
    });

    test('uses BondRing thresholds (50/80) at the boundaries', () {
      // Cross-check: the prompt builder must agree with
      // BondTier.from in lib/src/widgets/bond_ring.dart so the
      // model's tonal calibration matches what the user sees on
      // the ring. 49 is drifting; 50 is steady; 79 is steady; 80
      // is close.
      final at49 = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(bondScore: 49),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(at49, contains('drifting'));

      final at50 = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(bondScore: 50),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(at50, contains('steady'));

      final at79 = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(bondScore: 79),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(at79, contains('steady'));

      final at80 = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(bondScore: 80),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(at80, contains('close'));
    });
  });

  group('memory document section', () {
    test('embeds the rendered memory markdown', () {
      final memory = MemoryDocument(
        contactId: 'sarah',
        displayName: 'Sarah Johnson',
        lastUpdated: DateTime.utc(2026, 5, 19),
        summary: 'Friends since 2020. Coffee regular.',
      );
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: memory,
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('Existing memory document:'));
      expect(out, contains('Friends since 2020. Coffee regular.'));
    });
  });

  group('recent interactions section', () {
    test('emits "none yet" when no interactions are passed', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('Recent interactions: none yet.'));
    });

    test('lists interactions most-recent first', () {
      final older = _interaction(
        id: 'a',
        date: DateTime.utc(2026, 4, 1),
        title: 'Older',
      );
      final newer = _interaction(
        id: 'b',
        date: DateTime.utc(2026, 5, 1),
        title: 'Newer',
      );
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: [older, newer],
        attachments: const [],
        userInput: '',
      );
      final iNewer = out.indexOf('"Newer"');
      final iOlder = out.indexOf('"Older"');
      expect(iNewer, greaterThan(0));
      expect(iOlder, greaterThan(iNewer));
    });

    test('caps at $kRecentInteractionsLimit even if more are passed', () {
      // Build 8 interactions on consecutive days; only the last 5 (by
      // date desc) should appear in the prompt.
      final all = <CrmInteraction>[];
      for (var i = 0; i < 8; i++) {
        all.add(
          _interaction(
            id: 'i$i',
            date: DateTime.utc(2026, 5, 1 + i),
            title: 'I$i',
          ),
        );
      }
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: all,
        attachments: const [],
        userInput: '',
      );
      // Most recent 5 (i3..i7) appear; older 3 (i0..i2) do not.
      for (final keep in const ['I3', 'I4', 'I5', 'I6', 'I7']) {
        expect(out, contains('"$keep"'),
            reason: '$keep should be present in the recent set');
      }
      for (final drop in const ['I0', 'I1', 'I2']) {
        expect(out, isNot(contains('"$drop"')),
            reason: '$drop should be excluded by the recent-cap');
      }
    });

    test('formats each interaction line with date, type, and title', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: [
          _interaction(
            id: 'a',
            date: DateTime.utc(2026, 5, 1),
            type: InteractionType.preference,
            title: 'Prefers oat milk lattes',
          ),
        ],
        attachments: const [],
        userInput: '',
      );
      expect(
        out,
        contains('- 2026-05-01 — preference — "Prefers oat milk lattes"'),
      );
    });
  });

  group('attachments section', () {
    test('emits "none" when no attachments', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('Attachments: none.'));
    });

    test('separates image and non-image attachments', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [
          AttachmentRef(name: 'garden_photo.jpg', path: '/tmp/g.jpg'),
          AttachmentRef(name: 'sarah_resume.pdf', path: '/tmp/r.pdf'),
          AttachmentRef(name: 'screenshot.PNG', path: '/tmp/s.png'),
        ],
        userInput: '',
      );
      expect(out, contains('- garden_photo.jpg (image, included)'));
      expect(out, contains('- screenshot.PNG (image, included)'));
      expect(out, contains('- sarah_resume.pdf (non-image, name only)'));
    });

    test('treats heic and webp as images', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [
          AttachmentRef(name: 'live.heic', path: '/tmp/l.heic'),
          AttachmentRef(name: 'sticker.webp', path: '/tmp/s.webp'),
        ],
        userInput: '',
      );
      expect(out, contains('- live.heic (image, included)'));
      expect(out, contains('- sticker.webp (image, included)'));
    });

    test('treats unknown extension as non-image', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [
          AttachmentRef(name: 'audio.m4a', path: '/tmp/a.m4a'),
        ],
        userInput: '',
      );
      expect(out, contains('- audio.m4a (non-image, name only)'));
    });
  });

  group('user input section', () {
    test('renders provided text under the User input header', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: "Sarah's daughter starts kindergarten in September.",
      );
      expect(out, contains('User input:'));
      expect(out, contains('kindergarten in September'));
    });

    test('emits "(empty)" when user input is empty', () {
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
      );
      expect(out, contains('User input:\n(empty)'));
    });
  });

  group('prepared-attachments override (Pass 4.3 #080 BLOCKER 4)', () {
    test('uses prepared.images and prepared.nameOnly when provided', () {
      // Reviewer BLOCKER 4: when the adapter has run images through
      // the #079 preparer, the prompt's attachments section must
      // reflect what's actually in the multipart payload. Image
      // refs that soft-failed land in nameOnly with a degrade
      // reason that informs the model.
      final prepared = PreparedAttachments(
        images: [
          PreparedImageAttachment(
            name: 'good.jpg',
            bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
            width: 800,
            height: 600,
          ),
        ],
        nameOnly: const [
          PreparedAttachment(
            name: 'broken.jpg',
            softFailReason: AttachmentDegradeReason.decodeError,
          ),
          PreparedAttachment(
            name: 'overflow.jpg',
            softFailReason: AttachmentDegradeReason.perCallImageCap,
          ),
          PreparedAttachment(
            name: 'doc.pdf',
            softFailReason: AttachmentDegradeReason.notAnImage,
          ),
        ],
      );

      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [
          AttachmentRef(name: 'good.jpg', path: '/tmp/g.jpg'),
          AttachmentRef(name: 'broken.jpg', path: '/tmp/b.jpg'),
          AttachmentRef(name: 'overflow.jpg', path: '/tmp/o.jpg'),
          AttachmentRef(name: 'doc.pdf', path: '/tmp/d.pdf'),
        ],
        userInput: '',
        prepared: prepared,
      );

      // Image that survived the preparer is labelled "included."
      expect(out, contains('- good.jpg (image, included)'));
      // Soft-failed image gets a clarifying degrade label so the
      // model knows we tried.
      expect(out, contains('- broken.jpg (image, name only — could not decode)'));
      expect(out, contains('- overflow.jpg (image, name only — over per-call image cap)'));
      // Non-image attachment retains its existing label.
      expect(out, contains('- doc.pdf (non-image, name only)'));
    });

    test('emits "Attachments: none." when prepared has no entries', () {
      const prepared = PreparedAttachments(
        images: [],
        nameOnly: [],
      );
      final out = buildLlmAiUpdateUserMessage(
        today: DateTime.utc(2026, 5, 27),
        contact: _connection(),
        memory: _emptyMemory(),
        recentInteractions: const [],
        attachments: const [],
        userInput: '',
        prepared: prepared,
      );
      expect(out, contains('Attachments: none.'));
    });
  });
}
