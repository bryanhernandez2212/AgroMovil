import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agromarket/services/api_service.dart';

class EmailService {
  static String get backendUrl => ApiService.baseUrl;

  /// Enviar correo de recuperación de contraseña con código de 6 dígitos
  static Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
    String? userName,
  }) async {
    try {
      print('📧 Enviando correo de recuperación a $email');
      
      final response = await http.post(
        Uri.parse('$backendUrl/send-password-reset'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          if (userName != null) 'user_name': userName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Correo de recuperación enviado exitosamente');
        return {
          'success': true,
          'message': data['message'] ?? 'Correo enviado exitosamente',
        };
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Error enviando correo',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('❌ Error enviando correo de recuperación: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Verificar código de recuperación de contraseña
  static Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      print('🔐 Verificando código de recuperación...');
      
      final response = await http.post(
        Uri.parse('$backendUrl/verify-reset-code'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Código verificado exitosamente');
        return {
          'success': true,
          'message': data['message'] ?? 'Código verificado',
          'session_token': data['session_token'],
        };
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Error verificando código',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('❌ Error verificando código: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Enviar notificación de cambio de contraseña
  static Future<Map<String, dynamic>> sendPasswordChangedEmail({
    required String email,
    String? userName,
  }) async {
    try {
      print('📧 Enviando notificación de cambio de contraseña a $email');
      
      final response = await http.post(
        Uri.parse('$backendUrl/send-password-changed'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          if (userName != null) 'user_name': userName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Notificación enviada exitosamente');
        return {
          'success': true,
          'message': data['message'] ?? 'Notificación enviada exitosamente',
        };
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Error enviando notificación',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('❌ Error enviando notificación: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Convierte el método de pago a texto legible
  static String _formatMetodoPago(String metodoPago) {
    switch (metodoPago.toLowerCase()) {
      case 'tarjeta':
        return 'Tarjeta de crédito/débito';
      case 'transferencia':
        return 'Transferencia bancaria';
      case 'efectivo':
        return 'Efectivo';
      default:
        return metodoPago;
    }
  }

  /// Enviar comprobante de pago
  static Future<Map<String, dynamic>> sendReceiptEmail({
    required String email,
    required String orderId,
    required double total,
    required List<Map<String, dynamic>> productos,
    String? userName,
    double? subtotal,
    double? envio,
    double? impuestos,
    String? ciudad,
    String? telefono,
    String? direccionEntrega,
    String? metodoPago,
    DateTime? fechaCompra,
  }) async {
    try {
      print('📧 Enviando comprobante a $email');
      
      // Formatear método de pago para que sea más legible
      String? metodoPagoFormateado;
      if (metodoPago != null) {
        metodoPagoFormateado = _formatMetodoPago(metodoPago);
      }
      
      final response = await http.post(
        Uri.parse('$backendUrl/send-receipt'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'order_id': orderId,
          'user_email': email,
          'total': total,
          'productos': productos,
          if (userName != null) 'user_name': userName,
          if (subtotal != null) 'subtotal': subtotal,
          if (envio != null) 'envio': envio,
          if (impuestos != null) 'impuestos': impuestos,
          if (ciudad != null) 'ciudad': ciudad,
          if (telefono != null) 'telefono': telefono,
          if (direccionEntrega != null && direccionEntrega.isNotEmpty) 'direccion_entrega': direccionEntrega,
          if (metodoPagoFormateado != null) 'metodo_pago': metodoPagoFormateado,
          if (fechaCompra != null) 'fecha_compra': fechaCompra.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Comprobante enviado exitosamente');
        return {
          'success': true,
          'message': data['message'] ?? 'Comprobante enviado exitosamente',
        };
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Error enviando comprobante',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('❌ Error enviando comprobante: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }
}

