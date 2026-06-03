import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/connections/firebase_connection_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Connection makeConnection({DateTime? lastBondDriftAppliedAt}) {
    return Connection(
      id: 'sarah',
      name: 'Sarah Chen',
      email: 'sarah@example.com',
      category: 'Friends',
      avatar: '👤',
      bondScore: 85,
      nextStep: 'Send the article',
      lastContact: DateTime.utc(2026, 5, 20),
      notes: 'Knows the team.',
      knownSince: DateTime.utc(2024, 1, 15),
      preferredChannels: const ['Text', 'Email'],
      lastBondDriftAppliedAt: lastBondDriftAppliedAt,
    );
  }

  Map<String, dynamic> encodedConnection({
    Object? lastBondDriftAppliedAt = _absent,
  }) {
    final data = <String, dynamic>{
      'id': 'sarah',
      'name': 'Sarah Chen',
      'email': 'sarah@example.com',
      'category': 'Friends',
      'avatar': '👤',
      'bondScore': 85,
      'nextStep': 'Send the article',
      'lastContact': Timestamp.fromDate(DateTime.utc(2026, 5, 20)),
      'notes': 'Knows the team.',
      'knownSince': Timestamp.fromDate(DateTime.utc(2024, 1, 15)),
      'preferredChannels': ['Text', 'Email'],
      'schemaVersion': FirebaseConnectionStore.schemaVersion,
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 5, 26)),
    };
    if (lastBondDriftAppliedAt != _absent) {
      data['lastBondDriftAppliedAt'] = lastBondDriftAppliedAt;
    }
    return data;
  }

  group('FirebaseConnectionStore connection mapping', () {
    test('encode omits lastBondDriftAppliedAt when absent', () {
      final encoded = FirebaseConnectionStore.encode(makeConnection());

      expect(encoded, isNot(contains('lastBondDriftAppliedAt')));
    });

    test('encode writes lastBondDriftAppliedAt timestamp when present', () {
      final appliedAt = DateTime.utc(2026, 6, 4, 12, 30);
      final encoded = FirebaseConnectionStore.encode(
        makeConnection(lastBondDriftAppliedAt: appliedAt),
      );

      expect(encoded['lastBondDriftAppliedAt'], Timestamp.fromDate(appliedAt));
    });

    test(
      'decode keeps old connection documents without drift timestamp valid',
      () {
        final decoded = FirebaseConnectionStore.decode(encodedConnection());

        expect(decoded, isNotNull);
        expect(decoded!.lastBondDriftAppliedAt, isNull);
      },
    );

    test('decode reads lastBondDriftAppliedAt timestamp when present', () {
      final appliedAt = Timestamp.fromDate(DateTime.utc(2026, 6, 4, 12, 30));
      final decoded = FirebaseConnectionStore.decode(
        encodedConnection(lastBondDriftAppliedAt: appliedAt),
      );

      expect(decoded, isNotNull);
      expect(decoded!.lastBondDriftAppliedAt, appliedAt.toDate());
    });

    test('decode rejects non-timestamp lastBondDriftAppliedAt', () {
      final decoded = FirebaseConnectionStore.decode(
        encodedConnection(lastBondDriftAppliedAt: '2026-06-04T12:30:00Z'),
      );

      expect(decoded, isNull);
    });
  });
}

const _absent = Object();
