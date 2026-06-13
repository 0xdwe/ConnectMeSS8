"use strict";

function localDateParts(now, timeZone) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const parts = Object.fromEntries(
    formatter.formatToParts(now)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );
  return {
    dateKey: `${parts.year}-${parts.month}-${parts.day}`,
    hour: Number(parts.hour),
    minute: Number(parts.minute),
  };
}

function isQuietMinute(minute, start, end) {
  if (start === end) return false;
  return start > end
    ? minute >= start || minute < end
    : minute >= start && minute < end;
}

function shouldDeliverNow(preferences, now) {
  let local;
  try {
    local = localDateParts(now, preferences.timeZone);
  } catch (_) {
    return false;
  }
  const nineAm = 9 * 60;
  const deliveryMinute = preferences.quietHoursEnabled &&
      isQuietMinute(
        nineAm,
        preferences.quietStartMinutes,
        preferences.quietEndMinutes,
      )
    ? preferences.quietEndMinutes
    : nineAm;
  const currentMinute = local.hour * 60 + local.minute;
  return currentMinute >= deliveryMinute &&
    currentMinute < deliveryMinute + 60;
}

function dailyDeliveryId(now, timeZone) {
  return `suggested-check-in-${localDateParts(now, timeZone).dateKey}`;
}

function buildNotificationCopy(connection) {
  return {
    title: "A gentle check-in",
    body: `${connection.name} could use a check-in.`,
  };
}

function isInvalidTokenError(code) {
  return code === "messaging/invalid-registration-token" ||
    code === "messaging/registration-token-not-registered";
}

module.exports = {
  buildNotificationCopy,
  dailyDeliveryId,
  isInvalidTokenError,
  isQuietMinute,
  localDateParts,
  shouldDeliverNow,
};
