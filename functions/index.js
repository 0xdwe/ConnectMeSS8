"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");

const {chooseSuggestedConnection} = require("./maintenance_policy");
const {
  buildNotificationCopy,
  dailyDeliveryId,
  isInvalidTokenError,
  shouldDeliverNow,
} = require("./suggested_check_ins");

initializeApp();

exports.sendSuggestedCheckIns = onSchedule(
  {
    schedule: "0 * * * *",
    region: "us-central1",
    timeZone: "UTC",
    retryCount: 0,
  },
  async () => {
    const firestore = getFirestore();
    const messaging = getMessaging();
    const now = new Date();
    const users = await firestore.collection("users").get();

    for (const userDoc of users.docs) {
      const preferences = userDoc.get("notificationPreferences");
      if (!preferences?.enabled || !preferences?.suggestedCheckIns) continue;
      if (!shouldDeliverNow(preferences, now)) continue;

      const tokensSnapshot = await userDoc.ref
        .collection("notificationTokens")
        .get();
      if (tokensSnapshot.empty) continue;

      const [connectionsSnapshot, interactionsSnapshot] = await Promise.all([
        userDoc.ref.collection("connections").get(),
        userDoc.ref.collection("interactions").get(),
      ]);
      const connections = connectionsSnapshot.docs.map((doc) => doc.data());
      const interactions = interactionsSnapshot.docs.map((doc) => doc.data());
      const connection = chooseSuggestedConnection(
        connections,
        interactions,
        now.getTime(),
      );
      if (connection == null) continue;

      const deliveryRef = userDoc.ref
        .collection("notificationDeliveries")
        .doc(dailyDeliveryId(now, preferences.timeZone));
      const claimed = await firestore.runTransaction(async (transaction) => {
        const existing = await transaction.get(deliveryRef);
        if (existing.exists) return false;
        transaction.create(deliveryRef, {
          status: "pending",
          contactId: connection.id,
          createdAt: FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!claimed) continue;

      const tokenDocs = tokensSnapshot.docs;
      const notification = buildNotificationCopy(connection);
      try {
        const response = await messaging.sendEachForMulticast({
          tokens: tokenDocs.map((doc) => doc.get("token")),
          notification,
          data: {
            kind: "suggestedCheckIn",
            contactId: connection.id,
          },
        });
        const invalidDeletes = [];
        response.responses.forEach((result, index) => {
          if (!result.success &&
              isInvalidTokenError(result.error?.code)) {
            invalidDeletes.push(tokenDocs[index].ref.delete());
          }
        });
        await Promise.all(invalidDeletes);
        await deliveryRef.update({
          status: "sent",
          successCount: response.successCount,
          failureCount: response.failureCount,
          sentAt: FieldValue.serverTimestamp(),
        });
      } catch (error) {
        await deliveryRef.delete();
        logger.error("Suggested check-in delivery failed", {
          uid: userDoc.id,
          error,
        });
      }
    }
  },
);
