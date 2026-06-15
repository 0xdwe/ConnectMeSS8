import '../models/social_models.dart';
import '../widgets/bond_ring.dart';
import 'memory/memory_document.dart';
import 'relationship_maintenance_policy.dart';

/// Pure-function recommendation engine.
///
/// Reads connections, interactions, per-contact memory map, and `now`;
/// returns up to 3 ranked [Recommendation]s.
///
/// Maintenance ranking:
///   primary = RelationshipMaintenancePolicy Maintenance Need
///   tie-break 1 = eligible Topic Suggestion quality boost
///   tie-break 2 = elapsed / adjusted cadence ratio
///   deterministic final tie-break = contact id
///   filter MaintenanceNeed.none
///   top N = 3
///
/// Mock-path narrative copy is deterministic and respects the PRD's
/// anti-shame guardrail: no numeric day counts, no guilt phrasing.
/// Recency buckets ('a few days ago', 'a few weeks ago', 'a while
/// back') are the rendered cadence.
///
/// `interactions` feed latest-touch Maintenance Need calculations;
/// `memories` feed upcoming-driven overlay cards.
List<Recommendation> rankRecommendations({
  required List<Connection> connections,
  required List<CrmInteraction> interactions,
  required Map<String, MemoryDocument> memories,
  required DateTime now,
  List<Recommendation>? previousList,
  DateTime? previousCacheTime,
  String? lastAiUpdatedContactId,
}) {
  // 1. Upcoming-driven special cards (PRD Q12).
  //
  //    Surface a special recommendation when a `MemoryDocument.upcoming`
  //    entry's endDate (or startDate if no endDate) falls in the
  //    window [now - 3d, now + 1d]. These cards rank ABOVE the
  //    Maintenance Need ranking and reduce the remaining slot count
  //    accordingly — we'd rather surface "Wondering how Sam's
  //    USA trip went?" than a third drifting reminder.
  //
  //    The Mock updater never populates `upcoming` (extracting
  //    "tomorrow" / "for a week" deterministically is too brittle).
  //    The engine logic exists so Pass 4's LLM adapter doesn't have
  //    to revisit the engine when memory.upcoming starts being
  //    populated for real.
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

  // 2. Maintenance Need ranking for the remaining slots (#094).
  final specialIds = {for (final r in special) r.contactId};
  final scored = <_Scored>[];
  for (final connection in connections) {
    if (specialIds.contains(connection.id)) continue; // de-dupe
    final result = RelationshipMaintenancePolicy.evaluate(
      connection: connection,
      interactions: interactions,
      now: now,
    );
    if (result.maintenanceNeed == MaintenanceNeed.none) continue;
    final elapsed = now.difference(result.latestTouchAt).inMilliseconds;
    final ratio = elapsed / result.adjustedCadence.inMilliseconds;
    scored.add(
      _Scored(
        connection: connection,
        tier: BondTier.from(connection.bondScore),
        need: result.maintenanceNeed,
        daysSince: now.difference(result.latestTouchAt).inDays,
        ratio: ratio,
        topic: _eligibleTopicSuggestion(
          memory: memories[connection.id],
          now: now,
        ),
      ),
    );
  }
  scored.sort(_compareScored);
  final ranked = scored.take(remainingSlots).map(_toRecommendation);

  // 3. Completion detection (Pass 4.6 / #115, #117).
  //
  //    Fast path (#117): when lastAiUpdatedContactId is provided and
  //    the contact was in previousList but dropped off the new list,
  //    emit a completed card directly — no interaction check needed.
  //    This is synchronous: the provider sets lastAiUpdatedContactId
  //    during AiUpdate.commit() before the new interaction reaches
  //    the snapshot listener.
  //
  //    Fallback path (#115): when lastAiUpdatedContactId is null,
  //    check for aiSuggested interactions after the cache time.
  //    Only one completed card per recomputation (fast path wins).
  final result = [...special, ...ranked];
  if (previousList != null) {
    // --- fast path (#117) ---
    if (lastAiUpdatedContactId != null) {
      final prevIndex = previousList.indexWhere(
        (r) =>
            r.contactId == lastAiUpdatedContactId && !r.isCompleted,
      );
      if (prevIndex >= 0) {
        final newContactIds = result.map((r) => r.contactId).toSet();
        if (!newContactIds.contains(lastAiUpdatedContactId)) {
          // #119: Differentiate the two completion scenarios:
          //   - MaintenanceNeed.none → relationship is healthy after the
          //     update; emit an affirmative "you're in a good place" card.
          //   - Still has a need but crowded out of top-3 → keep the
          //     generic "✓ Reached out" card.
          final contact = connections.firstWhere(
            (c) => c.id == lastAiUpdatedContactId,
            orElse: () => Connection(
              id: lastAiUpdatedContactId,
              name: lastAiUpdatedContactId,
              email: '',
              category: 'Friends',
              avatar: '👤',
              bondScore: 50,
              nextStep: '',
              lastContact: DateTime.now(),
              notes: '',
              knownSince: DateTime.now(),
              preferredChannels: const ['Text'],
            ),
          );
          final maintenanceResult = RelationshipMaintenancePolicy.evaluate(
            connection: contact,
            interactions: interactions,
            now: now,
          );
          final isHealthy =
              maintenanceResult.maintenanceNeed == MaintenanceNeed.none;
          final completed = isHealthy
              ? Recommendation(
                  contactId: lastAiUpdatedContactId,
                  reason: "You're in a good place with ${contact.name}.",
                  insight: 'This relationship looks healthy — keep it up.',
                  priority: 'completed',
                  isCompleted: true,
                  completedAt: now,
                )
              : Recommendation(
                  contactId: lastAiUpdatedContactId,
                  reason: '✓ Reached out to ${contact.name}',
                  insight: 'Just updated with AI',
                  priority: 'completed',
                  isCompleted: true,
                  completedAt: now,
                );

          final insertAt = prevIndex.clamp(0, result.length);
          final updated = <Recommendation>[...result];
          updated.insert(insertAt, completed);
          return updated.take(3).toList(growable: false);
        }
      }
      // Fast path didn't fire (contact still in list, or not in
      // previousList). Fall through to fallback.
    }

    // --- fallback path (#115) ---
    if (previousCacheTime != null) {
      final newContactIds = result.map((r) => r.contactId).toSet();
      for (var i = 0; i < previousList.length; i++) {
        final prev = previousList[i];
        if (prev.isCompleted) continue; // Already a completed card — skip
        if (newContactIds.contains(prev.contactId)) continue; // Still in top 3
        // Check for a new AI-suggested interaction after the cache time
        final hasNewAiInteraction = interactions.any(
          (ix) =>
              ix.contactId == prev.contactId &&
              ix.source == InteractionSource.aiSuggested &&
              (ix.date.isAfter(previousCacheTime) ||
                  ix.date == previousCacheTime),
        );
        if (!hasNewAiInteraction) continue;
        // Build a completed card at the original slot position
        final contact = connections.firstWhere(
          (c) => c.id == prev.contactId,
          orElse: () => Connection(
            id: prev.contactId,
            name: prev.contactId,
            email: '',
            category: 'Friends',
            avatar: '👤',
            bondScore: 50,
            nextStep: '',
            lastContact: DateTime.now(),
            notes: '',
            knownSince: DateTime.now(),
            preferredChannels: const ['Text'],
          ),
        );
        final completed = Recommendation(
          contactId: prev.contactId,
          reason: '✓ Reached out to ${contact.name}',
          insight: 'Just updated with AI',
          priority: 'completed',
          isCompleted: true,
          completedAt: now,
        );
        // Insert at the original slot position, clamping to result length
        final insertAt = i.clamp(0, result.length);
        final updated = <Recommendation>[...result];
        updated.insert(insertAt, completed);
        // Cap at 3 total
        return updated.take(3).toList(growable: false);
      }
    }
  }
  return result.take(3).toList(growable: false);
}

