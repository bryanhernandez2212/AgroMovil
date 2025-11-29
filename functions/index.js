/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
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
        type: "chat",
        chatId,
        orderId: chat.metadata?.orderId || "",
        senderId,
      },
    });
  }
);

// Notificar SOLO al comprador cuando cambie el estado del pedido
exports.notifyOrderStatusChange = onDocumentUpdated(
  {
    document: "compras/{orderId}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const orderId = event.params.orderId;

    // Estados válidos a notificar
    // Usar minúsculas para tolerancia de formato
    const VALID_STATES = new Set(["preparando", "enviado", "recibido", "devolucion"]);

    // Helper para mensaje por estado
    function statusMessage(statusRaw) {
      const s = (statusRaw || "").toString().trim().toLowerCase();
      switch (s) {
        case "preparando": return "Tu pedido está siendo preparado.";
        case "enviado": return "Tu pedido fue enviado.";
        case "recibido": return "Confirmamos que recibiste tu pedido.";
        case "devolucion": return "Tu pedido está en proceso de devolución.";
        default: return `Estado actualizado a ${s.toUpperCase()}`;
      }
    }

    // 1) Cambio global de estado
    const prevGlobal = (before.estado_pedido || before.estado || "")
      .toString()
      .trim()
      .toLowerCase();
    const currGlobal = (after.estado_pedido || after.estado || "")
      .toString()
      .trim()
      .toLowerCase();
    const buyerId = after.usuario_id || after.usuarioId;

    const messages = [];

    if (buyerId && currGlobal && currGlobal !== prevGlobal && VALID_STATES.has(currGlobal)) {
      const tokens = await getUserTokens(buyerId);
      if (tokens.length) {
        messages.push({
          tokens,
          notification: {
            title: "Actualización de pedido",
            body: statusMessage(currGlobal),
          },
          data: {
            type: "order_status",
            orderId,
            newStatus: currGlobal,
          },
        });
      }
    }

    // 2) (Eliminado) Notificaciones por producto: solo conservamos la global de pedido

    if (!messages.length) return;
    await Promise.all(messages.map((m) => admin.messaging().sendEachForMulticast(m)));
  }
);

async function getUserTokens(uid) {
  try {
    const snap = await admin.firestore().collection("usuarios").doc(uid).get();
    const data = snap.data() || {};
    // Admitir tokens como arreglo o como mapa {token:true}
    if (Array.isArray(data.fcmTokens)) {
      return data.fcmTokens.filter(Boolean);
    }
    if (data.fcmTokens && typeof data.fcmTokens === "object") {
      return Object.keys(data.fcmTokens).filter(Boolean);
    }
    return [];
  } catch {
    return [];
  }
}
