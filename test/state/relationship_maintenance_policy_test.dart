import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/relationship_maintenance_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 4, 12);

  Connection connection({
    String id = 'c1',
    String category = 'Friends',
    int bondScore = 50,
    DateTime? lastContact,
    DateTime? lastBondDriftAppliedAt,
  }) {
    return Connection(
      id: id,
      name: 'Test Contact',
      email: 'test@example.com',
      category: category,
      avatar: '🙂',
      bondScore: bondScore,
      nextStep: '',
      lastContact: lastContact ?? now.subtract(const Duration(days: 1)),
      notes: '',
      knownSince: now.subtract(const Duration(days: 365)),
      preferredChannels: const ['Text'],
      lastBondDriftAppliedAt: lastBondDriftAppliedAt,
    );
  }

  CrmInteraction interaction({
    String id = 'i1',
    String contactId = 'c1',
    DateTime? date,
  }) {
    return CrmInteraction(
      id: id,
      contactId: contactId,
      type: InteractionType.interaction,
      title: 'Chat',
      note: '',
      date: date ?? now,
    );
  }

  group('cadence calibration', () {
    final cases = [
      ('Family', 50, 14),
      ('Friends', 50, 21),
      ('Work', 50, 30),
      ('College', 50, 45),
      ('High School', 50, 45),
      ('Book Club', 50, 21),
      ('Family', 80, 21),
      ('Friends', 49, 16),
    ];

    for (final (category, bondScore, expectedDays) in cases) {
      test(
        '$category score $bondScore adjusts cadence to $expectedDays days',
        () {
          final result = RelationshipMaintenancePolicy.evaluate(
            connection: connection(category: category, bondScore: bondScore),
            interactions: const [],
            now: now,
          );

          expect(result.adjustedCadence, Duration(days: expectedDays));
        },
      );
    }
  });

  test('latest touch is max of lastContact and matching interactions only', () {
    final olderLastContact = now.subtract(const Duration(days: 20));
    final matchingLatest = now.subtract(const Duration(days: 5));
    final otherContactNewer = now.subtract(const Duration(days: 1));

    final result = RelationshipMaintenancePolicy.evaluate(
      connection: connection(lastContact: olderLastContact),
      interactions: [
        interaction(id: 'old', date: now.subtract(const Duration(days: 12))),
        interaction(id: 'match', date: matchingLatest),
        interaction(id: 'other', contactId: 'c2', date: otherContactNewer),
      ],
      now: now,
    );

    expect(result.latestTouchAt, matchingLatest);
  });

  test('latest touch falls back to lastContact when it is newer', () {
    final lastContact = now.subtract(const Duration(days: 3));

    final result = RelationshipMaintenancePolicy.evaluate(
      connection: connection(lastContact: lastContact),
      interactions: [interaction(date: now.subtract(const Duration(days: 8)))],
      now: now,
    );

    expect(result.latestTouchAt, lastContact);
  });

  group('Maintenance Need buckets', () {
    final cases = [
      (15, MaintenanceNeed.none),
      (16, MaintenanceNeed.low),
      (21, MaintenanceNeed.medium),
      (31, MaintenanceNeed.medium),
      (32, MaintenanceNeed.high),
    ];

    for (final (elapsedDays, expectedNeed) in cases) {
      test('$elapsedDays elapsed days -> $expectedNeed', () {
        final result = RelationshipMaintenancePolicy.evaluate(
          connection: connection(
            category: 'Friends',
            bondScore: 50,
            lastContact: now.subtract(Duration(days: elapsedDays)),
          ),
          interactions: const [],
          now: now,
        );

        expect(result.maintenanceNeed, expectedNeed);
      });
    }
  });

  group('Bond Drift buckets and caps', () {
    test('below drift threshold returns zero drift', () {
      final result = RelationshipMaintenancePolicy.evaluate(
        connection: connection(
          category: 'Friends',
          bondScore: 50,
          lastContact: now.subtract(const Duration(days: 31)),
        ),
        interactions: const [],
        now: now,
      );

      expect(result.candidateBondDrift, 0);
      expect(result.driftReason, BondDriftReason.withinDriftGrace);
    });

    group('exact bucket boundaries', () {
      final steadyCases = [
        (31.5, -1, BondDriftReason.clearlyOutsideRhythm),
        (42.0, -2, BondDriftReason.farOutsideRhythm),
        (63.0, -2, BondDriftReason.farOutsideRhythm),
      ];

      for (final (elapsedDays, expectedDrift, expectedReason) in steadyCases) {
        test('steady tier ratio ${elapsedDays / 21} -> $expectedDrift', () {
          final result = RelationshipMaintenancePolicy.evaluate(
            connection: connection(
              category: 'Friends',
              bondScore: 50,
              lastContact: now.subtract(
                Duration(
                  milliseconds: (elapsedDays * 24 * 60 * 60 * 1000).toInt(),
                ),
              ),
            ),
            interactions: const [],
            now: now,
          );

          expect(result.adjustedCadence, const Duration(days: 21));
          expect(result.candidateBondDrift, expectedDrift);
          expect(result.driftReason, expectedReason);
        });
      }

      test('drifting tier ratio greater than 3.0 can reach -3', () {
        final result = RelationshipMaintenancePolicy.evaluate(
          connection: connection(
            category: 'Friends',
            bondScore: 40,
            lastContact: now.subtract(const Duration(days: 49)),
          ),
          interactions: const [],
          now: now,
        );

        expect(result.adjustedCadence, const Duration(days: 16));
        expect(result.candidateBondDrift, -3);
        expect(result.driftReason, BondDriftReason.veryFarOutsideRhythm);
      });
    });

    test('high Bond Score caps drift at -1', () {
      final result = RelationshipMaintenancePolicy.evaluate(
        connection: connection(
          category: 'Friends',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: 100)),
        ),
        interactions: const [],
        now: now,
      );

      expect(result.adjustedCadence, const Duration(days: 32));
      expect(result.candidateBondDrift, -1);
      expect(result.bondTier, BondDurabilityTier.close);
    });

    test('Work category caps drift at -1 regardless of tier', () {
      final result = RelationshipMaintenancePolicy.evaluate(
        connection: connection(
          category: 'Work',
          bondScore: 20,
          lastContact: now.subtract(const Duration(days: 100)),
        ),
        interactions: const [],
        now: now,
      );

      expect(result.candidateBondDrift, -1);
    });

    test('candidate drift clamps so Bond Score cannot go below zero', () {
      final result = RelationshipMaintenancePolicy.evaluate(
        connection: connection(
          category: 'Friends',
          bondScore: 1,
          lastContact: now.subtract(const Duration(days: 100)),
        ),
        interactions: const [],
        now: now,
      );

      expect(result.candidateBondDrift, -1);
    });
  });

  group('drift application window', () {
    test('null last drift timestamp is eligible', () {
      final result = RelationshipMaintenancePolicy.evaluate(
        connection: connection(lastBondDriftAppliedAt: null),
        interactions: const [],
        now: now,
      );

      expect(result.isBondDriftApplicationEligible, isTrue);
    });

    test('less than 7 days since last drift is ineligible', () {
      final result = RelationshipMaintenancePolicy.evaluate(
        connection: connection(
          lastBondDriftAppliedAt: now.subtract(
            const Duration(days: 6, hours: 23, minutes: 59),
          ),
        ),
        interactions: const [],
        now: now,
      );

      expect(result.isBondDriftApplicationEligible, isFalse);
    });

    test('exactly 7 days since last drift is eligible', () {
      final result = RelationshipMaintenancePolicy.evaluate(
        connection: connection(
          lastBondDriftAppliedAt: now.subtract(const Duration(days: 7)),
        ),
        interactions: const [],
        now: now,
      );

      expect(result.isBondDriftApplicationEligible, isTrue);
    });
  });

  test('result uses domain-coded values rather than user-copy strings', () {
    final result = RelationshipMaintenancePolicy.evaluate(
      connection: connection(
        lastContact: now.subtract(const Duration(days: 40)),
      ),
      interactions: const [],
      now: now,
    );

    expect(result.maintenanceNeed, MaintenanceNeed.high);
    expect(result.maintenanceReason, MaintenanceReason.farOutsideRhythm);
    expect(result.driftReason, BondDriftReason.clearlyOutsideRhythm);
    expect(result.toString(), isNot(contains('check in')));
    expect(result.toString(), isNot(contains('overdue')));
    expect(result.toString(), isNot(contains('neglected')));
  });
}