int _compareScored(_Scored a, _Scored b) {
  final need = _needRank(b.need).compareTo(_needRank(a.need));
  if (need != 0) return need;
  final topic = b.topic.qualityRank.compareTo(a.topic.qualityRank);
  if (topic != 0) return topic;
  final ratio = b.ratio.compareTo(a.ratio);
  if (ratio != 0) return ratio;
  return a.connection.id.compareTo(b.connection.id);
}

int _needRank(MaintenanceNeed need) => switch (need) {
  MaintenanceNeed.high => 3,
  MaintenanceNeed.medium => 2,
  MaintenanceNeed.low => 1,
  MaintenanceNeed.none => 0,
};

class _Scored {
  const _Scored({
    required this.connection,
    required this.tier,
    required this.need,
    required this.daysSince,
    required this.ratio,
    required this.topic,
  });

  final Connection connection;
  final BondTier tier;
  final MaintenanceNeed need;
  final int daysSince;
  final double ratio;
  final _TopicRecommendation topic;
}

Recommendation _toRecommendation(_Scored s) {
  final bucket = _recencyBucket(s.daysSince);
  final topic = s.topic;
  if (topic.isEligible) {
    return Recommendation(
      contactId: s.connection.id,
      reason: '${s.connection.name} has ${topic.topic} on their mind.',
      insight: 'A recent update mentioned ${topic.topic}.',
      priority: _priorityFor(s.need),
      topic: topic.topic,
      action: topic.action,
    );
  }
  return Recommendation(
    contactId: s.connection.id,
    reason: _reasonFor(s.tier, s.connection.name),
    insight: _insightFor(s.tier, bucket),
    priority: _priorityFor(s.need),
  );
}

