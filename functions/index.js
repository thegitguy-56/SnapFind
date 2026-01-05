const {setGlobalOptions} = require("firebase-functions/v2/options");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

setGlobalOptions({maxInstances: 10});

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Helper: get all FCM tokens for a user.
 * @param {string} userId
 * @return {Promise<string[]>}
 */
async function getUserTokens(userId) {
  const tokensSnap = await db
      .collection("users")
      .doc(userId)
      .collection("tokens")
      .get();

  if (tokensSnap.empty) return [];
  return tokensSnap.docs.map((doc) => doc.id);
}

/**
 * Trigger: when a new alert is created, notify the finder.
 * alerts/{alertId}
 */
exports.onAlertCreated = onDocumentCreated(
    "alerts/{alertId}",
    async (event) => {
      const alertData = event.data.data();
      const finderId = alertData.finderId;
      const itemId = alertData.itemId;

      if (!finderId || !itemId) {
        console.log("Missing finderId or itemId in alert");
        return;
      }

      const tokens = await getUserTokens(finderId);
      if (tokens.length === 0) {
        console.log("No tokens for finder", finderId);
        return;
      }

      const payload = {
        notification: {
          title: "New alert on your found item",
          body: `Someone says they are looking for item ${itemId}`,
        },
        data: {
          type: "alert",
          itemId: itemId,
        },
      };

      await messaging.sendToDevice(tokens, payload);
      console.log("Sent alert notification to finder", finderId);
    },
);

/**
 * Trigger: when a new chat message is created, notify the other user.
 * chats/{chatId}/messages/{messageId}
 */
exports.onChatMessageCreated = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const messageData = event.data.data();
      const chatId = event.params.chatId;

      const senderRole = messageData.senderRole;
      const text = messageData.text || "You have a new message";

      if (!senderRole) {
        console.log("Missing senderRole in message");
        return;
      }

      const chatSnap = await db.collection("chats").doc(chatId).get();
      if (!chatSnap.exists) {
        console.log("Chat not found for id", chatId);
        return;
      }
      const chat = chatSnap.data();
      const finderId = chat.finderId;
      const seekerId = chat.seekerId;

      if (!finderId || !seekerId) {
        console.log("Missing finderId or seekerId in chat");
        return;
      }

      // Determine receiver based on senderRole
      const receiverId = senderRole === "finder" ? seekerId : finderId;

      const tokens = await getUserTokens(receiverId);
      if (tokens.length === 0) {
        console.log("No tokens for receiver", receiverId);
        return;
      }

      const payload = {
        notification: {
          title: "New message in SnapFind",
          body: text,
        },
        data: {
          type: "chat",
          chatId: chatId,
        },
      };

      await messaging.sendToDevice(tokens, payload);
      console.log("Sent chat notification to", receiverId);
    },
);
