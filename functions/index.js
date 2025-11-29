/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onCall} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
admin.initializeApp();

// Configurar opciones globales para funciones v2
setGlobalOptions({maxInstances: 10});

// Configurar transporter de email usando SMTP
// Para Firebase Functions v2, los secrets se pasan como parámetros a la función
function getEmailTransporter(smtpSecrets) {
  if (!smtpSecrets) {
    console.warn("⚠️ SMTP secrets no disponibles");
    return null;
  }

  const smtpHost = (smtpSecrets.SMTP_HOST || process.env.SMTP_HOST || "smtp.gmail.com").trim();
  const smtpPort = parseInt((smtpSecrets.SMTP_PORT || process.env.SMTP_PORT || "587").trim());
  const smtpUser = (smtpSecrets.SMTP_USER || process.env.SMTP_USER || "").trim();
  const smtpPass = (smtpSecrets.SMTP_PASS || process.env.SMTP_PASS || "").trim();
  const smtpSecure = ((smtpSecrets.SMTP_SECURE || process.env.SMTP_SECURE || "false").trim()) === "true";
  
  console.log(`📧 Configurando SMTP con host: ${smtpHost}, port: ${smtpPort}, user: ${smtpUser ? "✅" : "❌"}`);

  if (!smtpUser || !smtpPass) {
    console.warn("⚠️ SMTP no configurado. Usuario o contraseña faltantes.");
    return null;
  }

  console.log(`📧 Configurando SMTP: ${smtpHost}:${smtpPort} con usuario ${smtpUser}`);
  console.log(`📋 Valores SMTP - Host: "${smtpHost}", Port: ${smtpPort}, Secure: ${smtpSecure}, User: "${smtpUser ? smtpUser.substring(0, 5) + '...' : 'NO'}"`);

  // Validar que el host no esté vacío y sea válido
  if (!smtpHost || smtpHost.trim() === "") {
    console.error("❌ SMTP_HOST está vacío o no es válido");
    return null;
  }

  try {
    return nodemailer.createTransport({
      host: smtpHost.trim(),
      port: smtpPort,
      secure: smtpSecure,
      auth: {
        user: smtpUser.trim(),
        pass: smtpPass.trim(),
      },
      connectionTimeout: 60000,
      greetingTimeout: 30000,
      socketTimeout: 60000,
      // Agregar opciones adicionales para mejorar la conexión
      tls: {
        rejectUnauthorized: false, // Para desarrollo, en producción debería ser true
      },
    });
  } catch (error) {
    console.error("❌ Error creando transporter:", error);
    return null;
  }
}

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

