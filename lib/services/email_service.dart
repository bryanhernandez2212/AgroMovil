import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class EmailService {
  // Usar Firebase Functions en lugar de Railway
  static String get _projectId {
    try {
      final projectId = FirebaseAuth.instance.app.options.projectId;
      if (projectId == null || projectId.isEmpty) {
        print('⚠️ ProjectId es null o vacío, usando valor por defecto');
        return 'agromarket-625b2';
      }
      print('✅ ProjectId obtenido: $projectId');
      return projectId;
    } catch (e) {
      print('⚠️ Error obteniendo projectId: $e, usando valor por defecto');
      return 'agromarket-625b2';
    }
  }
  static String get _region => 'us-central1';
  static String _getFunctionUrl(String functionName) {
    final projectId = _projectId;
    final region = _region;
    final url = 'https://$region-$projectId.cloudfunctions.net/$functionName';
    print('🌐 URL construida para $functionName: $url');
    return url;
  }

  /// Parsea y mejora mensajes de error comunes de SMTP
  static String _parseSmtpError(String? errorMessage, int? statusCode) {
    if (errorMessage == null) {
      return 'Error desconocido al enviar correo';
    }

    final errorLower = errorMessage.toLowerCase();
    
    // Errores del servidor (502, 503, 504, etc.)
    if (statusCode == 502 || errorLower.contains('application failed to respond') || 
        errorLower.contains('bad gateway')) {
      return 'El servidor no está respondiendo. El servicio de correo puede estar temporalmente no disponible. Por favor, intenta más tarde o contacta al soporte.';
    }
    
    if (statusCode == 503 || errorLower.contains('service unavailable')) {
      return 'El servicio de correo no está disponible temporalmente. Intenta más tarde.';
    }
    
    if (statusCode == 504 || errorLower.contains('gateway timeout')) {
      return 'El servidor tardó demasiado en responder. Intenta nuevamente.';
    }
    
    if (statusCode == 500 || errorLower.contains('internal server error')) {
      return 'Error interno del servidor. El problema ha sido reportado. Intenta más tarde.';
    }
    
    // Errores comunes de Google SMTP
    if (errorLower.contains('authentication failed') || 
        errorLower.contains('invalid login') ||
        errorLower.contains('535')) {
      return 'Error de autenticación con Google SMTP. Verifica las credenciales del servidor.';
    }
    
    if (errorLower.contains('connection refused') || 
        errorLower.contains('connection timeout') ||
        errorLower.contains('econnrefused')) {
      return 'No se pudo conectar al servidor SMTP de Google. Verifica la configuración de red.';
    }
    
    if (errorLower.contains('rate limit') || 
        errorLower.contains('quota exceeded') ||
        errorLower.contains('550')) {
      return 'Límite de envío de correos excedido. Intenta más tarde.';
    }
    
    if (errorLower.contains('invalid recipient') || 
        errorLower.contains('550-5.1.1')) {
      return 'Dirección de correo inválida. Verifica el email del destinatario.';
    }
    
    if (errorLower.contains('tls') || 
        errorLower.contains('ssl') ||
        errorLower.contains('certificate')) {
      return 'Error de seguridad SSL/TLS. Verifica la configuración del servidor SMTP.';
    }
    
    if (errorLower.contains('timeout')) {
      return 'Tiempo de espera agotado. El servidor SMTP no respondió a tiempo.';
    }
    
    // Si no coincide con ningún patrón conocido, devolver el mensaje original
    return errorMessage;
  }

  /// Enviar correo de recuperación de contraseña con código de 6 dígitos usando Firebase Functions
  static Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
    String? userName,
  }) async {
    try {
      print('📧 Enviando correo de recuperación a $email usando Firebase Functions');
      
      final functionUrl = _getFunctionUrl('sendPasswordResetCode');
      
      print('📤 Enviando petición a: $functionUrl');
      print('📋 Datos: email=$email');
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'email': email,
            if (userName != null) 'userName': userName,
          },
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Firebase Function está tardando demasiado en responder. Por favor, intenta más tarde.');
        },
      );

      print('📥 Respuesta recibida - Status: ${response.statusCode}');
      print('📄 Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final data = (responseData['result'] ?? responseData) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          print('✅ Correo de recuperación enviado exitosamente');
          return {
            'success': true,
            'message': data['message'] ?? 'Correo enviado exitosamente',
          };
        } else {
          final rawMessage = data['message'] ?? 'Error enviando correo';
          final parsedMessage = _parseSmtpError(rawMessage, response.statusCode);
          return {
            'success': false,
            'message': parsedMessage,
            'raw_error': rawMessage,
            'status_code': response.statusCode,
          };
        }
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('📄 Respuesta del servidor: ${response.body}');
        
        // Manejo específico para error 404
        if (response.statusCode == 404) {
          final projectId = _projectId;
          final region = _region;
          return {
            'success': false,
            'message': 'La función de correo no está disponible. Por favor, verifica que las Cloud Functions estén desplegadas. URL intentada: https://$region-$projectId.cloudfunctions.net/sendPasswordResetCode',
            'raw_error': '404 - Función no encontrada',
            'status_code': 404,
            'function_url': 'https://$region-$projectId.cloudfunctions.net/sendPasswordResetCode',
          };
        }
        
        try {
          final errorData = jsonDecode(response.body);
          final rawMessage = errorData['message'] ?? errorData['error'] ?? 'Error enviando correo';
          final parsedMessage = _parseSmtpError(rawMessage, response.statusCode);
          return {
            'success': false,
            'message': parsedMessage,
            'raw_error': rawMessage,
            'status_code': response.statusCode,
          };
        } catch (e) {
          return {
            'success': false,
            'message': _parseSmtpError('Error del servidor: ${response.statusCode}', response.statusCode),
            'status_code': response.statusCode,
          };
        }
      }
    } on TimeoutException catch (e) {
      print('❌ Timeout enviando correo: ${e.message}');
      return {
        'success': false,
        'message': 'Tiempo de espera agotado. Intenta más tarde.',
        'raw_error': e.toString(),
      };
    } catch (e) {
      print('❌ Error enviando correo de recuperación: $e');
      return {
        'success': false,
        'message': _parseSmtpError('Error de conexión: ${e.toString()}', null),
        'raw_error': e.toString(),
      };
    }
  }

  /// Verificar código de recuperación de contraseña usando Firebase Functions
  static Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      print('🔐 Verificando código de recuperación usando Firebase Functions...');
      
      final functionUrl = _getFunctionUrl('verifyPasswordResetCode');
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'email': email,
            'code': code,
          },
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Firebase Function está tardando demasiado en responder.');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final data = (responseData['result'] ?? responseData) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          print('✅ Código verificado exitosamente');
          return {
            'success': true,
            'message': data['message'] ?? 'Código verificado',
            'session_token': data['sessionToken'] ?? data['session_token'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Error verificando código',
          };
        }
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
    } on TimeoutException catch (e) {
      print('❌ Timeout verificando código: ${e.message}');
      return {
        'success': false,
        'message': 'Tiempo de espera agotado. Intenta más tarde.',
      };
    } catch (e) {
      print('❌ Error verificando código: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Enviar notificación de cambio de contraseña usando Firebase Functions
  /// NOTA: Esta función aún no está implementada en Firebase Functions
  /// Por ahora retorna éxito sin enviar el correo, o puedes implementarla en functions/index.js
  static Future<Map<String, dynamic>> sendPasswordChangedEmail({
    required String email,
    String? userName,
  }) async {
    print('📧 Notificación de cambio de contraseña para $email');
    print('⚠️ Función sendPasswordChangedEmail no implementada aún en Firebase Functions');
    
    // Por ahora, solo retornamos éxito ya que no es crítico
    // TODO: Implementar sendPasswordChangedEmail en Firebase Functions cuando sea necesario
    return {
      'success': true,
      'message': 'Notificación registrada (función aún no implementada)',
    };
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

  /// Enviar comprobante de pago usando Firebase Functions
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
      print('📧 Enviando comprobante a $email usando Firebase Functions');
      
      final functionUrl = _getFunctionUrl('sendReceiptEmail');
      
      // Formatear método de pago para que sea más legible
      String? metodoPagoFormateado;
      if (metodoPago != null) {
        metodoPagoFormateado = _formatMetodoPago(metodoPago);
      }
      
      print('📤 Enviando comprobante a: $functionUrl');
      print('📋 Datos: orderId=$orderId, email=$email, total=$total');
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'orderId': orderId,
            'userEmail': email,
            'total': total,
            'productos': productos,
            if (userName != null) 'userName': userName,
            if (subtotal != null) 'subtotal': subtotal,
            if (envio != null) 'envio': envio,
            if (impuestos != null) 'impuestos': impuestos,
            if (ciudad != null) 'ciudad': ciudad,
            if (telefono != null) 'telefono': telefono,
            if (direccionEntrega != null && direccionEntrega.isNotEmpty) 'direccionEntrega': direccionEntrega,
            if (metodoPagoFormateado != null) 'metodoPago': metodoPagoFormateado,
            if (fechaCompra != null) 'fechaCompra': fechaCompra.toIso8601String(),
          },
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Firebase Function está tardando demasiado en responder. Por favor, intenta más tarde.');
        },
      );

      print('📥 Respuesta recibida - Status: ${response.statusCode}');
      print('📄 Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final data = (responseData['result'] ?? responseData) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          print('✅ Comprobante enviado exitosamente');
          return {
            'success': true,
            'message': data['message'] ?? 'Comprobante enviado exitosamente',
          };
        } else {
          final rawMessage = data['message'] ?? 'Error enviando comprobante';
          final parsedMessage = _parseSmtpError(rawMessage, response.statusCode);
          return {
            'success': false,
            'message': parsedMessage,
            'raw_error': rawMessage,
            'status_code': response.statusCode,
          };
        }
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('📄 Respuesta del servidor: ${response.body}');
        
        // Manejo específico para error 404
        if (response.statusCode == 404) {
          final projectId = _projectId;
          final region = _region;
          return {
            'success': false,
            'message': 'La función de envío de comprobante no está disponible. Por favor, verifica que las Cloud Functions estén desplegadas. URL intentada: https://$region-$projectId.cloudfunctions.net/sendReceiptEmail',
            'raw_error': '404 - Función no encontrada',
            'status_code': 404,
            'function_url': 'https://$region-$projectId.cloudfunctions.net/sendReceiptEmail',
          };
        }
        
        try {
          final errorData = jsonDecode(response.body);
          final rawMessage = errorData['message'] ?? errorData['error'] ?? 'Error enviando comprobante';
          final parsedMessage = _parseSmtpError(rawMessage, response.statusCode);
          
          return {
            'success': false,
            'message': parsedMessage,
            'raw_error': rawMessage,
            'status_code': response.statusCode,
          };
        } catch (e) {
          return {
            'success': false,
            'message': _parseSmtpError('Error del servidor: ${response.statusCode}', response.statusCode),
            'status_code': response.statusCode,
          };
        }
      }
    } on TimeoutException catch (e) {
      print('❌ Timeout enviando comprobante: ${e.message}');
      return {
        'success': false,
        'message': 'Tiempo de espera agotado. Intenta más tarde.',
        'raw_error': e.toString(),
      };
    } catch (e) {
      print('❌ Error enviando comprobante: $e');
      return {
        'success': false,
        'message': _parseSmtpError('Error de conexión: ${e.toString()}', null),
        'raw_error': e.toString(),
      };
    }
  }
}

