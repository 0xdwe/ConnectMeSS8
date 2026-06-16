"use strict";

const { runScheduledBondDrift } = require("../index");

// Mock firebase-admin dependencies
jest.mock("firebase-admin/app", () => ({
  initializeApp: jest.fn(),
}));

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn(),
  FieldValue: {
    serverTimestamp: jest.fn(() => "mock-timestamp"),
  },
}));

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: jest.fn(),
}));

jest.mock("firebase-functions/v2/scheduler", () => ({
  onSchedule: jest.fn((options, handler) => handler),
}));

jest.mock("firebase-functions", () => ({
  logger: {
    info: jest.fn(),
    error: jest.fn(),
  },
}));

test("runScheduledBondDrift scans users and updates eligible connection scores", async () => {
  const day = 24 * 60 * 60 * 1000;
  const now = Date.parse("2026-06-12T00:00:00Z");

  const mockBatchUpdate = jest.fn();
  const mockBatchCommit = jest.fn();

  const mockFirestore = {
    collection: jest.fn(() => ({
      get: jest.fn(async () => ({
        docs: [
          {
            id: "user_1",
            ref: {
              collection: jest.fn((name) => {
                if (name === "connections") {
                  return {
                    get: jest.fn(async () => ({
                      docs: [
                        {
                          id: "contact_1",
                          ref: "mock-conn-ref-1",
                          data: () => ({
                            category: "Friends",
                            bondScore: 80,
                            lastContact: now - 35 * day, // Way overdue
                            lastBondDriftAppliedAt: now - 4 * day, // Eligible
                          }),
                        },
                        {
                          id: "contact_2",
                          ref: "mock-conn-ref-2",
                          data: () => ({
                            category: "Friends",
                            bondScore: 80,
                            lastContact: now - 1 * day, // Not overdue
                            lastBondDriftAppliedAt: now - 4 * day,
                          }),
                        },
                      ],
                    })),
                  };
                }
                if (name === "interactions") {
                  return {
                    get: jest.fn(async () => ({
                      docs: [],
                    })),
                  };
                }
              }),
            },
          },
        ],
      })),
    })),
    batch: jest.fn(() => ({
      update: mockBatchUpdate,
      commit: mockBatchCommit,
    })),
  };

  const updatedCount = await runScheduledBondDrift(mockFirestore, now);
  expect(updatedCount).toBe(1);

  expect(mockBatchUpdate).toHaveBeenCalledTimes(1);
  expect(mockBatchUpdate).toHaveBeenCalledWith("mock-conn-ref-1", {
    bondScore: 77, // Close tier cap is -3. 80 - 3 = 77
    lastBondDriftAppliedAt: "mock-timestamp",
  });
  expect(mockBatchCommit).toHaveBeenCalledTimes(1);
});
