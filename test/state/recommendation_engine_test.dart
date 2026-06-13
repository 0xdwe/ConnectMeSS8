import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/memory/memory_document.dart';
import 'package:connect_me/src/state/recommendation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Connection _connection({
  required String id,
  required String name,
  required int bondScore,
  required DateTime lastContact,
  String category = 'Friends',
}) {
  return Connection(
    id: id,
    name: name,
    email: '$id@test.com',
    category: category,
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
    test('maintenance need severity outranks raw days-since recency', () {
      // Drifting Friends at 20d: adjusted cadence 16d → medium need.
      // Steady Friends at 31d: adjusted cadence 21d → medium need.
      // Close Friends at 40d: adjusted cadence 32d → medium need.
      // Medium-need ratio breaks ties, replacing raw days * tier weight.
      final connections = [
        _connection(
          id: 'a',
          name: 'Drifting Dana',
          bondScore: 40,
          lastContact: now.subtract(const Duration(days: 20)),
        ),
        _connection(
          id: 'b',
          name: 'Steady Sam',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 31)),
        ),
        _connection(
          id: 'c',
          name: 'Close Cory',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: 40)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(ranked.map((r) => r.contactId).toList(), ['b', 'a', 'c']);
    });

    test(
      'category cadence creates maintenance need before raw recency wins',
      () {
        final connections = [
          _connection(
            id: 'family',
            name: 'Family Fran',
            category: 'Family',
            bondScore: 60,
            lastContact: now.subtract(const Duration(days: 15)),
          ),
          _connection(
            id: 'college',
            name: 'College Casey',
            category: 'College',
            bondScore: 60,
            lastContact: now.subtract(const Duration(days: 30)),
          ),
        ];

        final ranked = rankRecommendations(
          connections: connections,
          interactions: const [],
          memories: const {},
          now: now,
        );

        expect(ranked.map((r) => r.contactId).toList(), ['family']);
      },
    );

    test('close-tier Bond Score durability gives grace before ranking', () {
      final connections = [
        _connection(
          id: 'close',
          name: 'Close Cory',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: 24)),
        ),
        _connection(
          id: 'steady',
          name: 'Steady Sam',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 18)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(ranked.map((r) => r.contactId).toList(), ['steady', 'close']);
    });

    test('recent interaction suppresses maintenance need via latest-touch', () {
      final connections = [
        _connection(
          id: 'touched',
          name: 'Touched Taylor',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 40)),
        ),
        _connection(
          id: 'quiet',
          name: 'Quiet Quinn',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 25)),
        ),
      ];
      final interactions = [
        CrmInteraction(
          id: 'i1',
          contactId: 'touched',
          type: InteractionType.interaction,
          title: 'Lunch',
          note: '',
          date: now.subtract(const Duration(days: 2)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: interactions,
        memories: const {},
        now: now,
      );

      expect(ranked.map((r) => r.contactId).toList(), ['quiet']);
    });

    test('ranks by maintenance need before tier at equal recency', () {
      const days = 20;
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

      expect(ranked.map((r) => r.contactId).toList(), ['drifting', 'steady']);
    });

    test('equal normalized urgency sorts deterministically by contact id', () {
      final connections = [
        _connection(
          id: 'z-family',
          name: 'Family Fran',
          category: 'Family',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 14)),
        ),
        _connection(
          id: 'a-friend',
          name: 'Friend Alex',
          category: 'Friends',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 21)),
        ),
      ];

      final ranked = rankRecommendations(
        connections: connections,
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(ranked.map((r) => r.contactId).toList(), ['a-friend', 'z-family']);
    });

    test('within-rhythm filtering excludes fresh connections', () {
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
          lastContact: now.subtract(const Duration(days: 25)),
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
            lastContact: now.subtract(Duration(days: 40 + i)),
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

    test('ranking does not mutate Bond Score or drift timestamp', () {
      final driftAppliedAt = now.subtract(const Duration(days: 30));
      final connection = _connection(
        id: 'safe',
        name: 'Safe Sam',
        bondScore: 40,
        lastContact: now.subtract(const Duration(days: 45)),
      ).copyWith(lastBondDriftAppliedAt: driftAppliedAt);

      rankRecommendations(
        connections: [connection],
        interactions: const [],
        memories: const {},
        now: now,
      );

      expect(connection.bondScore, 40);
      expect(connection.lastBondDriftAppliedAt, driftAppliedAt);
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

    test('sample fixture: top 3 ordered by maintenance need descending', () {
      // Mirrors #094 ranking: need severity first, ratio tie-break.
      final connections = [
        _connection(
          id: 'drifting',
          name: 'Drifting Dana',
          bondScore: 40,
          lastContact: now.subtract(const Duration(days: 40)), // high
        ),
        _connection(
          id: 'steady',
          name: 'Steady Sam',
          bondScore: 60,
          lastContact: now.subtract(const Duration(days: 24)), // medium
        ),
        _connection(
          id: 'close',
          name: 'Close Cory',
          bondScore: 90,
          lastContact: now.subtract(const Duration(days: 28)), // low
        ),
        _connection(
          id: 'recent',
          name: 'Recent Rae',
          bondScore: 60,
          lastContact: now.subtract(const Duration(hours: 2)), // none
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
    group('topic-aware recommendations (#099)', () {
      MemoryDocument memoryWithTopic({
        required String contactId,
        required String topic,
        required DateTime? lastMentionedAt,
        required int mentionCount,
        DateTime? expiresAt,
        String text = 'Ask how the Paris plans are coming together.',
        List<UpcomingEntry> upcoming = const [],
      }) {
        return MemoryDocument.empty(
          contactId: contactId,
          displayName: contactId,
          now: now,
        ).copyWith(
          topics: [topic],
          topicSuggestions: [
            TopicSuggestionGroup(
              topic: topic,
              lastMentionedAt: lastMentionedAt,
              mentionCount: mentionCount,
              expiresAt: expiresAt,
              suggestions: [
                TopicSuggestion(kind: TopicSuggestionKind.ask, text: text),
              ],
            ),
          ],
          upcoming: upcoming,
        );
      }

      test(
        'topic quality boost breaks ties after Maintenance Need severity',
        () {
          final connections = [
            _connection(
              id: 'topic',
              name: 'Topic Taylor',
              bondScore: 60,
              lastContact: now.subtract(const Duration(days: 21)),
            ),
            _connection(
              id: 'plain',
              name: 'Plain Pat',
              bondScore: 60,
              lastContact: now.subtract(const Duration(days: 21)),
            ),
          ];

          final ranked = rankRecommendations(
            connections: connections,
            interactions: const [],
            memories: {
              'topic': memoryWithTopic(
                contactId: 'topic',
                topic: 'Paris trip',
                lastMentionedAt: now.subtract(const Duration(days: 10)),
                mentionCount: 1,
              ),
            },
            now: now,
          );

          expect(ranked.map((r) => r.contactId).toList(), ['topic', 'plain']);
          expect(ranked.first.topic, 'Paris trip');
          expect(
            ranked.first.action,
            'Ask how the Paris plans are coming together.',
          );
          expect(
            ranked.first.reason,
            'Topic Taylor has Paris trip on their mind.',
          );
        },
      );

      test('Maintenance Need severity outranks topic boost', () {
        final connections = [
          _connection(
            id: 'low-topic',
            name: 'Low Topic',
            bondScore: 90,
            lastContact: now.subtract(const Duration(days: 33)),
          ),
          _connection(
            id: 'high-plain',
            name: 'High Plain',
            bondScore: 40,
            lastContact: now.subtract(const Duration(days: 33)),
          ),
        ];

        final ranked = rankRecommendations(
          connections: connections,
          interactions: const [],
          memories: {
            'low-topic': memoryWithTopic(
              contactId: 'low-topic',
              topic: 'Paris trip',
              lastMentionedAt: now.subtract(const Duration(days: 2)),
              mentionCount: 1,
            ),
          },
          now: now,
        );

        expect(ranked.first.contactId, 'high-plain');
      });

      test(
        'topic suggestions do not create urgency for within-rhythm contacts',
        () {
          final ranked = rankRecommendations(
            connections: [
              _connection(
                id: 'fresh-topic',
                name: 'Fresh Topic',
                bondScore: 60,
                lastContact: now.subtract(const Duration(days: 2)),
              ),
            ],
            interactions: const [],
            memories: {
              'fresh-topic': memoryWithTopic(
                contactId: 'fresh-topic',
                topic: 'Paris trip',
                lastMentionedAt: now.subtract(const Duration(days: 1)),
                mentionCount: 3,
              ),
            },
            now: now,
          );

          expect(ranked, isEmpty);
        },
      );

      test('quality gate accepts mention count or recent mention', () {
        final connections = [
          _connection(
            id: 'count',
            name: 'Count Casey',
            bondScore: 60,
            lastContact: now.subtract(const Duration(days: 21)),
          ),
          _connection(
            id: 'recent',
            name: 'Recent Riley',
            bondScore: 60,
            lastContact: now.subtract(const Duration(days: 21)),
          ),
          _connection(
            id: 'stale',
            name: 'Stale Sam',
            bondScore: 60,
            lastContact: now.subtract(const Duration(days: 21)),
          ),
        ];

        final ranked = rankRecommendations(
          connections: connections,
          interactions: const [],
          memories: {
            'count': memoryWithTopic(
              contactId: 'count',
              topic: 'Book club',
              lastMentionedAt: now.subtract(const Duration(days: 90)),
              mentionCount: 2,
            ),
            'recent': memoryWithTopic(
              contactId: 'recent',
              topic: 'Garden',
              lastMentionedAt: now.subtract(const Duration(days: 30)),
              mentionCount: 1,
            ),
            'stale': memoryWithTopic(
              contactId: 'stale',
              topic: 'Currency',
              lastMentionedAt: now.subtract(const Duration(days: 31)),
              mentionCount: 1,
            ),
          },
          now: now,
        );

        expect(
          ranked.where((r) => r.contactId == 'count').single.topic,
          'Book club',
        );
        expect(
          ranked.where((r) => r.contactId == 'recent').single.topic,
          'Garden',
        );
        expect(
          ranked.where((r) => r.contactId == 'stale').single.topic,
          isNull,
        );
      });

      test('same-contact upcoming overlay de-dupes topic regular card', () {
        final memory = memoryWithTopic(
          contactId: 'same',
          topic: 'Tokyo trip',
          lastMentionedAt: now,
          mentionCount: 2,
          upcoming: [UpcomingEntry(startDate: now, description: 'Tokyo trip')],
        );

        final ranked = rankRecommendations(
          connections: [
            _connection(
              id: 'same',
              name: 'Same Sam',
              bondScore: 60,
              lastContact: now.subtract(const Duration(days: 21)),
            ),
            _connection(
              id: 'plain',
              name: 'Plain Pat',
              bondScore: 60,
              lastContact: now.subtract(const Duration(days: 21)),
            ),
          ],
          interactions: const [],
          memories: {'same': memory},
          now: now,
        );

        expect(ranked.where((r) => r.contactId == 'same'), hasLength(1));
        expect(ranked.first.contactId, 'same');
        expect(ranked.first.topic, isNull);
      });

      test(
        'upcoming-tied topic passes quality gate but overlay still ranks first',
        () {
          final memory = memoryWithTopic(
            contactId: 'upcoming-topic',
            topic: 'Tokyo trip',
            lastMentionedAt: now.subtract(const Duration(days: 90)),
            mentionCount: 1,
            upcoming: [
              UpcomingEntry(
                startDate: now.add(const Duration(days: 10)),
                description: 'Tokyo trip',
              ),
            ],
          );

          final ranked = rankRecommendations(
            connections: [
              _connection(
                id: 'upcoming-topic',
                name: 'Upcoming Uma',
                bondScore: 60,
                lastContact: now.subtract(const Duration(days: 21)),
              ),
              _connection(
                id: 'overlay',
                name: 'Overlay Owen',
                bondScore: 60,
                lastContact: now.subtract(const Duration(days: 21)),
              ),
            ],
            interactions: const [],
            memories: {
              'upcoming-topic': memory,
              'overlay':
                  MemoryDocument.empty(
                    contactId: 'overlay',
                    displayName: 'Overlay Owen',
                    now: now,
                  ).copyWith(
                    upcoming: [
                      UpcomingEntry(startDate: now, description: 'workshop'),
                    ],
                  ),
            },
            now: now,
          );

          expect(ranked.first.contactId, 'overlay');
          final topicCard = ranked.singleWhere(
            (r) => r.contactId == 'upcoming-topic',
          );
          expect(topicCard.topic, 'Tokyo trip');
        },
      );

      test(
        'topic-aware copy contains no numeric day counts or guilt phrasing',
        () {
          final ranked = rankRecommendations(
            connections: [
              _connection(
                id: 'topic-copy',
                name: 'Topic Taylor',
                bondScore: 60,
                lastContact: now.subtract(const Duration(days: 21)),
              ),
            ],
            interactions: const [],
            memories: {
              'topic-copy': memoryWithTopic(
                contactId: 'topic-copy',
                topic: 'Paris trip',
                lastMentionedAt: now.subtract(const Duration(days: 1)),
                mentionCount: 2,
              ),
            },
            now: now,
          );

          final blob =
              '${ranked.single.reason} ${ranked.single.insight} ${ranked.single.action}'
                  .toLowerCase();
          expect(blob, isNot(matches(RegExp(r'\d'))));
          for (final phrase in [
            'overdue',
            'forgot',
            'neglect',
            'should have',
            'too long',
          ]) {
            expect(blob, isNot(contains(phrase)));
          }
        },
      );

      test('expired topic suggestions never surface', () {
        final ranked = rankRecommendations(
          connections: [
            _connection(
              id: 'expired',
              name: 'Expired Erin',
              bondScore: 60,
              lastContact: now.subtract(const Duration(days: 21)),
            ),
          ],
          interactions: const [],
          memories: {
            'expired': memoryWithTopic(
              contactId: 'expired',
              topic: 'Conference',
              lastMentionedAt: now.subtract(const Duration(days: 1)),
              mentionCount: 3,
              expiresAt: now.subtract(const Duration(days: 1)),
            ),
          },
          now: now,
        );

        expect(ranked.single.topic, isNull);
        expect(ranked.single.action, isNull);
      });
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
      lastContact: lastContact ?? now.subtract(const Duration(days: 25)),
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

      // Far-past Sam: only the Maintenance Need ranking should surface.
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

    test('upcoming card outranks the Maintenance Need ranking', () {
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
            lastContact: now.subtract(const Duration(days: 40)),
          ),
          _connection(
            id: 'steady',
            name: 'S',
            bondScore: 60,
            lastContact: now.subtract(const Duration(days: 24)),
          ),
          _connection(
            id: 'close',
            name: 'C',
            bondScore: 90,
            lastContact: now.subtract(const Duration(days: 28)),
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
