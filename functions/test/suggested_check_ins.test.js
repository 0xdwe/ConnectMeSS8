"use strict";

const {
  buildNotificationCopy,
  dailyDeliveryId,
  isInvalidTokenError,
  isQuietMinute,
  shouldDeliverNow,
} = require("../suggested_check_ins");

test("quiet-hour checks support ranges that span midnight", () => {
  expect(isQuietMinute(23 * 60, 22 * 60, 8 * 60)).toBe(true);
  expect(isQuietMinute(7 * 60, 22 * 60, 8 * 60)).toBe(true);
  expect(isQuietMinute(12 * 60, 22 * 60, 8 * 60)).toBe(false);
});

test("delivers only at 9 AM local time and outside quiet hours", () => {
  const preferences = {
    timeZone: "Asia/Taipei",
    quietHoursEnabled: false,
    quietStartMinutes: 22 * 60,
    quietEndMinutes: 8 * 60,
  };
  expect(
    shouldDeliverNow(preferences, new Date("2026-06-12T01:00:00Z")),
  ).toBe(true);
  expect(
    shouldDeliverNow(preferences, new Date("2026-06-12T02:00:00Z")),
  ).toBe(false);
});

test("defers a 9 AM delivery until quiet hours end", () => {
  const preferences = {
    timeZone: "Asia/Taipei",
    quietHoursEnabled: true,
    quietStartMinutes: 8 * 60,
    quietEndMinutes: 10 * 60 + 30,
  };
  expect(
    shouldDeliverNow(preferences, new Date("2026-06-12T01:00:00Z")),
  ).toBe(false);
  expect(
    shouldDeliverNow(preferences, new Date("2026-06-12T03:00:00Z")),
  ).toBe(true);
});

test("daily delivery IDs follow the user's local date", () => {
  expect(
    dailyDeliveryId(
      new Date("2026-06-11T17:00:00Z"),
      "Asia/Taipei",
    ),
  ).toBe("suggested-check-in-2026-06-12");
});

test("copy stays gentle and contains no elapsed day count", () => {
  expect(buildNotificationCopy({name: "Mike"})).toEqual({
    title: "A gentle check-in",
    body: "Mike could use a check-in.",
  });
});

test("recognizes FCM errors that require token cleanup", () => {
  expect(isInvalidTokenError(
    "messaging/registration-token-not-registered",
  )).toBe(true);
  expect(isInvalidTokenError("messaging/internal-error")).toBe(false);
});
