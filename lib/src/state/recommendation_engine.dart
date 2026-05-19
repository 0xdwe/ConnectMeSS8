import '../models/social_models.dart';
import '../widgets/bond_ring.dart';
import 'memory/memory_document.dart';

/// Pure-function recommendation engine.
///
/// Reads connections, interactions, per-contact memory map, and `now`;
/// returns up to 3 ranked [Recommendation]s.
///
/// PRD Q11 ranking:
///   score = daysSinceContact * tierWeight
///   tierWeight = { drifting: 1.5, steady: 1.0, close: 0.8 }
///   filter daysSinceContact < 1 (24h cooldown)
///   top N = 3
///
/// Mock-path narrative copy is deterministic and respects the PRD's
/// anti-shame guardrail: no numeric day counts, no guilt phrasing.
/// Recency buckets ('a few days ago', 'a few weeks ago', 'a while
/// back') are the rendered cadence.
///
/// `interactions` and `memories` are accepted but unused in #047.
/// They sit in the signature so the engine stays stable through
/// #048 (caching) and #049 (memory-driven cards).
List<Recommendation> rankRecommendations({
  required List<Connection> connections,
  required List<CrmInteraction> interactions,
  required Map<String, MemoryDocument> memories,
  required DateTime now,
}) {
  final scored = <_Scored>[];
  for (final connection in connections) {
    final daysSince = now.difference(connection.lastContact).inDays;
    if (daysSince < 1) continue; // 24h cooldown
    final tier = BondTier.from(connection.bondScore);
    final weight = _tierWeight(tier);
    final score = daysSince * weight;
    scored.add(_Scored(
      connection: connection,
      tier: tier,
      daysSince: daysSince,
      score: score,
    ));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  final top = scored.take(3).toList(growable: false);
  return top.map(_toRecommendation).toList(growable: false);
}

double _tierWeight(BondTier tier) => switch (tier) {
      BondTier.drifting => 1.5,
      BondTier.steady => 1.0,
      BondTier.close => 0.8,
    };

class _Scored {
  const _Scored({
    required this.connection,
    required this.tier,
    required this.daysSince,
    required this.score,
  });

  final Connection connection;
  final BondTier tier;
  final int daysSince;
  final double score;
}

Recommendation _toRecommendation(_Scored s) {
  final bucket = _recencyBucket(s.daysSince);
  return Recommendation(
    contactId: s.connection.id,
    reason: _reasonFor(s.tier, s.connection.name),
    insight: _insightFor(s.tier, bucket),
    priority: _priorityFor(s.tier),
  );
}

/// Coarse recency buckets. Day counts never reach the user.
String _recencyBucket(int days) {
  if (days <= 7) return 'a few days ago';
  if (days <= 30) return 'a few weeks ago';
  return 'a while back';
}

/// Question-shaped, second-person, never imperative, never shame.
/// PRODUCT.md voice: "Wondering how Mike's job hunt went?"
String _reasonFor(BondTier tier, String name) => switch (tier) {
      BondTier.close => "Wondering how $name has been?",
      BondTier.steady => "Want to check in on $name?",
      BondTier.drifting => "Curious how $name is doing?",
    };

String _insightFor(BondTier tier, String bucket) => switch (tier) {
      BondTier.close => 'You two talk often — last chat was $bucket.',
      BondTier.steady => 'Last chat was $bucket.',
      BondTier.drifting =>
        "It's been $bucket — a quick hello goes a long way.",
    };

/// Priority field is filled deterministically from tier so the
/// existing UI keeps compiling. UI-side rendering of priority is out
/// of scope for #047.
String _priorityFor(BondTier tier) => switch (tier) {
      BondTier.drifting => 'high priority',
      BondTier.steady => 'medium priority',
      BondTier.close => 'low priority',
    };
