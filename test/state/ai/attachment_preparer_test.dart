import 'dart:io';
import 'dart:typed_data';

import 'package:connect_me/src/ai/attachment_preparer.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Builds a JPEG image of [width]x[height] with a deterministic
/// gradient so tests can assert decode + downscale behavior without
/// snapshotting raw bytes.
Uint8List _buildJpegBytes({
  required int width,
  required int height,
  int quality = 90,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 255 / width).round(),
        (y * 255 / height).round(),
        128,
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

Uint8List _buildPngBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, 200, 100, 50);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// Test reader factory: maps fake paths to canned bytes (or null
/// to simulate a missing file). Throws when [throwingPaths]
/// includes the requested path so the read-error branch is
/// exercised.
AttachmentBytesReader _readerFor(
  Map<String, Uint8List?> bytesByPath, {
  Set<String> throwingPaths = const {},
}) {
  return (String path) async {
    if (throwingPaths.contains(path)) {
      throw const FileSystemException('boom');
    }
    return bytesByPath[path];
  };
}

void main() {
  group('extension classification', () {
    test('treats jpg/jpeg/png/webp/heic as image extensions', () async {
      final result = await prepareAttachments(
        [
          const AttachmentRef(name: 'a.jpg', path: '/tmp/a.jpg'),
          const AttachmentRef(name: 'b.jpeg', path: '/tmp/b.jpeg'),
          const AttachmentRef(name: 'c.PNG', path: '/tmp/c.png'),
          const AttachmentRef(name: 'd.WebP', path: '/tmp/d.webp'),
          const AttachmentRef(name: 'e.heic', path: '/tmp/e.heic'),
        ],
        // Reader returns null for everything → all soft-fail to
        // fileNotFound, but classification logic runs first.
        reader: _readerFor(const {}),
      );
      // None promoted to images (bytes missing), but every entry
      // landed in nameOnly with fileNotFound, NOT notAnImage —
      // confirms each was classified as an image.
      expect(result.images, isEmpty);
      expect(result.nameOnly, hasLength(5));
      for (final entry in result.nameOnly) {
        expect(entry.softFailReason, AttachmentDegradeReason.fileNotFound);
      }
    });

    test('treats pdf, m4a, txt, and extension-less as non-image', () async {
      final result = await prepareAttachments([
        const AttachmentRef(name: 'doc.pdf', path: '/tmp/d.pdf'),
        const AttachmentRef(name: 'audio.m4a', path: '/tmp/a.m4a'),
        const AttachmentRef(name: 'note.txt', path: '/tmp/n.txt'),
        const AttachmentRef(name: 'README', path: '/tmp/r'),
      ], reader: _readerFor(const {}));
      expect(result.images, isEmpty);
      expect(result.nameOnly, hasLength(4));
      for (final entry in result.nameOnly) {
        expect(entry.softFailReason, AttachmentDegradeReason.notAnImage);
      }
    });
  });

  group('happy path — decode + downscale + JPEG re-encode', () {
    test('reads, decodes, and produces JPEG bytes', () async {
      final src = _buildJpegBytes(width: 600, height: 400);
      final result = await prepareAttachments([
        const AttachmentRef(name: 'photo.jpg', path: '/tmp/photo.jpg'),
      ], reader: _readerFor({'/tmp/photo.jpg': src}));
      expect(result.images, hasLength(1));
      final prepared = result.images.single;
      expect(prepared.name, 'photo.jpg');
      expect(prepared.mimeType, 'image/jpeg');
      expect(prepared.bytes.isNotEmpty, isTrue);

      // Verify the output is a real JPEG by round-tripping it.
      final roundTripped = img.decodeJpg(prepared.bytes);
      expect(roundTripped, isNotNull);
    });

    test('PNG input is re-encoded to JPEG', () async {
      final src = _buildPngBytes(width: 200, height: 200);
      final result = await prepareAttachments([
        const AttachmentRef(name: 'flat.png', path: '/tmp/flat.png'),
      ], reader: _readerFor({'/tmp/flat.png': src}));
      expect(result.images, hasLength(1));
      // Output must decode as JPEG, not PNG.
      expect(img.decodeJpg(result.images.single.bytes), isNotNull);
    });

    test('does not upscale small images', () async {
      final src = _buildJpegBytes(width: 320, height: 240);
      final result = await prepareAttachments([
        const AttachmentRef(name: 'tiny.jpg', path: '/tmp/tiny.jpg'),
      ], reader: _readerFor({'/tmp/tiny.jpg': src}));
      final prepared = result.images.single;
      expect(prepared.width, 320);
      expect(prepared.height, 240);
    });

    test('downscales landscape image to fit 1024 on long edge', () async {
      final src = _buildJpegBytes(width: 4000, height: 3000);
      final result = await prepareAttachments([
        const AttachmentRef(name: 'wide.jpg', path: '/tmp/wide.jpg'),
      ], reader: _readerFor({'/tmp/wide.jpg': src}));
      final prepared = result.images.single;
      expect(prepared.width, kImageMaxDimension); // 1024
      expect(prepared.height, lessThanOrEqualTo(kImageMaxDimension));
      // Aspect-preserving: 4000:3000 = 4:3, so 1024x768 expected.
      expect(prepared.height, 768);
    });

    test('downscales portrait image to fit 1024 on long edge', () async {
      final src = _buildJpegBytes(width: 1500, height: 3000);
      final result = await prepareAttachments([
        const AttachmentRef(name: 'tall.jpg', path: '/tmp/tall.jpg'),
      ], reader: _readerFor({'/tmp/tall.jpg': src}));
      final prepared = result.images.single;
      expect(prepared.height, kImageMaxDimension);
      expect(prepared.width, lessThanOrEqualTo(kImageMaxDimension));
      expect(prepared.width, 512); // 1500:3000 = 1:2
    });

    test(
      'JPEG re-encode produces meaningfully smaller bytes for big images',
      () async {
        final huge = _buildJpegBytes(width: 4000, height: 3000, quality: 95);
        final result = await prepareAttachments([
          const AttachmentRef(name: 'huge.jpg', path: '/tmp/huge.jpg'),
        ], reader: _readerFor({'/tmp/huge.jpg': huge}));
        // Downscaled+re-encoded payload should be far smaller than the
        // raw 4000x3000 source. Loose bound — exact ratios depend on
        // gradient compressibility.
        expect(result.images.single.bytes.length, lessThan(huge.length));
      },
    );
  });

  group('per-call image cap', () {
    test('caps images at kMaxImagesPerCall and degrades overflow', () async {
      final src = _buildJpegBytes(width: 100, height: 100);
      final attachments = <AttachmentRef>[
        for (var i = 0; i < kMaxImagesPerCall + 2; i++)
          AttachmentRef(name: 'img$i.jpg', path: '/tmp/img$i.jpg'),
      ];
      final reader = _readerFor({
        for (var i = 0; i < kMaxImagesPerCall + 2; i++) '/tmp/img$i.jpg': src,
      });
      final result = await prepareAttachments(attachments, reader: reader);
      expect(result.images, hasLength(kMaxImagesPerCall));
      expect(result.nameOnly, hasLength(2));
      for (final overflow in result.nameOnly) {
        expect(
          overflow.softFailReason,
          AttachmentDegradeReason.perCallImageCap,
        );
      }
    });

    test('respects custom maxImages override', () async {
      final src = _buildJpegBytes(width: 100, height: 100);
      final result = await prepareAttachments(
        [
          const AttachmentRef(name: 'a.jpg', path: '/tmp/a.jpg'),
          const AttachmentRef(name: 'b.jpg', path: '/tmp/b.jpg'),
        ],
        reader: _readerFor({'/tmp/a.jpg': src, '/tmp/b.jpg': src}),
        maxImages: 1,
      );
      expect(result.images, hasLength(1));
      expect(result.nameOnly, hasLength(1));
      expect(
        result.nameOnly.single.softFailReason,
        AttachmentDegradeReason.perCallImageCap,
      );
    });

    test(
      'cap counts only successfully-prepared images, not soft-failed ones',
      () async {
        // Three image refs: one decode-fails, two succeed. With
        // maxImages=2, the two successes should both make it through;
        // the decode-fail counts as nameOnly (decodeError), not
        // toward the cap.
        final src = _buildJpegBytes(width: 100, height: 100);
        final result = await prepareAttachments(
          [
            const AttachmentRef(name: 'broken.jpg', path: '/tmp/broken.jpg'),
            const AttachmentRef(name: 'a.jpg', path: '/tmp/a.jpg'),
            const AttachmentRef(name: 'b.jpg', path: '/tmp/b.jpg'),
          ],
          reader: _readerFor({
            '/tmp/broken.jpg': Uint8List.fromList([
              0x00,
              0x01,
              0x02,
              0x03,
              0x04,
            ]),
            '/tmp/a.jpg': src,
            '/tmp/b.jpg': src,
          }),
          maxImages: 2,
        );
        expect(result.images, hasLength(2));
        expect(
          result.images.map((i) => i.name),
          containsAll(['a.jpg', 'b.jpg']),
        );
        expect(
          result.nameOnly.single.softFailReason,
          AttachmentDegradeReason.decodeError,
        );
      },
    );
  });

  group('hard-fail policy', () {
    const hardFailMessage =
        "Attachments couldn't be read. Try again, or continue without them.";

    test(
      'returns message when image-like refs all fail and input is blank',
      () {
        final message = attachmentHardFailureFor(
          userInput: '   ',
          attachments: const [AttachmentRef(name: 'photo.jpg', path: null)],
          prepared: const PreparedAttachments(
            images: [],
            nameOnly: [
              PreparedAttachment(
                name: 'photo.jpg',
                softFailReason: AttachmentDegradeReason.fileNotFound,
              ),
            ],
          ),
        );

        expect(message, hardFailMessage);
      },
    );

    test('does not hard-fail non-image-only attachments', () {
      final message = attachmentHardFailureFor(
        userInput: '',
        attachments: const [AttachmentRef(name: 'notes.pdf', path: null)],
        prepared: const PreparedAttachments(
          images: [],
          nameOnly: [
            PreparedAttachment(
              name: 'notes.pdf',
              softFailReason: AttachmentDegradeReason.notAnImage,
            ),
          ],
        ),
      );

      expect(message, isNull);
    });

    test('does not hard-fail image failures when useful text exists', () {
      final message = attachmentHardFailureFor(
        userInput: 'Remember this photo from lunch.',
        attachments: const [AttachmentRef(name: 'photo.png', path: null)],
        prepared: const PreparedAttachments(
          images: [],
          nameOnly: [
            PreparedAttachment(
              name: 'photo.png',
              softFailReason: AttachmentDegradeReason.fileNotFound,
            ),
          ],
        ),
      );

      expect(message, isNull);
    });

    test('does not hard-fail when a prepared image is available', () {
      final message = attachmentHardFailureFor(
        userInput: '',
        attachments: const [AttachmentRef(name: 'photo.webp', path: '/p')],
        prepared: PreparedAttachments(
          images: [
            PreparedImageAttachment(
              name: 'photo.webp',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
          nameOnly: const [],
        ),
      );

      expect(message, isNull);
    });
  });

  group('soft-fail branches', () {
    test('null path → fileNotFound nameOnly', () async {
      final result = await prepareAttachments([
        const AttachmentRef(name: 'orphan.jpg', path: null),
      ], reader: _readerFor(const {}));
      expect(result.images, isEmpty);
      expect(
        result.nameOnly.single.softFailReason,
        AttachmentDegradeReason.fileNotFound,
      );
    });

    test('empty path → fileNotFound nameOnly', () async {
      final result = await prepareAttachments([
        const AttachmentRef(name: 'empty.jpg', path: ''),
      ], reader: _readerFor(const {}));
      expect(
        result.nameOnly.single.softFailReason,
        AttachmentDegradeReason.fileNotFound,
      );
    });

    test('reader returns null → fileNotFound nameOnly', () async {
      final result = await prepareAttachments([
        const AttachmentRef(name: 'gone.jpg', path: '/tmp/gone.jpg'),
      ], reader: _readerFor({'/tmp/gone.jpg': null}));
      expect(
        result.nameOnly.single.softFailReason,
        AttachmentDegradeReason.fileNotFound,
      );
    });

    test('reader throws → fileNotFound nameOnly', () async {
      final result = await prepareAttachments([
        const AttachmentRef(name: 'locked.jpg', path: '/tmp/locked.jpg'),
      ], reader: _readerFor(const {}, throwingPaths: {'/tmp/locked.jpg'}));
      expect(
        result.nameOnly.single.softFailReason,
        AttachmentDegradeReason.fileNotFound,
      );
    });

    test('empty bytes → readError nameOnly', () async {
      final result = await prepareAttachments([
        const AttachmentRef(name: 'zero.jpg', path: '/tmp/zero.jpg'),
      ], reader: _readerFor({'/tmp/zero.jpg': Uint8List(0)}));
      expect(
        result.nameOnly.single.softFailReason,
        AttachmentDegradeReason.readError,
      );
    });

    test('garbage bytes → decodeError nameOnly', () async {
      final result = await prepareAttachments(
        [const AttachmentRef(name: 'garbage.jpg', path: '/tmp/g.jpg')],
        reader: _readerFor({
          '/tmp/g.jpg': Uint8List.fromList([
            0xDE,
            0xAD,
            0xBE,
            0xEF,
            0xCA,
            0xFE,
          ]),
        }),
      );
      expect(
        result.nameOnly.single.softFailReason,
        AttachmentDegradeReason.decodeError,
      );
    });

    test('one bad image does not block neighbors', () async {
      final src = _buildJpegBytes(width: 200, height: 200);
      final result = await prepareAttachments(
        [
          const AttachmentRef(name: 'good.jpg', path: '/tmp/good.jpg'),
          const AttachmentRef(name: 'bad.jpg', path: '/tmp/bad.jpg'),
          const AttachmentRef(name: 'good2.jpg', path: '/tmp/good2.jpg'),
        ],
        reader: _readerFor({
          '/tmp/good.jpg': src,
          '/tmp/bad.jpg': Uint8List.fromList([0x00]),
          '/tmp/good2.jpg': src,
        }),
      );
      expect(
        result.images.map((i) => i.name),
        containsAll(['good.jpg', 'good2.jpg']),
      );
      expect(result.nameOnly.single.name, 'bad.jpg');
      expect(
        result.nameOnly.single.softFailReason,
        AttachmentDegradeReason.decodeError,
      );
    });
  });

  group('mixed input', () {
    test('image + non-image + cap overflow + soft-fail in one batch', () async {
      final src = _buildJpegBytes(width: 100, height: 100);
      final attachments = <AttachmentRef>[
        const AttachmentRef(name: 'a.jpg', path: '/tmp/a.jpg'),
        const AttachmentRef(name: 'b.jpg', path: '/tmp/b.jpg'),
        const AttachmentRef(name: 'doc.pdf', path: '/tmp/doc.pdf'),
        const AttachmentRef(name: 'c.jpg', path: '/tmp/c.jpg'),
        const AttachmentRef(name: 'd.jpg', path: '/tmp/d.jpg'),
        const AttachmentRef(name: 'overflow.jpg', path: '/tmp/o.jpg'),
        const AttachmentRef(name: 'broken.jpg', path: '/tmp/broken.jpg'),
      ];
      final reader = _readerFor({
        '/tmp/a.jpg': src,
        '/tmp/b.jpg': src,
        '/tmp/c.jpg': src,
        '/tmp/d.jpg': src,
        '/tmp/o.jpg': src,
        '/tmp/broken.jpg': Uint8List.fromList([0x00]),
      });
      final result = await prepareAttachments(attachments, reader: reader);

      // Cap is 4: a, b, c, d make it; overflow.jpg degrades to
      // perCallImageCap. doc.pdf is notAnImage. broken.jpg
      // degrades to decodeError.
      expect(result.images, hasLength(4));
      expect(result.images.map((i) => i.name), [
        'a.jpg',
        'b.jpg',
        'c.jpg',
        'd.jpg',
      ]);

      final reasonsByName = {
        for (final e in result.nameOnly) e.name: e.softFailReason,
      };
      expect(reasonsByName, {
        'doc.pdf': AttachmentDegradeReason.notAnImage,
        'overflow.jpg': AttachmentDegradeReason.perCallImageCap,
        'broken.jpg': AttachmentDegradeReason.decodeError,
      });
    });

    test('empty input list → empty result', () async {
      final result = await prepareAttachments(const []);
      expect(result.images, isEmpty);
      expect(result.nameOnly, isEmpty);
    });
  });
}