// Función para generar código de 6 dígitos
function generateResetCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Cloud Function para enviar código de 6 dígitos para recuperación de contraseña
// Esta función usa SMTP personalizado con correos HTML personalizados
exports.sendPasswordResetCode = onCall(
  {
    region: "us-central1",
    maxInstances: 10,
    cors: true,
    secrets: ["SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS", "SMTP_SECURE", "SMTP_FROM"],
  },
  async (request) => {
    const { email } = request.data;

    if (!email) {
      return {
        success: false,
        message: "El email es requerido",
      };
    }

    try {
      // Verificar que el usuario existe en Firebase Auth
      let userRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email);
      } catch (error) {
        if (error.code === "auth/user-not-found") {
          return {
            success: false,
            message: "No existe una cuenta con este email",
          };
        }
        throw error;
      }

      // Generar código de 6 dígitos
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date();
      expiresAt.setMinutes(expiresAt.getMinutes() + 15); // Expira en 15 minutos

      // Guardar código en Firestore
      const codeDoc = {
        email: email,
        code: code,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: expiresAt,
        used: false,
      };

      // Eliminar códigos anteriores para este email
      const existingCodes = await admin
        .firestore()
        .collection("passwordResetCodes")
        .where("email", "==", email)
        .where("used", "==", false)
        .get();

      const batch = admin.firestore().batch();
      existingCodes.forEach((doc) => {
        batch.update(doc.ref, { used: true });
      });
      await batch.commit();

      // Guardar nuevo código
      await admin.firestore().collection("passwordResetCodes").add(codeDoc);

      console.log(`📧 Generando email con código de recuperación para ${email}`);

      // Obtener secrets de SMTP
      const smtpSecrets = {
        SMTP_HOST: (process.env.SMTP_HOST || "").trim(),
        SMTP_PORT: (process.env.SMTP_PORT || "").trim(),
        SMTP_USER: (process.env.SMTP_USER || "").trim(),
        SMTP_PASS: (process.env.SMTP_PASS || "").trim(),
        SMTP_SECURE: (process.env.SMTP_SECURE || "").trim(),
        SMTP_FROM: (process.env.SMTP_FROM || "").trim(),
      };

      const transporter = getEmailTransporter(smtpSecrets);
      if (!transporter) {
        console.error("❌ SMTP no configurado. No se puede enviar código.");
        return {
          success: false,
          message: "Error de configuración: SMTP no está configurado. Por favor, contacta al soporte.",
        };
      }

      // Generar HTML del email
      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; 
              line-height: 1.6; 
              color: #333; 
              background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
              padding: 20px;
            }
            .container { 
              max-width: 600px; 
              margin: 0 auto; 
              background-color: #ffffff; 
              border-radius: 16px; 
              overflow: hidden; 
              box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            }
            .header { 
              background: linear-gradient(135deg, #2E7D32 0%, #1B5E20 100%);
              color: white; 
              padding: 40px 30px; 
              text-align: center;
            }
            .header h1 { 
              font-size: 32px; 
              margin-bottom: 8px;
              font-weight: 700;
            }
            .content { 
              padding: 40px 35px; 
            }
            .code-box {
              background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
              padding: 30px;
              border-radius: 12px;
              text-align: center;
              margin: 30px 0;
              border: 2px dashed #2E7D32;
            }
            .code {
              font-size: 48px;
              font-weight: 700;
              color: #2E7D32;
              letter-spacing: 8px;
              font-family: 'Courier New', monospace;
            }
            .warning {
              background: #fff3cd;
              border-left: 4px solid #ffc107;
              padding: 15px;
              border-radius: 8px;
              margin: 20px 0;
              color: #856404;
            }
            .footer { 
              background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
              padding: 30px; 
              text-align: center; 
              border-top: 1px solid #e9ecef;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🌾 AgroMarket</h1>
              <h2>Recuperación de Contraseña</h2>
            </div>
            <div class="content">
              <p style="font-size: 18px; margin-bottom: 8px; color: #2E7D32;">
                <strong>Hola,</strong>
              </p>
              <p style="color: #666; margin-bottom: 20px; font-size: 15px;">
                Has solicitado restablecer tu contraseña. Usa el siguiente código de verificación:
              </p>
              
              <div class="code-box">
                <p style="color: #666; margin-bottom: 15px; font-size: 14px;">Tu código de verificación es:</p>
                <div class="code">${code}</div>
              </div>

              <div class="warning">
                <strong>⚠️ Importante:</strong> Este código expirará en 15 minutos. No compartas este código con nadie.
              </div>

              <p style="color: #666; margin-top: 30px; font-size: 15px;">
                Si no solicitaste este código, puedes ignorar este correo de forma segura.
              </p>
            </div>
            <div class="footer">
              <p style="font-weight: 600; color: #2E7D32; margin-bottom: 10px;">
                Saludos,<br>El equipo de AgroMarket
              </p>
              <p style="font-size: 12px; color: #999; font-style: italic;">
                Este es un correo automático, por favor no respondas a este mensaje.
              </p>
            </div>
          </div>
        </body>
        </html>
      `;

      // Enviar email
      const smtpFrom = smtpSecrets.SMTP_FROM || smtpSecrets.SMTP_USER || "noreply@agromarket.com";

      await transporter.sendMail({
        from: `"AgroMarket" <${smtpFrom}>`,
        to: email,
        subject: "Código de Recuperación de Contraseña - AgroMarket",
        html: htmlContent,
        text: `
🌾 AgroMarket - Recuperación de Contraseña

Hola,

Has solicitado restablecer tu contraseña. Usa el siguiente código de verificación:

Código: ${code}

⚠️ IMPORTANTE: Este código expirará en 15 minutos. No compartas este código con nadie.

Si no solicitaste este código, puedes ignorar este correo de forma segura.

Saludos,
El equipo de AgroMarket
        `.trim(),
      });

      console.log(`✅ Código de recuperación enviado exitosamente a ${email}`);
      return {
        success: true,
        message: "Código de recuperación enviado exitosamente",
      };
    } catch (error) {
      console.error("Error en sendPasswordResetCode:", error);
      return {
        success: false,
        message: `Error al enviar código: ${error.message || error.toString()}`,
      };
    }
  }
);

// Cloud Function para verificar código de recuperación
exports.verifyPasswordResetCode = onCall(
  {
    region: "us-central1",
    maxInstances: 10,
    cors: true,
  },
  async (request) => {
    const { email, code } = request.data;

    if (!email || !code) {
      return {
        success: false,
        message: "Email y código son requeridos",
      };
    }

    try {
      // Buscar código válido - consulta simplificada sin orderBy para evitar necesidad de índice
      const codeQuery = await admin
        .firestore()
        .collection("passwordResetCodes")
        .where("email", "==", email)
        .where("code", "==", code)
        .where("used", "==", false)
        .get();

      if (codeQuery.empty) {
        return {
          success: false,
          message: "Código inválido o ya utilizado",
        };
      }

      // Ordenar en memoria por expiresAt (más reciente primero) o createdAt
      const codeDocs = codeQuery.docs.sort((a, b) => {
        const aData = a.data();
        const bData = b.data();
        
        // Usar expiresAt si está disponible, sino createdAt
        let aTime = 0;
        let bTime = 0;
        
        if (aData.expiresAt) {
          aTime = aData.expiresAt.toMillis ? aData.expiresAt.toMillis() : new Date(aData.expiresAt).getTime();
        } else if (aData.createdAt) {
          aTime = aData.createdAt.toMillis ? aData.createdAt.toMillis() : new Date(aData.createdAt).getTime();
        }
        
        if (bData.expiresAt) {
          bTime = bData.expiresAt.toMillis ? bData.expiresAt.toMillis() : new Date(bData.expiresAt).getTime();
        } else if (bData.createdAt) {
          bTime = bData.createdAt.toMillis ? bData.createdAt.toMillis() : new Date(bData.createdAt).getTime();
        }
        
        return bTime - aTime; // Descendente (más reciente primero)
      });

      const codeDoc = codeDocs[0];
      const codeData = codeDoc.data();

      // Verificar expiración - el código expira en 15 minutos
      let expiresAt;
      if (codeData.expiresAt) {
        expiresAt = codeData.expiresAt.toDate ? codeData.expiresAt.toDate() : new Date(codeData.expiresAt);
      } else {
        // Si no hay expiresAt, calcular desde createdAt + 15 minutos
        const createdAt = codeData.createdAt?.toDate ? codeData.createdAt.toDate() : new Date(codeData.createdAt);
        expiresAt = new Date(createdAt.getTime() + 15 * 60 * 1000); // 15 minutos
      }
      
      const now = new Date();
      const timeRemaining = Math.floor((expiresAt.getTime() - now.getTime()) / 1000 / 60); // minutos restantes

      if (now > expiresAt) {
        // Marcar como usado
        await codeDoc.ref.update({ used: true });
        return {
          success: false,
          message: "El código ha expirado. Solicita uno nuevo.",
        };
      }
      
      console.log(`⏰ Código válido. Tiempo restante: ${timeRemaining} minutos`);

      // Generar token de sesión único
      const sessionToken = admin.firestore().collection("passwordResetSessions").doc().id;

      // Guardar sesión válida
      await admin.firestore().collection("passwordResetSessions").doc(sessionToken).set({
        email: email,
        codeId: codeDoc.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 30 * 60 * 1000), // 30 minutos
        used: false,
      });

      // Marcar código como usado
      await codeDoc.ref.update({ used: true });

      console.log(`✅ Código verificado exitosamente para ${email}`);
      return {
        success: true,
        message: "Código verificado exitosamente",
        sessionToken: sessionToken,
      };
    } catch (error) {
      console.error("Error en verifyPasswordResetCode:", error);
      return {
        success: false,
        message: `Error verificando código: ${error.message || error.toString()}`,
      };
    }
  }
);

// Cloud Function para cambiar contraseña después de verificar código
exports.resetPasswordWithVerifiedCode = onCall(
  {
    region: "us-central1",
    maxInstances: 10,
    cors: true,
  },
  async (request) => {
    const { email, sessionToken, newPassword } = request.data;

    if (!email || !sessionToken || !newPassword) {
      return {
        success: false,
        message: "Email, sessionToken y nueva contraseña son requeridos",
      };
    }

    if (newPassword.length < 6) {
      return {
        success: false,
        message: "La contraseña debe tener al menos 6 caracteres",
      };
    }

    try {
      // Verificar sesión válida
      const sessionDoc = await admin
        .firestore()
        .collection("passwordResetSessions")
        .doc(sessionToken)
        .get();

      if (!sessionDoc.exists) {
        return {
          success: false,
          message: "Sesión inválida o expirada",
        };
      }

      const sessionData = sessionDoc.data();

      if (sessionData.used) {
        return {
          success: false,
          message: "Esta sesión ya fue utilizada",
        };
      }

      if (sessionData.email !== email) {
        return {
          success: false,
          message: "El email no coincide con la sesión",
        };
      }

      // Verificar expiración
      const expiresAt = sessionData.expiresAt.toDate();
      const now = new Date();

      if (now > expiresAt) {
        return {
          success: false,
          message: "La sesión ha expirado. Solicita un nuevo código.",
        };
      }

      // Cambiar contraseña en Firebase Auth
      const userRecord = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(userRecord.uid, {
        password: newPassword,
      });

      // Marcar sesión como usada
      await sessionDoc.ref.update({ used: true });

      console.log(`✅ Contraseña cambiada exitosamente para ${email}`);
      return {
        success: true,
        message: "Contraseña cambiada exitosamente",
      };
    } catch (error) {
      console.error("Error en resetPasswordWithVerifiedCode:", error);
      return {
        success: false,
        message: `Error cambiando contraseña: ${error.message || error.toString()}`,
      };
    }
  }
);

// Cloud Function para enviar comprobante de compra por email
exports.sendReceiptEmail = onCall(
  {
    region: "us-central1",
    maxInstances: 10,
    cors: true,
    secrets: ["SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS", "SMTP_SECURE", "SMTP_FROM"],
  },
  async (request) => {
    const {
      orderId,
      userEmail,
      total,
      productos,
      userName,
      subtotal,
      envio,
      impuestos,
      ciudad,
      telefono,
      direccionEntrega,
      metodoPago,
      fechaCompra,
    } = request.data;

    if (!userEmail || !orderId || !total || !productos) {
      return {
        success: false,
        message: "Email, orderId, total y productos son requeridos",
      };
    }

    try {
      console.log(`📧 Enviando comprobante de compra a ${userEmail} para orden ${orderId}`);

      // Generar HTML del comprobante
      // Los productos vienen con: nombre, cantidad, precio_unitario, precio_total, unidad
      const productosHtml = productos
        .map(
          (p) => {
            // Intentar leer precio_unitario o precio (compatibilidad)
            const precioUnitario = parseFloat(p['precio_unitario'] || p['precio'] || 0);
            // Intentar leer precio_total o subtotal (compatibilidad)
            const precioTotal = parseFloat(p['precio_total'] || p['subtotal'] || precioUnitario * (p['cantidad'] || 1));
            const cantidad = p['cantidad'] || 1;
            const unidad = p['unidad'] || '';
            const nombre = p['nombre'] || 'Producto';
            
            return `
        <tr>
          <td style="padding: 12px; border-bottom: 1px solid #e0e0e0;">
            <strong>${nombre}</strong>
            ${unidad ? `<br><span style="color: #666; font-size: 0.9em;">${unidad}</span>` : ''}
          </td>
          <td style="padding: 12px; border-bottom: 1px solid #e0e0e0; text-align: center; font-weight: 500;">${cantidad}</td>
          <td style="padding: 12px; border-bottom: 1px solid #e0e0e0; text-align: right; font-weight: 500;">$${precioUnitario.toFixed(2)}</td>
          <td style="padding: 12px; border-bottom: 1px solid #e0e0e0; text-align: right; font-weight: 600; color: #2E7D32;">$${precioTotal.toFixed(2)}</td>
        </tr>
      `;
          }
        )
        .join("");

      const fechaFormateada = fechaCompra
        ? new Date(fechaCompra).toLocaleDateString("es-MX", {
            year: "numeric",
            month: "long",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          })
        : new Date().toLocaleDateString("es-MX");

      const htmlContent = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; 
              line-height: 1.6; 
              color: #333; 
              background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
              padding: 20px;
            }
            .container { 
              max-width: 650px; 
              margin: 0 auto; 
              background-color: #ffffff; 
              border-radius: 16px; 
              overflow: hidden; 
              box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            }
            .header { 
              background: linear-gradient(135deg, #2E7D32 0%, #1B5E20 100%);
              color: white; 
              padding: 40px 30px; 
              text-align: center;
              position: relative;
            }
            .header::after {
              content: '';
              position: absolute;
              bottom: 0;
              left: 0;
              right: 0;
              height: 4px;
              background: linear-gradient(90deg, #4CAF50, #81C784, #4CAF50);
            }
            .header h1 { 
              font-size: 32px; 
              margin-bottom: 8px;
              font-weight: 700;
              letter-spacing: -0.5px;
            }
            .header h2 { 
              font-size: 20px; 
              font-weight: 400;
              opacity: 0.95;
            }
            .content { 
              padding: 40px 35px; 
              background: #ffffff;
            }
            .greeting {
              font-size: 18px;
              margin-bottom: 8px;
              color: #2E7D32;
            }
            .intro-text {
              color: #666;
              margin-bottom: 30px;
              font-size: 15px;
            }
            .order-info { 
              background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
              padding: 25px; 
              border-radius: 12px; 
              margin: 25px 0;
              border-left: 4px solid #2E7D32;
            }
            .order-info p {
              margin: 8px 0;
              font-size: 15px;
            }
            .order-info strong {
              color: #2E7D32;
              font-weight: 600;
              min-width: 140px;
              display: inline-block;
            }
            table { 
              width: 100%; 
              border-collapse: collapse; 
              margin: 30px 0;
              background: #fff;
              border-radius: 8px;
              overflow: hidden;
              box-shadow: 0 2px 8px rgba(0,0,0,0.05);
            }
            thead {
              background: linear-gradient(135deg, #2E7D32 0%, #1B5E20 100%);
            }
            th { 
              color: white; 
              padding: 16px 12px; 
              text-align: left;
              font-weight: 600;
              font-size: 14px;
              text-transform: uppercase;
              letter-spacing: 0.5px;
            }
            th:last-child, td:last-child {
              text-align: right;
            }
            th:nth-child(2) {
              text-align: center;
            }
            tbody tr {
              transition: background-color 0.2s;
            }
            tbody tr:hover {
              background-color: #f8f9fa;
            }
            tbody tr:last-child td {
              border-bottom: none;
            }
            td { 
              padding: 14px 12px; 
              border-bottom: 1px solid #e9ecef;
              font-size: 15px;
            }
            .summary {
              background: #f8f9fa;
              padding: 25px;
              border-radius: 12px;
              margin-top: 30px;
            }
            .summary-row {
              display: flex;
              justify-content: space-between;
              padding: 10px 0;
              font-size: 16px;
              border-bottom: 1px solid #e9ecef;
            }
            .summary-row:last-child {
              border-bottom: none;
            }
            .summary-label {
              color: #666;
              font-weight: 500;
            }
            .summary-value {
              color: #333;
              font-weight: 600;
            }
            .total-row {
              margin-top: 15px;
              padding-top: 15px;
              border-top: 2px solid #2E7D32;
              font-size: 22px;
              font-weight: 700;
            }
            .total-row .summary-label {
              color: #2E7D32;
              font-size: 22px;
            }
            .total-row .summary-value {
              color: #2E7D32;
              font-size: 24px;
            }
            .footer { 
              background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
              padding: 30px; 
              text-align: center; 
              border-top: 1px solid #e9ecef;
            }
            .footer p {
              margin: 8px 0;
              color: #666;
            }
            .footer-signature {
              font-weight: 600;
              color: #2E7D32;
              margin-top: 15px;
            }
            .footer-note {
              font-size: 12px; 
              color: #999; 
              margin-top: 15px;
              font-style: italic;
            }
            @media only screen and (max-width: 600px) {
              body { padding: 10px; }
              .content { padding: 25px 20px; }
              .header { padding: 30px 20px; }
              .header h1 { font-size: 26px; }
              table { font-size: 14px; }
              th, td { padding: 10px 8px; }
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🌾 AgroMarket</h1>
              <h2>Comprobante de Compra</h2>
            </div>
            <div class="content">
              <p class="greeting">Hola <strong>${userName || "Cliente"}</strong>,</p>
              <p class="intro-text">Gracias por tu compra. Aquí está el detalle de tu pedido:</p>
              
              <div class="order-info">
                <p><strong>Número de Orden:</strong> <span style="font-family: monospace; color: #2E7D32;">${orderId}</span></p>
                <p><strong>Fecha:</strong> ${fechaFormateada}</p>
                ${ciudad ? `<p><strong>Ciudad:</strong> ${ciudad}</p>` : ""}
                ${telefono ? `<p><strong>Teléfono:</strong> ${telefono}</p>` : ""}
                ${direccionEntrega ? `<p><strong>Dirección de Entrega:</strong> ${direccionEntrega}</p>` : ""}
                ${metodoPago ? `<p><strong>Método de Pago:</strong> <span style="text-transform: capitalize;">${metodoPago}</span></p>` : ""}
              </div>

              <table>
                <thead>
                  <tr>
                    <th>Producto</th>
                    <th style="text-align: center;">Cantidad</th>
                    <th style="text-align: right;">Precio Unit.</th>
                    <th style="text-align: right;">Subtotal</th>
                  </tr>
                </thead>
                <tbody>
                  ${productosHtml}
                </tbody>
              </table>

              <div class="summary">
                <div class="summary-row">
                  <span class="summary-label">Subtotal:</span>
                  <span class="summary-value">$${parseFloat(subtotal || 0).toFixed(2)}</span>
                </div>
                <div class="summary-row">
                  <span class="summary-label">Envío:</span>
                  <span class="summary-value">$${parseFloat(envio || 0).toFixed(2)}</span>
                </div>
                <div class="summary-row">
                  <span class="summary-label">Impuestos:</span>
                  <span class="summary-value">$${parseFloat(impuestos || 0).toFixed(2)}</span>
                </div>
                <div class="summary-row total-row">
                  <span class="summary-label">Total:</span>
                  <span class="summary-value">$${parseFloat(total).toFixed(2)}</span>
                </div>
              </div>

              <p style="margin-top: 30px; color: #666; font-size: 15px;">
                Si tienes alguna pregunta sobre tu pedido, no dudes en contactarnos.
              </p>
            </div>
            <div class="footer">
              <p class="footer-signature">Saludos,<br>El equipo de AgroMarket</p>
              <p class="footer-note">
                Este es un correo automático, por favor no respondas a este mensaje.
              </p>
            </div>
          </div>
        </body>
        </html>
      `;

      // Enviar email usando SMTP desde Firebase Cloud Functions
      // En Firebase Functions v2, los secrets están disponibles en process.env después de declararlos
      const smtpSecrets = {
        SMTP_HOST: (process.env.SMTP_HOST || "").trim(),
        SMTP_PORT: (process.env.SMTP_PORT || "").trim(),
        SMTP_USER: (process.env.SMTP_USER || "").trim(),
        SMTP_PASS: (process.env.SMTP_PASS || "").trim(),
        SMTP_SECURE: (process.env.SMTP_SECURE || "").trim(),
        SMTP_FROM: (process.env.SMTP_FROM || "").trim(),
      };
      
      console.log("🔍 Secrets disponibles:", {
        SMTP_HOST: smtpSecrets.SMTP_HOST ? "✅ Configurado" : "❌ No configurado",
        SMTP_PORT: smtpSecrets.SMTP_PORT ? "✅ Configurado" : "❌ No configurado",
        SMTP_USER: smtpSecrets.SMTP_USER ? "✅ Configurado" : "❌ No configurado",
        SMTP_PASS: smtpSecrets.SMTP_PASS ? "✅ Configurado" : "❌ No configurado",
      });
      
      const transporter = getEmailTransporter(smtpSecrets);
      if (!transporter) {
        console.error("❌ SMTP no configurado. No se puede enviar comprobante.");
        return {
          success: false,
          message: "Error de configuración: SMTP no está configurado en Firebase Functions. Por favor, contacta al soporte.",
        };
      }

      try {
        const smtpFrom = smtpSecrets.SMTP_FROM || smtpSecrets.SMTP_USER || "noreply@agromarket.com";
        
        console.log(`📧 Enviando comprobante a ${userEmail}...`);
        
        await transporter.sendMail({
          from: `"AgroMarket" <${smtpFrom}>`,
          to: userEmail,
          subject: `Comprobante de Compra - Orden ${orderId}`,
          html: htmlContent,
          text: `
🌾 AgroMarket - Comprobante de Compra

Hola ${userName || "Cliente"},

Gracias por tu compra. Aquí está el detalle de tu pedido:

Número de Orden: ${orderId}
Fecha: ${fechaFormateada}
${ciudad ? `Ciudad: ${ciudad}` : ""}
${telefono ? `Teléfono: ${telefono}` : ""}
${direccionEntrega ? `Dirección: ${direccionEntrega}` : ""}
${metodoPago ? `Método de Pago: ${metodoPago}` : ""}

Productos:
${productos.map(p => {
  const precioUnitario = parseFloat(p['precio_unitario'] || p['precio'] || 0);
  const precioTotal = parseFloat(p['precio_total'] || p['subtotal'] || precioUnitario * (p['cantidad'] || 1));
  return `- ${p['nombre'] || 'Producto'} x${p['cantidad'] || 1} - $${precioUnitario.toFixed(2)} c/u - Total: $${precioTotal.toFixed(2)}`;
}).join('\n')}

${subtotal ? `Subtotal: $${parseFloat(subtotal).toFixed(2)}` : ""}
${envio ? `Envío: $${parseFloat(envio).toFixed(2)}` : ""}
${impuestos ? `Impuestos: $${parseFloat(impuestos).toFixed(2)}` : ""}
Total: $${parseFloat(total).toFixed(2)}

Saludos,
El equipo de AgroMarket
          `.trim(),
        });

        console.log(`✅ Comprobante enviado exitosamente a ${userEmail}`);
        return {
          success: true,
          message: "Comprobante enviado exitosamente",
        };
      } catch (emailError) {
        console.error("❌ Error enviando comprobante con SMTP:", emailError);
        console.error("📋 Detalles del error:", {
          message: emailError.message,
          code: emailError.code,
          command: emailError.command,
          response: emailError.response,
        });
        
        // Mensaje de error más descriptivo
        let errorMessage = "Error al enviar el comprobante";
        if (emailError.code === "EBADNAME" || emailError.message.includes("EBADNAME")) {
          errorMessage = "Error de configuración SMTP: El host del servidor no es válido. Verifica la configuración.";
        } else if (emailError.code === "ETIMEDOUT" || emailError.message.includes("timeout")) {
          errorMessage = "Tiempo de espera agotado al conectar con el servidor SMTP. Intenta más tarde.";
        } else if (emailError.code === "EAUTH" || emailError.message.includes("authentication")) {
          errorMessage = "Error de autenticación SMTP. Verifica las credenciales.";
        } else {
          errorMessage = `Error al enviar el comprobante: ${emailError.message}`;
        }
        
        return {
          success: false,
          message: errorMessage,
        };
      }
    } catch (error) {
      console.error("Error en sendReceiptEmail:", error);
      return {
        success: false,
        message: "Error al generar comprobante",
      };
    }
  }
);

// Cloud Function para verificar código de recuperación
