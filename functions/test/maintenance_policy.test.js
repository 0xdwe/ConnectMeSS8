"use strict";

const {
  adjustedCadenceDays,
  chooseSuggestedConnection,
  maintenanceNeedForRatio,
  bondTier,
  baseDriftFor,
  capDrift,
  isBondDriftEligible,
  evaluateRelationshipMaintenance,
} = require("../maintenance_policy");

test("mirrors the shipped cadence and Bond Score durability constants", () => {
  expect(adjustedCadenceDays({category: "Family", bondScore: 90})).toBe(21);
  expect(adjustedCadenceDays({category: "Work", bondScore: 60})).toBe(30);
  expect(adjustedCadenceDays({category: "Friends", bondScore: 40})).toBe(16);
});

test("mirrors Maintenance Need boundaries", () => {
  expect(maintenanceNeedForRatio(0.74)).toBe("none");
  expect(maintenanceNeedForRatio(0.75)).toBe("low");
  expect(maintenanceNeedForRatio(1.0)).toBe("medium");
  expect(maintenanceNeedForRatio(1.5)).toBe("medium");
  expect(maintenanceNeedForRatio(1.51)).toBe("high");
});

test("selects the highest-need connection without numeric shame copy", () => {
  const day = 24 * 60 * 60 * 1000;
  const now = Date.parse("2026-06-12T00:00:00Z");
  const connections = [
    {
      id: "recent",
      name: "Recent",
      category: "Friends",
      bondScore: 60,
      lastContact: now - 5 * day,
    },
    {
      id: "due",
      name: "Due",
      category: "Friends",
      bondScore: 60,
      lastContact: now - 40 * day,
    },
  ];

  expect(chooseSuggestedConnection(connections, [], now).id).toBe("due");
});

test("maps bondScore to correct bondTier", () => {
  expect(bondTier(90)).toBe("close");
  expect(bondTier(80)).toBe("close");
  expect(bondTier(79)).toBe("steady");
  expect(bondTier(50)).toBe("steady");
  expect(bondTier(49)).toBe("drifting");
  expect(bondTier(0)).toBe("drifting");
});

test("calculates correct baseDriftFor ratio", () => {
  expect(baseDriftFor(0.99)).toBe(0);
  expect(baseDriftFor(1.0)).toBe(-3);
  expect(baseDriftFor(1.49)).toBe(-3);
  expect(baseDriftFor(1.5)).toBe(-5);
  expect(baseDriftFor(2.5)).toBe(-5);
  expect(baseDriftFor(2.61)).toBe(-8);
});

test("caps drift according to tier and Work category rule", () => {
  // close tier cap is -3
  expect(capDrift(-8, "close", "Friends")).toBe(-3);
  // steady tier cap is -5
  expect(capDrift(-8, "steady", "Friends")).toBe(-5);
  // drifting tier cap is -8
  expect(capDrift(-8, "drifting", "Friends")).toBe(-8);

  // Work category cap is -2 if tierCap < -2
  expect(capDrift(-5, "close", "Work")).toBe(-2);
  expect(capDrift(-5, "steady", "Work")).toBe(-2);
  expect(capDrift(-5, "drifting", "Work")).toBe(-2);

  // If baseDrift is less severe than the cap, keep it
  expect(capDrift(-1, "close", "Friends")).toBe(-1);
});

test("checks bond drift eligibility window", () => {
  const day = 24 * 60 * 60 * 1000;
  const now = 1000 * day;
  expect(isBondDriftEligible(null, now)).toBe(true);
  expect(isBondDriftEligible(0, now)).toBe(true);
  expect(isBondDriftEligible(now - 2 * day, now)).toBe(false);
  expect(isBondDriftEligible(now - 3 * day, now)).toBe(true);
  expect(isBondDriftEligible(now - 4 * day, now)).toBe(true);
});

test("evaluates relationship maintenance and applies clamping", () => {
  const day = 24 * 60 * 60 * 1000;
  const now = Date.parse("2026-06-12T00:00:00Z");

  const connection = {
    id: "contact_1",
    category: "Friends",
    bondScore: 50,
    lastContact: now - 35 * day, // High ratio
    lastBondDriftAppliedAt: now - 4 * day, // Eligible
  };

  const evalResult = evaluateRelationshipMaintenance(connection, [], now);
  expect(evalResult.bondTier).toBe("steady");
  expect(evalResult.maintenanceNeed).toBe("high");
  // Steady cap is -5, ratio is high, baseDrift is -8, capped is -5
  expect(evalResult.candidateBondDrift).toBe(-5);
  expect(evalResult.isBondDriftApplicationEligible).toBe(true);

  // Clamping check: if bondScore is 3, candidate drift -5 should clamp to -3
  const lowScoreConnection = {
    ...connection,
    bondScore: 3,
  };
  const clampedResult = evaluateRelationshipMaintenance(lowScoreConnection, [], now);
  expect(clampedResult.candidateBondDrift).toBe(-3);
});

