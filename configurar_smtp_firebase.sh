#!/bin/bash

# Script para configurar los secrets de SMTP en Firebase Functions
# Reemplaza los valores entre comillas con los que ya tenías configurados

# ========================================
# ⚠️ EDITA ESTOS VALORES CON LOS QUE YA TENÍAS CONFIGURADOS
# ========================================

SMTP_HOST="smtp.gmail.com"           # Ejemplo: smtp.gmail.com
SMTP_PORT="587"                       # Ejemplo: 587
SMTP_USER="tu-email@gmail.com"       # Tu email
SMTP_PASS="tu-app-password"          # Tu contraseña o App Password
SMTP_SECURE="false"                   # true o false
SMTP_FROM="tu-email@gmail.com"       # Email desde el cual se envían

# ========================================
# NO MODIFIQUES NADA DE AQUÍ HACIA ABAJO
# ========================================

echo "🔧 Configurando secrets de SMTP en Firebase Functions..."
echo ""
echo "📝 Usando los siguientes valores:"
echo "   SMTP_HOST: $SMTP_HOST"
echo "   SMTP_PORT: $SMTP_PORT"
echo "   SMTP_USER: $SMTP_USER"
echo "   SMTP_PASS: *** (oculto por seguridad)"
echo "   SMTP_SECURE: $SMTP_SECURE"
echo "   SMTP_FROM: $SMTP_FROM"
echo ""
read -p "¿Son correctos estos valores? (s/n): " confirmacion

if [ "$confirmacion" != "s" ] && [ "$confirmacion" != "S" ]; then
    echo "❌ Configuración cancelada. Edita los valores en el script y vuelve a ejecutarlo."
    exit 1
fi

echo ""
echo "📧 Configurando SMTP_HOST..."
echo "$SMTP_HOST" | firebase functions:secrets:set SMTP_HOST

echo "📧 Configurando SMTP_PORT..."
echo "$SMTP_PORT" | firebase functions:secrets:set SMTP_PORT

echo "📧 Configurando SMTP_USER..."
echo "$SMTP_USER" | firebase functions:secrets:set SMTP_USER

echo "📧 Configurando SMTP_PASS..."
echo "$SMTP_PASS" | firebase functions:secrets:set SMTP_PASS

echo "📧 Configurando SMTP_SECURE..."
echo "$SMTP_SECURE" | firebase functions:secrets:set SMTP_SECURE

echo "📧 Configurando SMTP_FROM..."
echo "$SMTP_FROM" | firebase functions:secrets:set SMTP_FROM

echo ""
echo "✅ Todos los secrets han sido configurados!"
echo ""
echo "🚀 Ahora despliega las funciones con:"
echo "   firebase deploy --only functions"
