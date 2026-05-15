import 'package:flutter_test/flutter_test.dart';
import 'package:connect_me/src/models/social_models.dart';

void main() {
  group('Connection.isSample', () {
    test('defaults to false when not specified', () {
      final connection = Connection(
        id: 'test-id',
        name: 'Test User',
        email: 'test@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 50,
        nextStep: 'Follow up',
        lastContact: DateTime(2026, 5, 1),
        notes: 'Test notes',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: const ['Text'],
      );

      expect(connection.isSample, false);
    });

    test('can be set to true', () {
      final connection = Connection(
        id: 'test-id',
        name: 'Sample User',
        email: 'sample@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 50,
        nextStep: 'Follow up',
        lastContact: DateTime(2026, 5, 1),
        notes: 'Sample contact',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: const ['Text'],
        isSample: true,
      );

      expect(connection.isSample, true);
    });

    test('copyWith preserves isSample when not changed', () {
      final connection = Connection(
        id: 'test-id',
        name: 'Sample User',
        email: 'sample@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 50,
        nextStep: 'Follow up',
        lastContact: DateTime(2026, 5, 1),
        notes: 'Sample contact',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: const ['Text'],
        isSample: true,
      );

      final updated = connection.copyWith(name: 'Updated Name');

      expect(updated.isSample, true);
      expect(updated.name, 'Updated Name');
    });

    test('copyWith can change isSample', () {
      final connection = Connection(
        id: 'test-id',
        name: 'Sample User',
        email: 'sample@example.com',
        category: 'Friends',
        avatar: '👤',
        bondScore: 50,
        nextStep: 'Follow up',
        lastContact: DateTime(2026, 5, 1),
        notes: 'Sample contact',
        knownSince: DateTime(2020, 1, 1),
        preferredChannels: const ['Text'],
        isSample: true,
      );

      final updated = connection.copyWith(isSample: false);

      expect(updated.isSample, false);
    });
  });
}