class _TopicRecommendation {
  const _TopicRecommendation({
    required this.topic,
    required this.action,
    required this.qualityRank,
  });

  static const none = _TopicRecommendation(
    topic: '',
    action: '',
    qualityRank: 0,
  );

  final String topic;
  final String action;
  final int qualityRank;

  bool get isEligible => qualityRank > 0;
}

_TopicRecommendation _eligibleTopicSuggestion({
  required MemoryDocument? memory,
  required DateTime now,
}) {
  if (memory == null) return _TopicRecommendation.none;
  _TopicRecommendation best = _TopicRecommendation.none;
  for (final group in memory.topicSuggestions) {
    final topic = group.topic.trim();
    if (topic.isEmpty) continue;
    if (_isExpired(group.expiresAt, now)) continue;
    final action = _firstPreparedSuggestion(group);
    if (action == null) continue;
    final qualityRank = _topicQualityRank(group, memory, now);
    if (qualityRank > best.qualityRank) {
      best = _TopicRecommendation(
        topic: topic,
        action: action,
        qualityRank: qualityRank,
      );
    }
  }
  return best;
}

String? _firstPreparedSuggestion(TopicSuggestionGroup group) {
  for (final suggestion in group.suggestions) {
    final text = suggestion.text.trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int _topicQualityRank(
  TopicSuggestionGroup group,
  MemoryDocument memory,
  DateTime now,
) {
  var rank = 0;
  if (_hasUpcomingTie(group.topic, memory, now)) rank = 3;
  if (_isRecent(group.lastMentionedAt, now)) rank = rank < 2 ? 2 : rank;
  if (group.mentionCount >= 2) rank = rank < 1 ? 1 : rank;
  return rank;
}

bool _isExpired(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return false;
  return _day(expiresAt).isBefore(_day(now));
}

bool _isRecent(DateTime? lastMentionedAt, DateTime now) {
  if (lastMentionedAt == null) return false;
  final elapsed = _day(now).difference(_day(lastMentionedAt));
  return !elapsed.isNegative && elapsed <= const Duration(days: 30);
}

bool _hasUpcomingTie(String topic, MemoryDocument memory, DateTime now) {
  final normalizedTopic = topic.trim().toLowerCase();
  if (normalizedTopic.isEmpty) return false;
  for (final entry in memory.upcoming) {
    final effective = entry.endDate ?? entry.startDate;
    if (_day(effective).isBefore(_day(now))) continue;
    final description = entry.description.toLowerCase();
    if (description.contains(normalizedTopic) ||
        normalizedTopic.contains(description)) {
      return true;
    }
  }
  return false;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

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

/// Priority field is filled deterministically from Maintenance Need so
/// the existing UI keeps receiving stable priority strings.
String _priorityFor(MaintenanceNeed need) => switch (need) {
  MaintenanceNeed.high => 'high priority',
  MaintenanceNeed.medium => 'medium priority',
  MaintenanceNeed.low => 'low priority',
  MaintenanceNeed.none => 'low priority',
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
