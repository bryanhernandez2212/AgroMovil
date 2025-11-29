# Desplegar Funciones de Correo - Solución Error 404

## Problema Identificado
Las funciones de correo **NO están desplegadas** en Firebase. Solo están desplegadas:
- ✅ `notifyNewMessage`
- ✅ `notifyOrderStatusChange`

Pero faltan estas funciones críticas de correo:
- ❌ `sendPasswordResetCode`
- ❌ `verifyPasswordResetCode`
- ❌ `resetPasswordWithVerifiedCode`
- ❌ `sendReceiptEmail`

## Solución: Desplegar las Funciones

### Paso 1: Verificar que estás en el proyecto correcto
```bash
firebase use
# Debe mostrar: agromarket-625b2
```

### Paso 2: Desplegar todas las funciones de correo
```bash
cd functions
firebase deploy --only functions:sendPasswordResetCode,functions:verifyPasswordResetCode,functions:resetPasswordWithVerifiedCode,functions:sendReceiptEmail
```

**O para desplegar todas las funciones:**
```bash
firebase deploy --only functions
```

### Paso 3: Verificar el despliegue
```bash
firebase functions:list
```

Deberías ver ahora 6 funciones:
- notifyNewMessage
- notifyOrderStatusChange
- sendPasswordResetCode ✅
- verifyPasswordResetCode ✅
- resetPasswordWithVerifiedCode ✅
- sendReceiptEmail ✅

### Paso 4: Verificar que los Secrets de SMTP estén configurados

Antes de desplegar, asegúrate de que los secrets de SMTP estén configurados:

```bash
firebase functions:secrets:access SMTP_HOST
firebase functions:secrets:access SMTP_PORT
firebase functions:secrets:access SMTP_USER
firebase functions:secrets:access SMTP_PASS
firebase functions:secrets:access SMTP_SECURE
firebase functions:secrets:access SMTP_FROM
```

Si alguno no está configurado, configúralo:

```bash
# Ejemplo (reemplaza con tus valores reales)
echo "smtp.gmail.com" | firebase functions:secrets:set SMTP_HOST
echo "587" | firebase functions:secrets:set SMTP_PORT
echo "tu-email@gmail.com" | firebase functions:secrets:set SMTP_USER
echo "tu-contraseña-app" | firebase functions:secrets:set SMTP_PASS
echo "false" | firebase functions:secrets:set SMTP_SECURE
echo "noreply@agromarket.com" | firebase functions:secrets:set SMTP_FROM
```

### Paso 5: Verificar las URLs de las funciones

Después del despliegue, las funciones deberían estar disponibles en:

```
https://us-central1-agromarket-625b2.cloudfunctions.net/sendPasswordResetCode
https://us-central1-agromarket-625b2.cloudfunctions.net/verifyPasswordResetCode
https://us-central1-agromarket-625b2.cloudfunctions.net/resetPasswordWithVerifiedCode
https://us-central1-agromarket-625b2.cloudfunctions.net/sendReceiptEmail
```

## Notas Importantes

1. **Tiempo de despliegue**: El primer despliegue puede tardar varios minutos (5-10 minutos).

2. **Costo**: Las Cloud Functions v2 tienen costo asociado. Revisa tu facturación.

3. **Logs**: Puedes ver los logs en tiempo real:
   ```bash
   firebase functions:log
   ```

4. **Permisos**: Asegúrate de tener permisos de administrador en el proyecto Firebase.

## Después del Despliegue

Una vez desplegadas, prueba el envío de correos desde la app. Los logs mejorados mostrarán:
- La URL exacta intentada
- El status code de la respuesta
- Detalles del error (si hay alguno)

Si aún hay problemas después del despliegue, revisa los logs de Firebase Console.

