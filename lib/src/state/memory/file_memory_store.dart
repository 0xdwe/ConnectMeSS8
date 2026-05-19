import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'memory_document.dart';
import 'memory_store.dart';

/// Per-contact byte cap. PRD Q6.
const int _perContactCapBytes = 64 * 1024;

/// Global byte cap across every memory file. PRD Q6.
const int _globalCapBytes = 16 * 1024 * 1024;

/// Thrown by [FileMemoryStore.save] when a write would exceed the
/// per-contact 64KB cap with no `## History` bullets left to drop, or
/// when the global 16MB cap would be breached. The PRD Q4 contract
/// upstream catches this and abandons the in-memory state delta.
class MemoryCapExceededException implements Exception {
  const MemoryCapExceededException(this.message);

  final String message;

  @override
  String toString() => 'MemoryCapExceededException: $message';
}

/// File-backed [MemoryStore] writing one markdown file per contact at
/// `<app_documents>/memories/<contactId>.md`.
///
/// Writes go through a temp file then rename — atomic on POSIX — so a
/// failure between temp-write and rename leaves the previous file
/// intact. This is the on-disk half of the PRD Q4 all-or-nothing
/// contract.
class FileMemoryStore implements MemoryStore {
  /// `directoryOverride`, when supplied, replaces
  /// `getApplicationDocumentsDirectory()` as the parent of the
  /// `memories/` folder. Tests pass a `Directory.systemTemp` child.
  FileMemoryStore({Directory? directoryOverride})
      : _override = directoryOverride;

  final Directory? _override;
  Directory? _resolved;

  Future<Directory> _dir() async {
    final cached = _resolved;
    if (cached != null) return cached;
    final base = _override ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/memories');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _resolved = dir;
    return dir;
  }

  File _fileFor(Directory dir, String contactId) =>
      File('${dir.path}/$contactId.md');

  File _tempFileFor(Directory dir, String contactId) =>
      File('${dir.path}/$contactId.md.tmp');

  @override
  Future<MemoryDocument?> load(String contactId) async {
    final dir = await _dir();
    final file = _fileFor(dir, contactId);
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    return MemoryDocument.parse(raw);
  }

  @override
  Future<void> save(MemoryDocument doc) async {
    final dir = await _dir();

    // Per-contact cap: trim oldest history bullets until the rendered
    // doc fits. Throws MemoryCapExceededException if no history bullets
    // remain and the doc still exceeds the cap.
    final trimmed = trimToCap(doc, capBytes: _perContactCapBytes);
    final rendered = trimmed.render();
    final renderedBytes = utf8.encode(rendered);

    // Global cap: sum of every other file plus this write.
    final all = await _listFiles(dir);
    var totalBytes = 0;
    for (final f in all) {
      if (f.path.endsWith('/${doc.contactId}.md')) {
        // Replacing this file; its old size shouldn't double-count.
        continue;
      }
      try {
        totalBytes += await f.length();
      } catch (_) {
        // Skip transiently inaccessible files; the global cap is a
        // soft check.
      }
    }
    if (totalBytes + renderedBytes.length > _globalCapBytes) {
      throw MemoryCapExceededException(
        'Global memory cap (${_globalCapBytes ~/ (1024 * 1024)}MB) would '
        'be exceeded by saving "${doc.contactId}".',
      );
    }

    final tmp = _tempFileFor(dir, doc.contactId);
    final target = _fileFor(dir, doc.contactId);

    try {
      // Write + flush + close. RandomAccessFile.flush() is the Dart
      // equivalent of fsync on the data we just wrote.
      final raf = await tmp.open(mode: FileMode.writeOnly);
      try {
        await raf.writeFrom(renderedBytes);
        await raf.flush();
      } finally {
        await raf.close();
      }
      // Atomic on POSIX. Replaces the existing target if any.
      await tmp.rename(target.path);
    } catch (e) {
      // Best-effort cleanup of any orphan temp file.
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {
        // Ignore cleanup failures; the original error is what matters.
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String contactId) async {
    final dir = await _dir();
    final file = _fileFor(dir, contactId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<Map<String, MemoryDocument>> listAll() async {
    final dir = await _dir();
    final files = await _listFiles(dir);
    final out = <String, MemoryDocument>{};
    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final doc = MemoryDocument.parse(raw);
        // Skip parse failures: an empty contactId means the
        // frontmatter was missing or unreadable. Don't drop these
        // files from disk; just leave them out of the snapshot.
        if (doc.contactId.isEmpty) continue;
        out[doc.contactId] = doc;
      } catch (_) {
        // Defensive: parse is total, but I/O can still throw.
        continue;
      }
    }
    return Map.unmodifiable(out);
  }

  /// Returns every `*.md` file directly under `dir`, excluding
  /// `*.md.tmp` orphans.
  Future<List<File>> _listFiles(Directory dir) async {
    final entries = await dir.list(followLinks: false).toList();
    final files = <File>[];
    for (final entry in entries) {
      if (entry is! File) continue;
      final path = entry.path;
      if (!path.endsWith('.md')) continue;
      if (path.endsWith('.md.tmp')) continue;
      files.add(entry);
    }
    return files;
  }
}

/// Returns a copy of `doc` whose rendered UTF-8 size fits in
/// `capBytes`, dropping the oldest `## History` bullet (`- ...` line)
/// one at a time until it fits.
///
/// Topics, Summary, Preferences, and Upcoming are preserved per PRD
/// Q6. Throws [MemoryCapExceededException] if the doc still exceeds
/// the cap with zero history bullets left to drop (e.g., a
/// pathologically large `## Summary`).
///
/// Pure: takes a doc, returns a doc. No filesystem access. Top-level
/// so it can be unit-tested without a temp directory.
MemoryDocument trimToCap(
  MemoryDocument doc, {
  int capBytes = _perContactCapBytes,
}) {
  var current = doc;
  while (utf8.encode(current.render()).length > capBytes) {
    final next = _dropOldestHistoryBullet(current);
    if (next == null) {
      throw MemoryCapExceededException(
        'Document for "${doc.contactId}" exceeds $capBytes bytes with '
        'no history bullets left to drop.',
      );
    }
    current = next;
  }
  return current;
}

/// Returns `doc.copyWith` with the oldest `- ` bullet removed from
/// `history`, or null when there is no bullet line to drop. The
/// "oldest" bullet is the first `- ` line in textual order — bullets
/// are appended chronologically per the PRD's append-only history
/// rule.
MemoryDocument? _dropOldestHistoryBullet(MemoryDocument doc) {
  final lines = doc.history.split('\n');
  var dropIdx = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('- ')) {
      dropIdx = i;
      break;
    }
  }
  if (dropIdx < 0) return null;
  final next = [...lines]..removeAt(dropIdx);
  return doc.copyWith(history: next.join('\n'));
}
