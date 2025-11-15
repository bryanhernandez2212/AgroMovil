/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

// Configurar opciones globales para funciones v2
setGlobalOptions({maxInstances: 10});

exports.notifyNewMessage = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const message = event.data.data();
    const chatId = event.params.chatId;

    const chatDoc = await admin.firestore()
      .collection("chats")
      .doc(chatId)
      .get();
    if (!chatDoc.exists) return;

    const chat = chatDoc.data();
    const senderId = message.senderId;
    const participants = chat.participants || [];
    const targets = participants.filter((uid) => uid !== senderId);
    if (!targets.length) return;

    const users = await admin.firestore()
      .collection("usuarios")
      .where(admin.firestore.FieldPath.documentId(), "in", targets)
      .get();

    const tokens = [];
    users.forEach((doc) => {
      const tokenList = doc.data().fcmTokens || [];
      tokens.push(...tokenList);
    });
    if (!tokens.length) return;

    const senderData = chat.participantsData?.[senderId] || {};
    const title = senderData.nombre || "Nuevo mensaje";
    const body = message.type === "image"
      ? "📷 Imagen"
      : (message.text || "Tienes un nuevo mensaje");

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        chatId,
        orderId: chat.metadata?.orderId || "",
        senderId,
      },
    });
  }
);
