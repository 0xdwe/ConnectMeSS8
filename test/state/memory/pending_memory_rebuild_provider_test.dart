import 'package:connect_me/src/state/memory/memory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pendingMemoryRebuildProvider', () {
    test('starts as null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingMemoryRebuildProvider), isNull);
    });

    test('setContactId updates the state to the given contact ID', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(pendingMemoryRebuildProvider.notifier)
          .setContactId('sarah');

      expect(container.read(pendingMemoryRebuildProvider), equals('sarah'));
    });

    test('setContactId(null) clears the state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pendingMemoryRebuildProvider.notifier);
      notifier.setContactId('sarah');
      expect(container.read(pendingMemoryRebuildProvider), equals('sarah'));

      notifier.setContactId(null);
      expect(container.read(pendingMemoryRebuildProvider), isNull);
    });

    test('can set different contact IDs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pendingMemoryRebuildProvider.notifier);
      notifier.setContactId('sarah');
      expect(container.read(pendingMemoryRebuildProvider), equals('sarah'));

      notifier.setContactId('mike');
      expect(container.read(pendingMemoryRebuildProvider), equals('mike'));
    });
  });
}
