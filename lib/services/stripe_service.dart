import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:agromarket/services/api_service.dart';

class StripeService {
  static String get backendUrl => ApiService.baseUrl;
  
  // Crear Payment Intent en el servidor
  static Future<Map<String, dynamic>> createPaymentIntent({
    required String vendorId,
    required double amount,
    required String currency,
    required int applicationFeeAmount,
    String? orderId,
    Map<String, dynamic>? orderData,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print(' Creando Payment Intent con Stripe...');
      print('   - Monto: \$${amount.toStringAsFixed(2)}');
      print('   - Comisión (centavos): $applicationFeeAmount');
      
      final response = await http.post(
        Uri.parse('$backendUrl/create-payment-intent'), // Endpoint en tu backend
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (amount * 100).toInt(), // Stripe usa centavos
          'currency': currency.toLowerCase(),
          'metadata': {
            'order_id': orderData?['order_id'] ?? '',
            'user_id': orderData?['user_id'] ?? '',
            'user_email': orderData?['user_email'] ?? '',
          },
        }),
      );

      print('🔎 Respuesta createPaymentIntent: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' Payment Intent creado exitosamente');
        print('   - Payment Intent ID: ${data['paymentIntentId']}');
        if (data['clientSecret'] != null) {
          print('   - Client Secret: ${data['clientSecret'].toString().substring(0, 20)}...');
        }
        
        // Validar que tenemos el paymentIntentId
        final paymentIntentId = data['paymentIntentId'];
        if (paymentIntentId == null || paymentIntentId.toString().isEmpty) {
          print('⚠️ El servidor no devolvió paymentIntentId en StripeService.');
          return {
            'success': false,
            'message': 'El servidor no devolvió un Payment Intent ID válido',
          };
        }
        
        return {
          'success': true,
          'clientSecret': data['clientSecret'],
          'paymentIntentId': paymentIntentId,
        };
      } else {
        print(' Error del servidor: ${response.statusCode}');
        print(' Cuerpo de la respuesta: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? errorData['error'] ?? 'Error creando Payment Intent',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode} - ${response.body}',
          };
        }
      }
    } catch (e) {
      print(' Error creando Payment Intent: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Crear Payment Method con datos de tarjeta (el backend lo crea de forma segura)
  static Future<Map<String, dynamic>> createPaymentMethod({
    required String cardNumber,
    required int expiryMonth,
    required int expiryYear,
    required String cvc,
    required String cardHolderName,
    String? email,
  }) async {
    try {
      print(' Creando Payment Method con tarjeta...');
      
      final response = await http.post(
        Uri.parse('$backendUrl/create-payment-method'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'card_number': cardNumber,
          'expiry_month': expiryMonth,
          'expiry_year': expiryYear,
          'cvc': cvc,
          'cardholder_name': cardHolderName,
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' Payment Method creado: ${data['paymentMethodId']}');
        return {
          'success': true,
          'paymentMethodId': data['paymentMethodId'],
        };
      } else {
        print(' Error del servidor: ${response.statusCode}');
        print(' Cuerpo de la respuesta: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? errorData['error'] ?? 'Error creando Payment Method',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode} - ${response.body}',
          };
        }
      }
    } catch (e) {
      print(' Error creando Payment Method: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Confirmar pago con Payment Method (adjuntar PM al Payment Intent)
  static Future<Map<String, dynamic>> confirmPaymentWithMethod({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    try {
      print(' Confirmando pago con Payment Method...');
      print('   - Payment Intent ID: $paymentIntentId');
      print('   - Payment Method ID: $paymentMethodId');
      
      final response = await http.post(
        Uri.parse('$backendUrl/confirm-payment-method'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'payment_intent_id': paymentIntentId,
          'payment_method_id': paymentMethodId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' Pago confirmado exitosamente');
        print('   - Estado: ${data['status'] ?? 'confirmado'}');
        return {
          'success': true,
          'message': data['message'] ?? 'Pago confirmado',
          'status': data['status'],
        };
      } else {
        print(' Error confirmando pago: ${response.statusCode}');
        print(' Cuerpo de la respuesta: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? errorData['error'] ?? 'Error confirmando pago',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode} - ${response.body}',
          };
        }
      }
    } catch (e) {
      print(' Error confirmando pago: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Confirmar pago en el servidor (después de que Stripe confirma el pago)
  static Future<Map<String, dynamic>> confirmPayment({
    required String paymentIntentId,
    required String orderId,
  }) async {
    try {
      print(' Confirmando pago con Payment Intent ID: $paymentIntentId');
      
      final response = await http.post(
        Uri.parse('$backendUrl/confirm-payment'), // Endpoint en tu backend
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'payment_intent_id': paymentIntentId,
          'order_id': orderId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' Pago confirmado exitosamente');
        return {
          'success': true,
          'message': data['message'] ?? 'Pago confirmado',
        };
      } else {
        print(' Error confirmando pago: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Error confirmando pago',
        };
      }
    } catch (e) {
      print(' Error confirmando pago: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Enviar comprobante por correo (si tu backend lo maneja)
  static Future<Map<String, dynamic>> sendReceiptEmail({
    required String orderId,
    required String userEmail,
    required double total,
    required List<Map<String, dynamic>> productos,
  }) async {
    try {
      print(' Enviando comprobante por correo a $userEmail...');
      
      final response = await http.post(
        Uri.parse('$backendUrl/send-receipt'), // Endpoint en tu backend
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'order_id': orderId,
          'user_email': userEmail,
          'total': total,
          'productos': productos,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' Comprobante enviado exitosamente');
        return {
          'success': true,
          'message': data['message'] ?? 'Comprobante enviado',
        };
      } else {
        print(' Error enviando comprobante: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Error enviando comprobante',
        };
      }
    } catch (e) {
      print(' Error enviando comprobante: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }
}

