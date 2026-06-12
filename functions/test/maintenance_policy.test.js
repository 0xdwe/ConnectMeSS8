"use strict";

const {
  adjustedCadenceDays,
  chooseSuggestedConnection,
  maintenanceNeedForRatio,
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
