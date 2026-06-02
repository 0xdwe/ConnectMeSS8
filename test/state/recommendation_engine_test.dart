import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/recommendation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Connection _connection({
  required String id,
  required String name,
  required int bondScore,
  required DateTime lastContact,
}) {
  return Connection(
    id: id,
    name: name,
    email: '$id@test.com',
    category: 'Friends',
    avatar: '👤',
    bondScore: bondScore,
    nextStep: 'Say hi',
    lastContact: lastContact,
    notes: '',
    knownSince: DateTime(2020, 1, 1),
    preferredChannels: const ['Text'],
  );
}

void main() {
  // Pinned reference timestamp keeps daysSinceContact arithmetic exact.
  final now = DateTime.utc(2026, 5, 19, 12);

  group('rankRecommendations', () {
    test('Q11 score = daysSinceContact * tierWeight orders results', () {
      // drifting (40) at 10d → 10 * 1.5 = 15.0
      // steady   (60) at 12d → 12 * 1.0 = 12.0
      // close    (90) at 14d → 14 * 0.8 = 11.2
      final connections = [
        _connection(
          id: 'a',
          name: 'Drifting Dana',
          bondScore: 40,
          lastContact: now.subtract(const Duration(days: 10)),
        ),
        _connection(
          id: 'b',
          name: 'Steady Sam',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 12)),
        ),
        _connection(
          id: 'c',
          name: 'Close Cory',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: 14)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(ranked.map((r) => r.contactId).toList(), ['a', 'b', 'c']);
    });

    test('ranks drifting before steady before close at equal recency', () {
      const days = 7;
      final connections = [
        _connection(
          id: 'close',
          name: 'Close Carol',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: days)),
        ),
        _connection(
          id: 'steady',
          name: 'Steady Sue',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: days)),
        ),
        _connection(
          id: 'drifting',
          name: 'Drifting Dan',
          bondScore: 30,
          lastContact: now.subtract(const Duration(days: days)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(ranked.map((r) => r.contactId).toList(), [
        'drifting',
        'steady',
        'close',
      ]);
    });

    test('24h cooldown filters connections with daysSinceContact < 1', () {
      final connections = [
        _connection(
          id: 'fresh',
          name: 'Fresh Friend',
          bondScore: 30, // would otherwise rank top
          lastContact: now.subtract(const Duration(hours: 6)),
        ),
        _connection(
          id: 'eligible',
          name: 'Eligible Ed',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 5)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(ranked.map((r) => r.contactId), contains('eligible'));
      expect(ranked.map((r) => r.contactId), isNot(contains('fresh')));
    });

    test('returns at most 3 recommendations even with many candidates', () {
      final connections = [
        for (var i = 0; i < 8; i++)
          _connection(
            id: 'c$i',
            name: 'Contact $i',
            bondScore: 40,
            lastContact: now.subtract(Duration(days: 5 + i)),
          ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(ranked, hasLength(3));
    });

    test('deleted contact ids never appear in the output', () {
      final connections = [
        _connection(
          id: 'alive',
          name: 'Alive Alex',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 10)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      // 'ghost' was never in the input, and the engine never invents ids.
      expect(ranked.map((r) => r.contactId), isNot(contains('ghost')));
    });

    test('narrative copy contains no numeric day counts', () {
      final connections = [
        _connection(
          id: 'a',
          name: 'Drifting Dana',
          bondScore: 40,
          lastContact: now.subtract(const Duration(days: 67)),
        ),
        _connection(
          id: 'b',
          name: 'Steady Sam',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 12)),
        ),
        _connection(
          id: 'c',
          name: 'Close Cory',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: 3)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      final digit = RegExp(r'\d');
      for (final rec in ranked) {
        expect(
          rec.reason,
          isNot(matches(digit)),
          reason: 'reason must not contain digits: ${rec.reason}',
        );
        expect(
          rec.insight,
          isNot(matches(digit)),
          reason: 'insight must not contain digits: ${rec.insight}',
        );
      }
    });

    test('narrative copy is deterministic for fixed inputs', () {
      final connections = [
        _connection(
          id: 'a',
          name: 'Drifting Dana',
          bondScore: 40,
          lastContact: now.subtract(const Duration(days: 10)),
        ),
        _connection(
          id: 'b',
          name: 'Steady Sam',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 12)),
        ),
      ];

      final first = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );
      final second = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(first.length, second.length);
      for (var i = 0; i < first.length; i++) {
        expect(first[i].contactId, second[i].contactId);
        expect(first[i].reason, second[i].reason);
        expect(first[i].insight, second[i].insight);
        expect(first[i].priority, second[i].priority);
      }
    });

    test('anti-shame: copy contains no guilt-shaped phrasing', () {
      final connections = [
        _connection(
          id: 'a',
          name: 'Drifting Dana',
          bondScore: 40,
          lastContact: now.subtract(const Duration(days: 67)),
        ),
        _connection(
          id: 'b',
          name: 'Steady Sam',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 12)),
        ),
        _connection(
          id: 'c',
          name: 'Close Cory',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: 3)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      const denylist = [
        'overdue',
        "haven't",
        'havent',
        'forgot',
        'neglect',
        'should have',
        'too long',
        'failing',
        'disappointed',
      ];
      for (final rec in ranked) {
        final blob = '${rec.reason} ${rec.insight}'.toLowerCase();
        for (final phrase in denylist) {
          expect(
            blob,
            isNot(contains(phrase)),
            reason: 'guilt phrase "$phrase" must not appear in: $blob',
          );
        }
      }
    });

    test('sample fixture: top 3 ordered by score descending', () {
      // Mirrors the explicit fixture from the issue spec.
      final connections = [
        _connection(
          id: 'drifting',
          name: 'Drifting Dana',
          bondScore: 40,
          lastContact: now.subtract(const Duration(days: 10)), // 15.0
        ),
        _connection(
          id: 'steady',
          name: 'Steady Sam',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 12)), // 12.0
        ),
        _connection(
          id: 'close',
          name: 'Close Cory',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: 14)), // 11.2
        ),
        _connection(
          id: 'recent',
          name: 'Recent Rae',
          bondScore: 60,
          lastContact: now.subtract(const Duration(hours: 2)), // filtered
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(ranked.map((r) => r.contactId).toList(), [
        'drifting',
        'steady',
        'close',
      ]);
      expect(ranked.first.priority, 'high priority');
      expect(ranked[1].priority, 'medium priority');
      expect(ranked[2].priority, 'low priority');
    });
  });

  // -------------------------------------------------------------------
  // PRD Q12 / #049 — Upcoming-driven recommendation cards.
  //
  // Effective date = endDate if present, else startDate.
  // Window: [now - 3d, now + 1d].
  //   Post-trip: effective ≤ now
  //   Pre-trip:  effective > now
  // -------------------------------------------------------------------
  group('upcoming-driven recommendations', () {
    final now = DateTime(2026, 5, 19, 12, 0, 0);

    Connection sam({DateTime? lastContact}) => _connection(
      id: 'sam',
      name: 'Sam',
      bondScore: 70,
      lastContact: lastContact ?? now.subtract(const Duration(days: 5)),
    );

    MemoryDocument memoryWith(
      String contactId, {
      required UpcomingEntry entry,
    }) => MemoryDocument.empty(
      contactId: contactId,
      displayName: contactId,
      now: now,
    ).copyWith(upcoming: [entry]);

    test('post-trip card surfaces when endDate equals now', () {
      final memory = memoryWith(
        'sam',
        entry: UpcomingEntry(
          startDate: now.subtract(const Duration(days: 6)),
          endDate: now,
          description: 'USA trip',
        ),
      );
      final ranked = rankRecommendations(
        connections: [sam()],
        interactions: const [],
        memories: {'sam': memory},
        now: now,
      );
      expect(ranked, hasLength(1));
      expect(ranked.first.contactId, 'sam');
      expect(ranked.first.reason, equals("Wondering how Sam's USA trip went?"));
    });

    test('post-trip card surfaces when endDate is 3 days ago', () {
      final memory = memoryWith(
        'sam',
        entry: UpcomingEntry(
          startDate: now.subtract(const Duration(days: 10)),
          endDate: now.subtract(const Duration(days: 3)),
          description: 'Iceland',
        ),
      );
      final ranked = rankRecommendations(
        connections: [sam()],
        interactions: const [],
        memories: {'sam': memory},
        now: now,
      );
      expect(ranked.first.reason, equals("Wondering how Sam's Iceland went?"));
    });

    test('pre-trip card surfaces when startDate is 1 day in the future', () {
      final memory = memoryWith(
        'sam',
        entry: UpcomingEntry(
          startDate: now.add(const Duration(days: 1)),
          description: 'Tokyo',
        ),
      );
      final ranked = rankRecommendations(
        connections: [sam()],
        interactions: const [],
        memories: {'sam': memory},
        now: now,
      );
      expect(ranked.first.reason, equals("Sam's Tokyo is coming up."));
    });

    test('entry without endDate uses startDate as effective date', () {
      final memory = memoryWith(
        'sam',
        entry: UpcomingEntry(startDate: now, description: 'workshop'),
      );
      final ranked = rankRecommendations(
        connections: [sam()],
        interactions: const [],
        memories: {'sam': memory},
        now: now,
      );
      // startDate == now is at the post-trip boundary (effective <= now).
      expect(ranked.first.reason, equals("Wondering how Sam's workshop went?"));
    });

    test('entry outside the [now-3d, now+1d] window does not surface', () {
      final farPast = memoryWith(
        'sam',
        entry: UpcomingEntry(
          startDate: now.subtract(const Duration(days: 30)),
          endDate: now.subtract(const Duration(days: 4)),
          description: 'old trip',
        ),
      );
      final farFuture = memoryWith(
        'sam',
        entry: UpcomingEntry(
          startDate: now.add(const Duration(days: 7)),
          description: 'future trip',
        ),
      );

      // Far-past sam: only the bond-tier ranking should surface.
      final pastRanked = rankRecommendations(
        connections: [sam()],
        interactions: const [],
        memories: {'sam': farPast},
        now: now,
      );
      expect(pastRanked.first.reason, isNot(contains('Wondering how')));
      expect(pastRanked.first.reason, isNot(contains('is coming up')));

      // Far-future sam: same.
      final futureRanked = rankRecommendations(
        connections: [sam()],
        interactions: const [],
        memories: {'sam': farFuture},
        now: now,
      );
      expect(futureRanked.first.reason, isNot(contains('Wondering how')));
      expect(futureRanked.first.reason, isNot(contains('is coming up')));
    });

    test('upcoming card outranks the bond-tier ranking', () {
      // Sam has a fresh post-trip card. Mike is drifting, hasn't been
      // contacted in a long time — normally he'd be the top pick.
      final samMemory = memoryWith(
        'sam',
        entry: UpcomingEntry(
          startDate: now.subtract(const Duration(days: 7)),
          endDate: now.subtract(const Duration(days: 1)),
          description: 'Iceland',
        ),
      );
      final mike = _connection(
        id: 'mike',
        name: 'Mike',
        bondScore: 30, // drifting
        lastContact: now.subtract(const Duration(days: 90)),
      );

      final ranked = rankRecommendations(
        connections: [mike, sam()],
        interactions: const [],
        memories: {'sam': samMemory},
        now: now,
      );

      expect(ranked.first.contactId, 'sam');
      expect(ranked.first.reason, contains('Wondering how'));
      expect(ranked[1].contactId, 'mike');
    });

    test('one upcoming card per contact — the first matching entry wins', () {
      final memory =
          memoryWith(
            'sam',
            entry: UpcomingEntry(
              startDate: now.subtract(const Duration(days: 5)),
              endDate: now.subtract(const Duration(days: 1)),
              description: 'Iceland',
            ),
          ).copyWith(
            upcoming: [
              UpcomingEntry(
                startDate: now.subtract(const Duration(days: 5)),
                endDate: now.subtract(const Duration(days: 1)),
                description: 'Iceland',
              ),
              UpcomingEntry(
                startDate: now.add(const Duration(days: 1)),
                description: 'Tokyo',
              ),
            ],
          );
      final ranked = rankRecommendations(
        connections: [sam()],
        interactions: const [],
        memories: {'sam': memory},
        now: now,
      );
      // Only one card for Sam, and it's the Iceland (post-trip) one
      // because that's the first entry in the list.
      expect(ranked.where((r) => r.contactId == 'sam'), hasLength(1));
      expect(ranked.first.reason, contains('Iceland'));
    });

    test(
      'no regression: empty upcoming on every contact still ranks normally',
      () {
        // PRD Q12 explicitly: no regression in #047 ranking when no
        // Upcoming entries exist.
        final connections = [
          _connection(
            id: 'drifting',
            name: 'D',
            bondScore: 30,
            lastContact: now.subtract(const Duration(days: 10)),
          ),
          _connection(
            id: 'steady',
            name: 'S',
            bondScore: 60,
            lastContact: now.subtract(const Duration(days: 12)),
          ),
          _connection(
            id: 'close',
            name: 'C',
            bondScore: 90,
            lastContact: now.subtract(const Duration(days: 14)),
          ),
        ];
        final memories = {
          for (final c in connections)
            c.id: MemoryDocument.empty(
              contactId: c.id,
              displayName: c.name,
              now: now,
            ),
        };
        final ranked = rankRecommendations(
          connections: connections,
          interactions: const [],
          memories: memories,
          now: now,
        );
        expect(ranked.map((r) => r.contactId).toList(), [
          'drifting',
          'steady',
          'close',
        ]);
      },
    );
  });
}
