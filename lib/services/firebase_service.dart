import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agromarket/services/email_service.dart';
import 'package:agromarket/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Registrar nuevo usuario con email y contraseña
  static Future<Map<String, dynamic>> registerWithEmail({
    required String nombre,
    required String email,
    required String password,
    required String rol,
    String? nombreEmpresa,
    String? ubicacion,
    double? ubicacionLat,
    double? ubicacionLng,
  }) async {
    try {
      print('Registrando usuario: $email');
      
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Preparar datos base
        final userData = <String, dynamic>{
          'nombre': nombre,
          'email': email,
          'activo': true,
          'rol_activo': rol,
          'roles': [rol],
          'fecha_registro': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        };

        // Agregar campos opcionales solo para vendedores
        if (rol == 'vendedor') {
          // Nombre de tienda
          if (nombreEmpresa != null && nombreEmpresa.isNotEmpty) {
            userData['nombre_tienda'] = nombreEmpresa;
          }
          // Ubicación
          if (ubicacion != null && ubicacion.isNotEmpty) {
            userData['ubicacion'] = ubicacion;
            userData['ubicacion_formatted'] = ubicacion;
          }
          if (ubicacionLat != null && ubicacionLng != null) {
            userData['ubicacion_lat'] = ubicacionLat;
            userData['ubicacion_lng'] = ubicacionLng;
          }
        }

        // Guardar datos en Firestore
        await _firestore.collection('usuarios').doc(userCredential.user!.uid).set(userData);

        print('Usuario registrado exitosamente');
        return {
          'success': true,
          'message': 'Usuario registrado exitosamente',
          'user': {
            'id': userCredential.user!.uid,
            'nombre': nombre,
            'email': email,
            'activo': true,
            'rol_activo': rol,
            'roles': [rol],
            'fecha_registro': FieldValue.serverTimestamp(),
          }
        };
      } else {
        return {
          'success': false,
          'message': 'Error creando usuario',
        };
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'La contraseña es muy débil';
          break;
        case 'email-already-in-use':
          message = 'El email ya está registrado';
          break;
        case 'invalid-email':
          message = 'El email no es válido';
          break;
        case 'operation-not-allowed':
          message = 'Esta operación no está permitida';
          break;
        case 'network-request-failed':
          message = 'Error de conexión. Verifica tu internet';
          break;
        default:
          message = 'Error al crear la cuenta. Inténtalo de nuevo';
      }
      
      print('Error en registro: $message');
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('Error inesperado en registro: $e');
      return {
        'success': false,
        'message': 'Error inesperado: ${e.toString()}',
      };
    }
  }


  /// Iniciar sesión con email y contraseña
  static Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('Iniciando sesión: $email');
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Obtener datos del usuario desde Firestore
        final userDoc = await _firestore
            .collection('usuarios')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          print('Login exitoso');
          return {
            'success': true,
            'message': 'Login exitoso',
            'user': {
              'id': userCredential.user!.uid,
              'nombre': userData['nombre'],
              'email': userData['email'],
              'activo': userData['activo'] ?? true,
              'rol_activo': userData['rol_activo'] ?? 'comprador',
              'roles': userData['roles'] ?? ['comprador'],
              'fecha_registro': userData['fecha_registro'],
            }
          };
        } else {
          return {
            'success': false,
            'message': 'Datos de usuario no encontrados',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Error en el login',
        };
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Usuario no encontrado';
          break;
        case 'wrong-password':
          message = 'Contraseña incorrecta';
          break;
        case 'invalid-email':
          message = 'Email no válido';
          break;
        case 'user-disabled':
          message = 'Usuario deshabilitado';
          break;
        case 'too-many-requests':
          message = 'Demasiados intentos fallidos. Intenta más tarde';
          break;
        case 'network-request-failed':
          message = 'Error de conexión. Verifica tu internet';
          break;
        case 'invalid-credential':
          message = 'Credenciales incorrectas. Verifica tu email y contraseña';
          break;
        default:
          message = 'Credenciales incorrectas. Verifica tu email y contraseña';
      }
      
      print('Error en login: $message');
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('Error inesperado en login: $e');
      return {
        'success': false,
        'message': 'Error inesperado: ${e.toString()}',
      };
    }
  }

  /// Enviar email de verificación
  static Future<Map<String, dynamic>> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'No hay usuario autenticado',
        };
      }

      if (user.emailVerified) {
        return {
          'success': true,
          'message': 'El email ya está verificado',
        };
      }

      print('Enviando email de verificación a: ${user.email}');
      
      await user.sendEmailVerification();
      
      print('Email de verificación enviado exitosamente');
      return {
        'success': true,
        'message': 'Se ha enviado un email de verificación a ${user.email}',
      };
    } catch (e) {
      print('Error enviando email de verificación: $e');
      return {
        'success': false,
        'message': 'Error enviando email de verificación: ${e.toString()}',
      };
    }
  }

  /// Enviar email de recuperación de contraseña usando nuestro servicio personalizado
  static Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      print('📧 Enviando email de recuperación personalizado a: $email');
      
      // Verificar que el usuario existe y obtener su nombre desde Firestore
      String? userName;
      try {
        final userQuery = await _firestore
            .collection('usuarios')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        
        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          userName = userData['nombre'] as String?;
          print('✅ Usuario encontrado en Firestore');
        }
      } catch (e) {
        print('⚠️ Error verificando usuario en Firestore: $e');
        // Continuar intentando enviar el correo
      }
      
      // Generar enlace de recuperación usando Firebase
      // Usamos ActionCodeSettings para manejar el enlace en la app
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://agromarket.com/reset-password',
        handleCodeInApp: true,
        androidPackageName: 'com.example.agromarket',
        iOSBundleId: 'com.example.agromarket',
      );
      
      // Usar nuestro servicio personalizado para enviar correo con código de 6 dígitos
      print('📧 Enviando correo personalizado con código de 6 dígitos...');
      final emailResult = await EmailService.sendPasswordResetEmail(
        email: email,
        userName: userName,
      );
      
      if (emailResult['success']) {
        print('✅ Email personalizado con código enviado exitosamente');
        return {
          'success': true,
          'message': 'Se ha enviado un código de recuperación a $email',
        };
      } else {
        // Si falla nuestro servicio, usar Firebase como respaldo SOLO EN ESTE CASO
        print('⚠️ Falló nuestro servicio de email, usando Firebase como respaldo');
        await _auth.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: actionCodeSettings,
        );
        return {
          'success': true,
          'message': 'Se ha enviado un email de recuperación a $email',
        };
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No existe una cuenta con este email';
          break;
        case 'invalid-email':
          message = 'El email no es válido';
          break;
        case 'too-many-requests':
          message = 'Demasiados intentos. Intenta más tarde';
          break;
        case 'network-request-failed':
          message = 'Error de conexión. Verifica tu internet';
          break;
        default:
          message = 'Error al enviar el email. Inténtalo de nuevo';
      }
      
      print('❌ Error enviando email de recuperación: $message');
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('❌ Error inesperado enviando email: $e');
      return {
        'success': false,
        'message': 'Error inesperado: ${e.toString()}',
      };
    }
  }

  /// Cambiar contraseña después de verificar código de recuperación
  /// Usa el backend para cambiar la contraseña directamente
  static Future<Map<String, dynamic>> resetPasswordWithCode({
    required String email,
    required String sessionToken,
    required String newPassword,
  }) async {
    try {
      print('🔄 Cambiando contraseña con código verificado para: $email');
      print('🔑 Session Token: ${sessionToken.substring(0, 20)}...');
      print('🔒 Nueva contraseña: ${"*" * newPassword.length} (${newPassword.length} caracteres)');

      final requestBody = {
        'email': email,
        'session_token': sessionToken,
        'new_password': newPassword,
      };
      
      print('📤 Enviando solicitud a: ${ApiService.baseUrl}/reset-password-with-code');
      print('📦 Body: ${jsonEncode({
        'email': email,
        'session_token': sessionToken.substring(0, 20) + '...',
        'new_password': '*' * newPassword.length,
      })}');

      // Enviar solicitud al backend para cambiar la contraseña
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/reset-password-with-code'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Si el backend dice que debemos usar Firebase directamente
        if (data['use_firebase'] == true) {
          print('🔄 Usando Firebase directamente para cambiar contraseña');
          
          // Generar enlace de recuperación de Firebase
          final actionCodeSettings = ActionCodeSettings(
            url: 'https://agromarket.com/reset-password',
            handleCodeInApp: false,
          );

          try {
            // Enviar email de reset - esto generará un enlace que el usuario puede usar
            await _auth.sendPasswordResetEmail(
              email: email,
              actionCodeSettings: actionCodeSettings,
            );

            print('✅ Email de cambio de contraseña enviado desde Firebase');
            
            return {
              'success': true,
              'message': 'Se ha enviado un enlace a tu correo para cambiar la contraseña. Por favor, revisa tu bandeja de entrada.',
              'requires_email_link': true,
            };
          } catch (e) {
            print('⚠️ Error generando enlace de Firebase: $e');
            return {
              'success': false,
              'message': 'Error generando enlace de recuperación. Por favor, intenta de nuevo.',
            };
          }
        }
        
        print('✅ Contraseña cambiada exitosamente por el backend');
        
        // Enviar notificación por correo
        try {
          final userDoc = await _firestore
              .collection('usuarios')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          
          String? userName;
          if (userDoc.docs.isNotEmpty) {
            final userData = userDoc.docs.first.data();
            userName = userData['nombre'] as String?;
          }
          
          await _sendPasswordChangedNotification(
            email: email,
            userName: userName,
          );
        } catch (e) {
          print('⚠️ Advertencia: No se pudo enviar notificación: $e');
        }
        
        return {
          'success': true,
          'message': data['message'] ?? 'Contraseña cambiada exitosamente',
        };
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('📄 Respuesta del servidor: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Error cambiando contraseña';
          print('💬 Mensaje de error: $errorMessage');
          return {
            'success': false,
            'message': errorMessage,
          };
        } catch (e) {
          print('⚠️ Error parseando respuesta: $e');
          return {
            'success': false,
            'message': 'Error del servidor: ${response.statusCode}. ${response.body}',
          };
        }
      }
    } catch (e) {
      print('❌ Error inesperado: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Cambiar contraseña usando un enlace de Firebase (desde deep link o URL)
  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      print('🔄 Confirmando cambio de contraseña con código de Firebase');
      
      await _auth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      
      print('✅ Contraseña cambiada exitosamente');
      return {
        'success': true,
        'message': 'Contraseña cambiada exitosamente',
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'expired-action-code':
          message = 'El código ha expirado. Solicita un nuevo código.';
          break;
        case 'invalid-action-code':
          message = 'El código es inválido. Solicita un nuevo código.';
          break;
        case 'weak-password':
          message = 'La nueva contraseña es muy débil';
          break;
        case 'network-request-failed':
          message = 'Error de conexión. Verifica tu internet';
          break;
        default:
          message = 'Error al cambiar la contraseña. Inténtalo de nuevo';
      }
      
      print('❌ Error cambiando contraseña: $message');
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('❌ Error inesperado: $e');
      return {
        'success': false,
        'message': 'Error inesperado: ${e.toString()}',
      };
    }
  }

  /// Cambiar contraseña del usuario autenticado (requiere contraseña actual)
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'No hay usuario autenticado',
        };
      }

      if (user.email == null) {
        return {
          'success': false,
          'message': 'El usuario no tiene email asociado',
        };
      }

      print('Cambiando contraseña para usuario: ${user.email}');

      // Re-autenticar al usuario con la contraseña actual
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      print('Re-autenticación exitosa');

      // Cambiar la contraseña
      await user.updatePassword(newPassword);
      print('Contraseña actualizada exitosamente');

      // Enviar notificación por correo usando el servicio de email
      try {
        // Obtener nombre del usuario desde Firestore
        final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
        String? userName;
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          userName = userData['nombre'] as String?;
        }
        
        // Importar y usar el servicio de email
        final emailResult = await _sendPasswordChangedNotification(
          email: user.email!,
          userName: userName,
        );
        
        if (!emailResult['success']) {
          print('⚠️ Advertencia: No se pudo enviar notificación por correo: ${emailResult['message']}');
          // No fallar el proceso si el email no se puede enviar
        }
      } catch (e) {
        print('⚠️ Advertencia: Error enviando notificación: $e');
        // No fallar el proceso si el email no se puede enviar
      }

      return {
        'success': true,
        'message': 'Contraseña actualizada exitosamente',
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'La contraseña actual es incorrecta';
          break;
        case 'weak-password':
          message = 'La nueva contraseña es muy débil';
          break;
        case 'requires-recent-login':
          message = 'Por seguridad, debes iniciar sesión nuevamente';
          break;
        case 'network-request-failed':
          message = 'Error de conexión. Verifica tu internet';
          break;
        case 'invalid-credential':
          message = 'La contraseña actual es incorrecta';
          break;
        default:
          message = 'Error al cambiar la contraseña. Inténtalo de nuevo';
      }
      
      print('Error cambiando contraseña: $message');
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('Error inesperado cambiando contraseña: $e');
      return {
        'success': false,
        'message': 'Error inesperado: ${e.toString()}',
      };
    }
  }

  /// Cerrar sesión
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('Sesión cerrada');
    } catch (e) {
      print('Error cerrando sesión: $e');
    }
  }

  /// Obtener usuario actual
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Verificar si hay un usuario autenticado
  static bool isUserSignedIn() {
    return _auth.currentUser != null;
  }

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtener datos del usuario actual
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        print('🔥 FirebaseService: Datos obtenidos de Firestore: $data');
        print('🔥 FirebaseService: rol_activo: ${data['rol_activo']}');
        print('🔥 FirebaseService: roles: ${data['roles']}');
        print('🔥 FirebaseService: activo: ${data['activo']}');
        print('🔥 FirebaseService: nombre_tienda: ${data['nombre_tienda']}');
        print('🔥 FirebaseService: ubicacion: ${data['ubicacion']}');
        print('🔥 FirebaseService: ubicacion_formatted: ${data['ubicacion_formatted']}');
        
        final result = {
          'id': user.uid,
          'nombre': data['nombre'],
          'email': data['email'],
          'activo': data['activo'] ?? true,
          'rol_activo': data['rol_activo'] ?? 'comprador',
          'roles': data['roles'] ?? ['comprador'],
          'fecha_registro': data['fecha_registro'],
          'created_at': data['created_at'],
          'updated_at': data['updated_at'],
        };
        
        // Agregar campos de vendedor si existen
        if (data.containsKey('nombre_tienda')) {
          result['nombre_tienda'] = data['nombre_tienda'];
        }
        if (data.containsKey('ubicacion')) {
          result['ubicacion'] = data['ubicacion'];
        }
        if (data.containsKey('ubicacion_formatted')) {
          result['ubicacion_formatted'] = data['ubicacion_formatted'];
        }
        if (data.containsKey('ubicacion_lat')) {
          result['ubicacion_lat'] = data['ubicacion_lat'];
        }
        if (data.containsKey('ubicacion_lng')) {
          result['ubicacion_lng'] = data['ubicacion_lng'];
        }
        
        print('🔥 FirebaseService: Datos procesados: $result');
        return result;
      }
      return null;
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
  }

  /// Actualizar datos del usuario
  static Future<bool> updateUserData(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      data.remove('id');
      data.remove('created_at');
      data['updated_at'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .update(data);

      print('Datos del usuario actualizados');
      return true;
    } catch (e) {
      print('Error actualizando datos del usuario: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('usuarios')
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nombre': data['nombre'],
          'email': data['email'],
          'created_at': data['created_at'],
          'updated_at': data['updated_at'],
        };
      }).toList();
    } catch (e) {
      print('Error obteniendo usuarios: $e');
      return [];
    }
  }


  // Verificar conexión a Firebase
  /// Registrar usuario de Microsoft OAuth en Firestore
  static Future<Map<String, dynamic>> registerMicrosoftUser({
    required String nombre,
    required String email,
  }) async {
    try {
      print('🔥 FirebaseService: Iniciando registro de usuario Microsoft');
      print('📧 Email: $email');
      print('👤 Nombre: $nombre');
      
      // Crear un ID único para el usuario de Microsoft
      final userId = 'microsoft_${email.hashCode}';
      print('🆔 UserID generado: $userId');
      
      // Verificar si el usuario ya existe
      print('🔍 Verificando si el usuario ya existe...');
      final userDoc = await _firestore.collection('usuarios').doc(userId).get();
      
      if (userDoc.exists) {
        print('✅ Usuario de Microsoft ya existe, cargando datos...');
        final userData = userDoc.data()!;
        print('📊 Datos del usuario existente: $userData');
        return {
          'success': true,
          'message': 'Usuario ya registrado',
          'user': {
            'id': userId,
            'nombre': userData['nombre'] ?? nombre,
            'email': userData['email'] ?? email,
            'activo': userData['activo'] ?? true,
            'rol_activo': userData['rol_activo'] ?? 'comprador',
            'roles': userData['roles'] ?? ['comprador'],
            'fecha_registro': userData['fecha_registro'],
          }
        };
      }
      
      // Crear nuevo usuario de Microsoft
      print('📝 Creando nuevo usuario de Microsoft en Firestore...');
      final userData = {
        'nombre': nombre,
        'email': email,
        'provider': 'microsoft',
        'activo': true,
        'rol_activo': 'comprador',
        'roles': ['comprador'],
        'fecha_registro': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      print('📊 Datos a guardar: $userData');
      
      await _firestore.collection('usuarios').doc(userId).set(userData);
      
      print('✅ Usuario de Microsoft registrado exitosamente en Firestore');
      print('🆔 ID del documento: $userId');
      
      return {
        'success': true,
        'message': 'Usuario de Microsoft registrado exitosamente',
        'user': {
          'id': userId,
          'nombre': nombre,
          'email': email,
          'activo': true,
          'rol_activo': 'comprador',
          'roles': ['comprador'],
          'fecha_registro': FieldValue.serverTimestamp(),
        }
      };
    } catch (e) {
      print('❌ Error registrando usuario de Microsoft: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return {
        'success': false,
        'message': 'Error registrando usuario: ${e.toString()}',
      };
    }
  }

  static Future<bool> testConnection() async {
    try {
      await _firestore.collection('test').limit(1).get();
      print('Conexión a Firebase exitosa');
      return true;
    } catch (e) {
      print('Error conectando a Firebase: $e');
      return false;
    }
  }

  /// Método privado para enviar notificación de cambio de contraseña
  static Future<Map<String, dynamic>> _sendPasswordChangedNotification({
    required String email,
    String? userName,
  }) async {
    try {
      return await EmailService.sendPasswordChangedEmail(
        email: email,
        userName: userName,
      );
    } catch (e) {
      print('Error enviando notificación de cambio de contraseña: $e');
      return {
        'success': false,
        'message': 'Error enviando notificación: ${e.toString()}',
      };
    }
  }
}