/// Configuración de Stripe
/// 
/// La clave pública de Stripe puede estar en el cliente de forma segura.
/// La clave secreta NUNCA debe estar aquí - solo en el servidor.
class StripeConfig {
  // Clave pública de Stripe (publishable key)
  // Esta clave está diseñada para usarse en el cliente de forma segura
  static const String publishableKey = 'pk_test_51S4nWTKFtQrWkPCD3FRrULpKifZ43LK9m3RcNn9TFpbzYqNU36uInxGyKRuuV78HtuC5drNe0qeZWei34yKGiYeF00M9L6swJq';
  
  // NOTA: La clave secreta (secret key) NUNCA debe estar aquí
  // Solo debe estar en el servidor (STRIPE-SERVER/config.py)
}

