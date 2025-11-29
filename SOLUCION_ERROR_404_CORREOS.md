# Solución para Error 404 en Envío de Correos

## Problema
Al subir la aplicación a Play Store, el envío de correos marca error 404. Esto significa que las Cloud Functions no están disponibles o no están desplegadas correctamente.

## Causa Principal
El error 404 indica que las Cloud Functions de Firebase no están desplegadas o no son accesibles desde la URL esperada.

## Solución: Verificar y Desplegar las Cloud Functions

### 1. Verificar que las funciones estén desplegadas

Ejecuta el siguiente comando en tu terminal desde la carpeta `functions`:

```bash
cd functions
firebase functions:list
```

Deberías ver las siguientes funciones:
- `sendPasswordResetCode`
- `verifyPasswordResetCode`
- `resetPasswordWithVerifiedCode`
- `sendReceiptEmail`

Si no aparecen, necesitas desplegarlas.

### 2. Desplegar las Cloud Functions

Desde la carpeta raíz del proyecto:

```bash
firebase deploy --only functions
```

O para desplegar solo las funciones de correo:

```bash
firebase deploy --only functions:sendPasswordResetCode,functions:verifyPasswordResetCode,functions:resetPasswordWithVerifiedCode,functions:sendReceiptEmail
```

### 3. Verificar la URL de las funciones

Después de desplegar, verifica que las funciones estén accesibles. La URL debería ser:

```
https://us-central1-agromarket-625b2.cloudfunctions.net/sendPasswordResetCode
https://us-central1-agromarket-625b2.cloudfunctions.net/sendReceiptEmail
```

Puedes probar estas URLs en tu navegador o con curl:

```bash
curl -X POST https://us-central1-agromarket-625b2.cloudfunctions.net/sendPasswordResetCode \
  -H "Content-Type: application/json" \
  -d '{"data":{"email":"test@example.com"}}'
```

### 4. Verificar configuración de SMTP

Asegúrate de que los secrets de SMTP estén configurados en Firebase:

```bash
firebase functions:secrets:access SMTP_HOST
firebase functions:secrets:access SMTP_PORT
firebase functions:secrets:access SMTP_USER
firebase functions:secrets:access SMTP_PASS
firebase functions:secrets:access SMTP_SECURE
firebase functions:secrets:access SMTP_FROM
```

Si no están configurados, configúralos con:

```bash
firebase functions:secrets:set SMTP_HOST
firebase functions:secrets:set SMTP_PORT
firebase functions:secrets:set SMTP_USER
firebase functions:secrets:set SMTP_PASS
firebase functions:secrets:set SMTP_SECURE
firebase functions:secrets:set SMTP_FROM
```

### 5. Verificar logs de las funciones

Para ver los logs y diagnosticar problemas:

```bash
firebase functions:log
```

O para una función específica:

```bash
firebase functions:log --only sendPasswordResetCode
```

## Verificación en la App

Después de desplegar, la aplicación mostrará mensajes más detallados en los logs cuando intente enviar correos. Los logs incluirán:

- La URL construida de la función
- El status code de la respuesta
- El cuerpo de la respuesta (si hay error)

Esto ayudará a diagnosticar si el problema persiste.

## Notas Importantes

1. **Primera vez desplegando**: Las Cloud Functions pueden tardar varios minutos en desplegarse la primera vez.

2. **Costo**: Las Cloud Functions v2 tienen un costo asociado. Verifica la facturación de Firebase.

3. **Región**: Las funciones están configuradas en `us-central1`. Asegúrate de que esta región esté disponible en tu plan de Firebase.

4. **Permisos**: Asegúrate de tener los permisos necesarios en Firebase para desplegar funciones.

## Si el problema persiste

1. Verifica que el `projectId` en `firebase_options.dart` sea correcto: `agromarket-625b2`
2. Verifica que estés conectado al proyecto correcto de Firebase:
   ```bash
   firebase projects:list
   firebase use agromarket-625b2
   ```
3. Revisa los logs de Firebase Console en: https://console.firebase.google.com/project/agromarket-625b2/functions/logs

## Cambios Realizados

Se ha mejorado el manejo de errores en:
- `lib/services/email_service.dart`
- `lib/services/firebase_service.dart`

Ahora estos archivos:
- Muestran la URL exacta que se está intentando usar
- Proporcionan mensajes de error más descriptivos cuando hay un 404
- Incluyen logs detallados para diagnóstico

