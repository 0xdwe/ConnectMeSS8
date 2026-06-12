"use strict";

const CADENCE_DAYS = {
  Family: 14,
  Friends: 21,
  Work: 30,
  College: 45,
  "High School": 45,
};

function bondMultiplier(score) {
  if (score >= 80) return 1.5;
  if (score >= 50) return 1.0;
  return 0.75;
}

function adjustedCadenceDays(connection) {
  const base = CADENCE_DAYS[connection.category] ?? 21;
  return Math.round(base * bondMultiplier(connection.bondScore));
}

function timestampMillis(value) {
  if (value == null) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  return 0;
}

function latestTouchMillis(connection, interactions) {
  let latest = timestampMillis(connection.lastContact);
  for (const interaction of interactions) {
    if (interaction.contactId !== connection.id) continue;
    latest = Math.max(latest, timestampMillis(interaction.date));
  }
  return latest;
}

function maintenanceRatio(connection, interactions, nowMillis) {
  const cadenceMillis =
    adjustedCadenceDays(connection) * 24 * 60 * 60 * 1000;
  return (nowMillis - latestTouchMillis(connection, interactions)) /
    cadenceMillis;
}

function maintenanceNeedForRatio(ratio) {
  if (ratio < 0.75) return "none";
  if (ratio < 1.0) return "low";
  if (ratio <= 1.5) return "medium";
  return "high";
}

function chooseSuggestedConnection(connections, interactions, nowMillis) {
  return connections
    .map((connection) => {
      const ratio = maintenanceRatio(connection, interactions, nowMillis);
      return {
        connection,
        ratio,
        need: maintenanceNeedForRatio(ratio),
      };
    })
    .filter((candidate) => candidate.need !== "none")
    .sort((a, b) => {
      const severity = {low: 1, medium: 2, high: 3};
      return severity[b.need] - severity[a.need] ||
        b.ratio - a.ratio ||
        a.connection.id.localeCompare(b.connection.id);
    })[0]?.connection ?? null;
}

module.exports = {
  adjustedCadenceDays,
  chooseSuggestedConnection,
  latestTouchMillis,
  maintenanceNeedForRatio,
  maintenanceRatio,
};
