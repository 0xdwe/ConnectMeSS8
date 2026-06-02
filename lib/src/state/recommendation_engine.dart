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
  // 1. Upcoming-driven special cards (PRD Q12).
  //
  //    Surface a special recommendation when a `MemoryDocument.upcoming`
  //    entry's endDate (or startDate if no endDate) falls in the
  //    window [now - 3d, now + 1d]. These cards rank ABOVE the
  //    bond-tier-weighted ranking and reduce the remaining slot count
  //    accordingly — we'd rather surface "Wondering how Sam's
  //    USA trip went?" than a third drifting reminder.
  //
  //    The Mock updater never populates `upcoming` (extracting
  //    "tomorrow" / "for a week" deterministically is too brittle).
  //    The engine logic exists so Pass 4's LLM adapter doesn't have
  //    to revisit the engine when memory.upcoming starts being
  //    populated for real.
  final byId = {for (final c in connections) c.id: c};
  final special = <Recommendation>[];
  // Iterate connections rather than memories.entries so output order
  // is deterministic regardless of the map's iteration order.
  for (final connection in connections) {
    final memory = memories[connection.id];
    if (memory == null) continue;
    for (final entry in memory.upcoming) {
      final card = _upcomingRecommendation(connection, entry, now);
      if (card != null) {
        special.add(card);
        break; // At most one upcoming card per contact.
      }
    }
  }

  final remainingSlots = 3 - special.length;
  if (remainingSlots <= 0) {
    return special.take(3).toList(growable: false);
  }

  // 2. Bond-tier-weighted recency for the remaining slots (PRD Q11).
  final specialIds = {for (final r in special) r.contactId};
  final scored = <_Scored>[];
  for (final connection in connections) {
    if (specialIds.contains(connection.id)) continue; // de-dupe
    final daysSince = now.difference(connection.lastContact).inDays;
    if (daysSince < 1) continue; // 24h cooldown
    final tier = BondTier.from(connection.bondScore);
    final weight = _tierWeight(tier);
    final score = daysSince * weight;
    scored.add(
      _Scored(
        connection: connection,
        tier: tier,
        daysSince: daysSince,
        score: score,
      ),
    );
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  final ranked = scored.take(remainingSlots).map(_toRecommendation);

  // Reference `byId` so the variable isn't dead in builds where the
  // upcoming branch never matched any contact. Also documents that
  // the lookup is by id.
  assert(byId.length == connections.length);

  return [...special, ...ranked];
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
  BondTier.drifting => "It's been $bucket — a quick hello goes a long way.",
};

/// Priority field is filled deterministically from tier so the
/// existing UI keeps compiling. UI-side rendering of priority is out
/// of scope for #047.
String _priorityFor(BondTier tier) => switch (tier) {
  BondTier.drifting => 'high priority',
  BondTier.steady => 'medium priority',
  BondTier.close => 'low priority',
};

// ---------------------------------------------------------------------------
// Upcoming-driven cards (PRD Q12 / #049).
// ---------------------------------------------------------------------------

/// Window edges, expressed as durations from `now`. The window is
/// `[now - postTripWindow, now + preTripWindow]` for the entry's
/// effective date (endDate when present, otherwise startDate).
const Duration _postTripWindow = Duration(days: 3);
const Duration _preTripWindow = Duration(days: 1);

/// Returns a special-card recommendation for `entry` if its effective
/// date sits in the trip window, else null.
///
/// Effective date: `endDate` if present, else `startDate`. The two
/// flavors of card are:
///   - Post-trip:  effective ∈ [now - 3d, now]
///   - Pre-trip:   effective ∈ (now, now + 1d]
///
/// Anti-shame guardrail still applies: no numeric day counts in copy.
Recommendation? _upcomingRecommendation(
  Connection connection,
  UpcomingEntry entry,
  DateTime now,
) {
  final effective = entry.endDate ?? entry.startDate;
  final earliest = now.subtract(_postTripWindow);
  final latest = now.add(_preTripWindow);
  if (effective.isBefore(earliest) || effective.isAfter(latest)) {
    return null;
  }
  final isPostTrip = !effective.isAfter(now); // effective ≤ now
  final reason = isPostTrip
      ? "Wondering how ${connection.name}'s ${entry.description} went?"
      : "${connection.name}'s ${entry.description} is coming up.";
  final insight = isPostTrip
      ? 'They might have stories to share.'
      : 'A short note before they head out goes a long way.';
  return Recommendation(
    contactId: connection.id,
    reason: reason,
    insight: insight,
    // Upcoming cards are time-bound and visible regardless of tier;
    // tag them medium so existing UI doesn't render a high-priority
    // pill for what is really a warmth nudge.
    priority: 'medium priority',
  );
}
