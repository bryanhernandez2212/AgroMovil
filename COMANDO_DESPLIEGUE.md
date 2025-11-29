# ⚠️ ACCIÓN REQUERIDA: Desplegar Funciones de Correo

## Estado Actual

✅ **Secrets de SMTP configurados**: Los valores de SMTP están configurados en Firebase
❌ **Funciones de correo NO desplegadas**: Solo 2 de 6 funciones están desplegadas

## Problema

Las funciones de correo están definidas en `functions/index.js` pero **NO están desplegadas** en Firebase, por eso recibes el error 404.

Funciones que faltan por desplegar:
- ❌ `sendPasswordResetCode`
- ❌ `verifyPasswordResetCode`
- ❌ `resetPasswordWithVerifiedCode`
- ❌ `sendReceiptEmail`

## Solución: Desplegar las Funciones

Ejecuta este comando para desplegar las funciones de correo:

```bash
cd /Users/bryan/Desktop/integradora/AgroMovil/functions
firebase deploy --only functions:sendPasswordResetCode,functions:verifyPasswordResetCode,functions:resetPasswordWithVerifiedCode,functions:sendReceiptEmail
```

**O para desplegar todas las funciones a la vez:**

```bash
cd /Users/bryan/Desktop/integradora/AgroMovil
firebase deploy --only functions
```

## Verificar después del despliegue

```bash
firebase functions:list
```

Deberías ver 6 funciones (las 2 que ya tienes + las 4 nuevas de correo).

## Tiempo estimado

El despliegue puede tardar entre 5-10 minutos, especialmente la primera vez.

## Después del despliegue

Una vez desplegadas, el error 404 debería desaparecer y los correos deberían funcionar correctamente.

