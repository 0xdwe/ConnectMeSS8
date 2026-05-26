import 'package:connect_me/src/state/connections/connection_seeder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless tests for the [ConnectionSeeder] planning logic
/// (Pass 4.5 #069).
///
/// `ConnectionSeeder.run()` itself touches Firestore so it lives in
/// the integration test substrate. The pure planning logic
/// ([computePlan], [SeederPlan], [SeederSampleSource], [SeederResult],
/// [SeederSentinels.all]) is exercised here. Together they cover
/// the AC for branching, idempotency, and partial-state recovery —
/// the only thing the integration test adds is "the actual batch
/// commits and the sentinels land."
void main() {
  group('SeederSentinels', () {
    test('all returns the five expected sentinel field names', () {
      expect(
        SeederSentinels.all,
        unorderedEquals(<String>[
          'connectionsSeededAt',
          'interactionsSeededAt',
          'eventsSeededAt',
          'categoriesSeededAt',
          'eventTypesSeededAt',
        ]),
      );
    });

    test('individual constants match the canonical names', () {
      expect(SeederSentinels.connections, 'connectionsSeededAt');
      expect(SeederSentinels.interactions, 'interactionsSeededAt');
      expect(SeederSentinels.events, 'eventsSeededAt');
      expect(SeederSentinels.categories, 'categoriesSeededAt');
      expect(SeederSentinels.eventTypes, 'eventTypesSeededAt');
    });
  });

  group('SeederSampleSource', () {
    test('connections returns the seeded sample list (5 entries)', () {
      // The seed list is sourced from AppState.seeded() and contains
      // David / Emily / Jessica / Mike / Sarah. The exact count is
      // pinned so a future change to AppState.seeded surfaces here
      // and forces an explicit decision to update Pass 4.5.
      final connections = SeederSampleSource.connections();
      expect(connections, hasLength(5));
      expect(
        connections.map((c) => c.id).toList(),
        unorderedEquals(<String>[
          'david',
          'emily',
          'jessica',
          'mike',
          'sarah',
        ]),
      );
      expect(
        connections.every((c) => c.isSample),
        isTrue,
        reason:
            'every seeded connection must carry isSample: true so the '
            'cleanup path in #070 / removeSampleConnections can find them.',
      );
    });

    test('interactions returns the seeded sample list', () {
      final interactions = SeederSampleSource.interactions();
      expect(interactions, isNotEmpty);
      // Each seeded interaction must reference one of the seeded
      // contacts; otherwise the cascade in #070 deleteConnection
      // would leave orphans.
      final contactIds =
          SeederSampleSource.connections().map((c) => c.id).toSet();
      for (final i in interactions) {
        expect(contactIds.contains(i.contactId), isTrue,
            reason: 'seeded interaction ${i.id} references unknown '
                'contactId ${i.contactId}.');
      }
    });

    test('events returns the seeded sample list', () {
      final events = SeederSampleSource.events();
      expect(events, isNotEmpty);
      // Seeded events with a contactId must reference a seeded
      // contact. Free-floating events (contactId == null) are
      // allowed.
      final contactIds =
          SeederSampleSource.connections().map((c) => c.id).toSet();
      for (final e in events) {
        if (e.contactId != null) {
          expect(contactIds.contains(e.contactId), isTrue,
              reason: 'seeded event ${e.id} references unknown '
                  'contactId ${e.contactId}.');
        }
      }
    });

    test('categories and eventTypes are non-empty defaults', () {
      expect(SeederSampleSource.categories(), isNotEmpty);
      expect(SeederSampleSource.eventTypes(), isNotEmpty);
    });
  });

  group('computePlan — samples branch', () {
    test('fresh user (no sentinels) seeds every target', () {
      final plan = computePlan(
        choice: SeederChoice.samples,
        existingSentinels: const <String>{},
      );
      expect(plan.connections, isTrue);
      expect(plan.interactions, isTrue);
      expect(plan.events, isTrue);
      expect(plan.categories, isTrue);
      expect(plan.eventTypes, isTrue);
      expect(plan.connectionsSentinel, isTrue);
      expect(plan.interactionsSentinel, isTrue);
      expect(plan.eventsSentinel, isTrue);
      expect(plan.isNoOp, isFalse);
    });

    test('all-sentinels-set is a no-op', () {
      final plan = computePlan(
        choice: SeederChoice.samples,
        existingSentinels: SeederSentinels.all.toSet(),
      );
      expect(plan.connections, isFalse);
      expect(plan.interactions, isFalse);
      expect(plan.events, isFalse);
      expect(plan.categories, isFalse);
      expect(plan.eventTypes, isFalse);
      expect(plan.connectionsSentinel, isFalse);
      expect(plan.interactionsSentinel, isFalse);
      expect(plan.eventsSentinel, isFalse);
      expect(plan.isNoOp, isTrue);
    });

    test('partial-state recovery: only missing sentinels run', () {
      // Imagine a previous run failed mid-batch and the categories
      // sentinel landed but the connections sentinel did not. The
      // next run must re-do the connections branch but NOT the
      // categories branch.
      final plan = computePlan(
        choice: SeederChoice.samples,
        existingSentinels: const <String>{
          'categoriesSeededAt',
        },
      );
      expect(plan.connections, isTrue);
      expect(plan.interactions, isTrue);
      expect(plan.events, isTrue);
      expect(plan.categories, isFalse,
          reason: 'categoriesSeededAt is set, so categories must be '
              'a no-op even though the rest of the run proceeds.');
      expect(plan.eventTypes, isTrue);
      expect(plan.connectionsSentinel, isTrue);
      expect(plan.eventsSentinel, isTrue);
      expect(plan.isNoOp, isFalse);
    });

    test('connections-only-set: that branch is a no-op, others run', () {
      final plan = computePlan(
        choice: SeederChoice.samples,
        existingSentinels: const <String>{
          'connectionsSeededAt',
        },
      );
      expect(plan.connections, isFalse);
      expect(plan.connectionsSentinel, isFalse,
          reason: 'never re-write a sentinel that is already set; '
              'the previously valid timestamp survives partial-state '
              'recovery.');
      expect(plan.interactions, isTrue);
      expect(plan.events, isTrue);
      expect(plan.categories, isTrue);
      expect(plan.eventTypes, isTrue);
      expect(plan.isNoOp, isFalse);
    });
  });

  group('computePlan — fresh branch', () {
    test('fresh user with fresh choice writes sentinels + categories/eventTypes',
        () {
      final plan = computePlan(
        choice: SeederChoice.fresh,
        existingSentinels: const <String>{},
      );
      expect(plan.connections, isFalse,
          reason: 'fresh choice must NOT write sample connections.');
      expect(plan.interactions, isFalse);
      expect(plan.events, isFalse);
      expect(plan.categories, isTrue,
          reason: 'PRD §Q12 — categories defaults are seeded for '
              'fresh-start users too.');
      expect(plan.eventTypes, isTrue);
      // Sentinels DO get written even though samples are not, so
      // the next launch short-circuits.
      expect(plan.connectionsSentinel, isTrue);
      expect(plan.interactionsSentinel, isTrue);
      expect(plan.eventsSentinel, isTrue);
      expect(plan.isNoOp, isFalse);
    });

    test('fresh choice with categories already set writes nothing else', () {
      final plan = computePlan(
        choice: SeederChoice.fresh,
        existingSentinels: SeederSentinels.all.toSet(),
      );
      expect(plan.connections, isFalse);
      expect(plan.interactions, isFalse);
      expect(plan.events, isFalse);
      expect(plan.categories, isFalse);
      expect(plan.eventTypes, isFalse);
      expect(plan.connectionsSentinel, isFalse);
      expect(plan.interactionsSentinel, isFalse);
      expect(plan.eventsSentinel, isFalse);
      expect(plan.isNoOp, isTrue);
    });

    test(
        'fresh choice does NOT trigger sample-branch booleans even '
        'when those sentinels are unset',
        () {
      // Belt-and-braces test against the bug "fresh choice mistakenly
      // seeds samples because the sentinel is unset."
      final plan = computePlan(
        choice: SeederChoice.fresh,
        existingSentinels: const <String>{
          'categoriesSeededAt',
          'eventTypesSeededAt',
          // connectionsSeededAt / interactionsSeededAt / eventsSeededAt
          // are all unset, but choice is fresh, so the sample-branch
          // booleans must remain false. The sentinel-write booleans
          // ARE true, so the next launch will short-circuit.
        },
      );
      expect(plan.connections, isFalse);
      expect(plan.interactions, isFalse);
      expect(plan.events, isFalse);
      expect(plan.connectionsSentinel, isTrue);
      expect(plan.interactionsSentinel, isTrue);
      expect(plan.eventsSentinel, isTrue);
      expect(plan.isNoOp, isFalse,
          reason: 'sentinel writes still need to run.');
    });

    test(
        'fresh choice in partial-state recovery does NOT re-write '
        'an already-set sentinel',
        () {
      // Bug class fix: an earlier draft used
      //   `plan.connections || plan.choice == SeederChoice.fresh`
      // to decide the connectionsSeededAt write, which would
      // re-write a previously valid timestamp every time. The
      // sentinel-write booleans are now strictly tied to the
      // "sentinel is unset" check.
      final plan = computePlan(
        choice: SeederChoice.fresh,
        existingSentinels: const <String>{
          'connectionsSeededAt',
        },
      );
      expect(plan.connectionsSentinel, isFalse,
          reason: 'never re-write a sentinel that is already set.');
      expect(plan.interactionsSentinel, isTrue);
      expect(plan.eventsSentinel, isTrue);
      expect(plan.connections, isFalse);
      expect(plan.interactions, isFalse);
      expect(plan.events, isFalse);
    });
  });

  group('SeederResult', () {
    test('SeederResult.noOp is a singleton with the expected shape', () {
      const result = SeederResult.noOp;
      expect(result.didSeed, isFalse);
      expect(result.didNoOp, isTrue);
      expect(result.connectionsWritten, 0);
      expect(result.interactionsWritten, 0);
      expect(result.eventsWritten, 0);
    });

    test('SeederResult records per-collection counts', () {
      const result = SeederResult(
        didSeed: true,
        didNoOp: false,
        connectionsWritten: 5,
        interactionsWritten: 3,
        eventsWritten: 5,
      );
      expect(result.didSeed, isTrue);
      expect(result.didNoOp, isFalse);
      expect(result.connectionsWritten, 5);
      expect(result.interactionsWritten, 3);
      expect(result.eventsWritten, 5);
    });
  });
}
