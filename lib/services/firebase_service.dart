import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Registrar nuevo usuario con email y contraseña
  static Future<Map<String, dynamic>> registerWithEmail({
    required String nombre,
    required String email,
    required String password,
    required String rol,
  }) async {
    try {
      print('Registrando usuario: $email');
      
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Guardar datos en Firestore
        await _firestore.collection('usuarios').doc(userCredential.user!.uid).set({
          'nombre': nombre,
          'email': email,
          'activo': true,
          'rol_activo': rol,
          'roles': [rol],
          'fecha_registro': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

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
        default:
          message = 'Error de autenticación: ${e.message}';
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
        default:
          message = 'Error de autenticación: ${e.message}';
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

  /// Enviar email de recuperación de contraseña
  static Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      print('Enviando email de recuperación a: $email');
      
      await _auth.sendPasswordResetEmail(email: email);
      
      print('Email de recuperación enviado exitosamente');
      return {
        'success': true,
        'message': 'Se ha enviado un email de recuperación a $email',
      };
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
        default:
          message = 'Error: ${e.message}';
      }
      
      print('Error enviando email de recuperación: $message');
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('Error inesperado enviando email: $e');
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
}