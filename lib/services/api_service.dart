import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Cambiar esta IP por la tuya (la que aparece en el servidor)
  static const String baseUrl = 'http://192.168.1.183:8000/api';
  
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  // Verificar estado del servidor
  static Future<bool> testConnection() async {
    try {
      print('🔍 Probando conexión con el servidor...');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      );
      print('Respuesta del servidor: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error conectando al servidor: $e');
      return false;
    }
  }

  // Login de usuario
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🔐 Intentando login con email: $email');
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('Respuesta del servidor: ${response.statusCode}');
      print('Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('Login exitoso: $result');
        return result;
      } else {
        final errorBody = jsonDecode(response.body);
        print('Error del servidor: ${errorBody['message']}');
        return {
          'success': false,
          'message': errorBody['message'] ?? 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error en login API: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Registro de usuario
  static Future<Map<String, dynamic>> register(String nombre, String email, String password) async {
    try {
      print('📝 Intentando registro con email: $email');
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: _headers,
        body: jsonEncode({
          'nombre': nombre,
          'email': email,
          'password': password,
        }),
      );

      print('Respuesta del servidor: ${response.statusCode}');
      print('Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('Registro exitoso: $result');
        return result;
      } else {
        final errorBody = jsonDecode(response.body);
        print('Error del servidor: ${errorBody['message']}');
        return {
          'success': false,
          'message': errorBody['message'] ?? 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error en registro API: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Obtener todos los usuarios (para testing)
  static Future<Map<String, dynamic>> getUsers() async {
    try {
      print('👥 Obteniendo usuarios...');
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: _headers,
      );

      print('Respuesta del servidor: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('Usuarios obtenidos: ${result['count']} usuarios');
        return result;
      } else {
        return {
          'success': false,
          'message': 'Error obteniendo usuarios: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error obteniendo usuarios: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }
}
