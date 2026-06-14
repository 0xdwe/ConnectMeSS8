import '../models/social_models.dart';

enum BondDurabilityTier { close, steady, drifting }

enum MaintenanceNeed { none, low, medium, high }

enum MaintenanceReason {
  withinRhythm,
  approachingRhythm,
  outsideRhythm,
  farOutsideRhythm,
}

enum BondDriftReason {
  withinDriftGrace,
  clearlyOutsideRhythm,
  farOutsideRhythm,
  veryFarOutsideRhythm,
}

class RelationshipMaintenanceResult {
  const RelationshipMaintenanceResult({
    required this.bondTier,
    required this.adjustedCadence,
    required this.latestTouchAt,
    required this.maintenanceNeed,
    required this.maintenanceReason,
    required this.candidateBondDrift,
    required this.driftReason,
    required this.isBondDriftApplicationEligible,
  });

  final BondDurabilityTier bondTier;
  final Duration adjustedCadence;
  final DateTime latestTouchAt;
  final MaintenanceNeed maintenanceNeed;
  final MaintenanceReason maintenanceReason;
  final int candidateBondDrift;
  final BondDriftReason driftReason;
  final bool isBondDriftApplicationEligible;
}

class RelationshipMaintenancePolicy {
  const RelationshipMaintenancePolicy._();

  static RelationshipMaintenanceResult evaluate({
    required Connection connection,
    required Iterable<CrmInteraction> interactions,
    required DateTime now,
  }) {
    final tier = _tierFor(connection.bondScore);
    final baseCadenceDays = _baseCadenceDaysFor(connection.category);
    final adjustedCadenceDays = (baseCadenceDays * _multiplierFor(tier))
        .round();
    final adjustedCadence = Duration(days: adjustedCadenceDays);
    final latestTouchAt = _latestTouchAt(connection, interactions);
    final ratio =
        now.difference(latestTouchAt).inMilliseconds /
        adjustedCadence.inMilliseconds;
    final maintenanceNeed = _maintenanceNeedFor(ratio);
    final baseDrift = _baseDriftFor(ratio);
    final cappedDrift = _capDrift(
      baseDrift: baseDrift,
      tier: tier,
      category: connection.category,
    );
    final clampedDrift = cappedDrift < -connection.bondScore
        ? -connection.bondScore
        : cappedDrift;

    return RelationshipMaintenanceResult(
      bondTier: tier,
      adjustedCadence: adjustedCadence,
      latestTouchAt: latestTouchAt,
      maintenanceNeed: maintenanceNeed,
      maintenanceReason: _maintenanceReasonFor(maintenanceNeed),
      candidateBondDrift: clampedDrift,
      driftReason: _driftReasonFor(baseDrift),
      isBondDriftApplicationEligible: _isEligible(
        connection.lastBondDriftAppliedAt,
        now,
      ),
    );
  }

  static int _baseCadenceDaysFor(String category) {
    return switch (category) {
      'Family' => 14,
      'Friends' => 21,
      'Work' => 30,
      'College' => 45,
      'High School' => 45,
      _ => 21,
    };
  }

  static BondDurabilityTier _tierFor(int bondScore) {
    if (bondScore >= 80) return BondDurabilityTier.close;
    if (bondScore >= 50) return BondDurabilityTier.steady;
    return BondDurabilityTier.drifting;
  }

  static double _multiplierFor(BondDurabilityTier tier) {
    return switch (tier) {
      BondDurabilityTier.close => 1.5,
      BondDurabilityTier.steady => 1.0,
      BondDurabilityTier.drifting => 0.75,
    };
  }

  static DateTime _latestTouchAt(
    Connection connection,
    Iterable<CrmInteraction> interactions,
  ) {
    var latest = connection.lastContact;
    for (final interaction in interactions) {
      if (interaction.contactId != connection.id) continue;
      if (interaction.date.isAfter(latest)) latest = interaction.date;
    }
    return latest;
  }

  static MaintenanceNeed _maintenanceNeedFor(double ratio) {
    if (ratio < 0.75) return MaintenanceNeed.none;
    if (ratio < 1.0) return MaintenanceNeed.low;
    if (ratio <= 1.5) return MaintenanceNeed.medium;
    return MaintenanceNeed.high;
  }

  static MaintenanceReason _maintenanceReasonFor(MaintenanceNeed need) {
    return switch (need) {
      MaintenanceNeed.none => MaintenanceReason.withinRhythm,
      MaintenanceNeed.low => MaintenanceReason.approachingRhythm,
      MaintenanceNeed.medium => MaintenanceReason.outsideRhythm,
      MaintenanceNeed.high => MaintenanceReason.farOutsideRhythm,
    };
  }

  static int _baseDriftFor(double ratio) {
    // Drift starts as soon as a contact is overdue (ratio >= 1.0).
    // Demo-tuned: faster decay so the system feels alive during demos.
    if (ratio < 1.0) return 0;
    if (ratio < 1.5) return -3;
    if (ratio <= 2.5) return -5;
    return -8;
  }

  static BondDriftReason _driftReasonFor(int drift) {
    return switch (drift) {
      0 => BondDriftReason.withinDriftGrace,
      -3 => BondDriftReason.clearlyOutsideRhythm,
      -5 => BondDriftReason.farOutsideRhythm,
      _ => BondDriftReason.veryFarOutsideRhythm,
    };
  }

  static int _capDrift({
    required int baseDrift,
    required BondDurabilityTier tier,
    required String category,
  }) {
    final tierCap = switch (tier) {
      BondDurabilityTier.close => -3,
      BondDurabilityTier.steady => -5,
      BondDurabilityTier.drifting => -8,
    };
    // Work contacts are capped at −2 to reflect professional distance
    // being more naturally maintained without regular touch.
    final cap = category == 'Work' && tierCap < -2 ? -2 : tierCap;
    return baseDrift < cap ? cap : baseDrift;
  }

  static bool _isEligible(DateTime? lastAppliedAt, DateTime now) {
    if (lastAppliedAt == null) return true;
    // 3-day window (demo-tuned from 7) so drift is visible quickly.
    return now.difference(lastAppliedAt) >= const Duration(days: 3);
  }
}
