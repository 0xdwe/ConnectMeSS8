import 'package:connect_me/src/state/memory/in_memory_memory_store.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryDocument _doc(String id, {String name = 'Person'}) {
  return MemoryDocument(
    contactId: id,
    displayName: name,
    lastUpdated: DateTime.utc(2026, 5, 19),
    summary: 'summary for $id',
  );
}

void main() {
  group('InMemoryMemoryStore', () {
    test('save then load round-trips', () async {
      final store = InMemoryMemoryStore();
      final doc = _doc('sarah');

      await store.save(doc);
      final loaded = await store.load('sarah');

      expect(loaded, isNotNull);
      expect(loaded!.contactId, 'sarah');
      expect(loaded.summary, 'summary for sarah');
    });

    test('load on unknown id returns null', () async {
      final store = InMemoryMemoryStore();
      expect(await store.load('nope'), isNull);
    });

    test('delete removes; load after delete returns null', () async {
      final store = InMemoryMemoryStore();
      await store.save(_doc('mike'));
      await store.delete('mike');

      expect(await store.load('mike'), isNull);
    });

    test('delete on missing id is a no-op', () async {
      final store = InMemoryMemoryStore();
      // Must not throw.
      await store.delete('not-there');
      expect(await store.load('not-there'), isNull);
    });

    test('listAll returns every saved document', () async {
      final store = InMemoryMemoryStore();
      await store.save(_doc('a'));
      await store.save(_doc('b'));
      await store.save(_doc('c'));

      final all = await store.listAll();
      expect(all.keys, containsAll(['a', 'b', 'c']));
      expect(all, hasLength(3));
    });

    test('listAll snapshot is unmodifiable', () async {
      final store = InMemoryMemoryStore();
      await store.save(_doc('a'));

      final all = await store.listAll();
      expect(() => all['b'] = _doc('b'), throwsUnsupportedError);
    });
  });
}
