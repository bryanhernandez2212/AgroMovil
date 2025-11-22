import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:agromarket/models/solicitud_vendedor_model.dart';

class VendorRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crear una solicitud de vendedor
  static Future<Map<String, dynamic>> createVendorRequest({
    required String nombre,
    required String email,
    required String password,
    required String nombreTienda,
    required String ubicacion,
    String? ubicacionFormatted,
    double? ubicacionLat,
    double? ubicacionLng,
    required File documentoFile,
  }) async {
    try {
      print('📝 VendorRequestService: Creando solicitud de vendedor para $email');

      // 1. Crear usuario en Firebase Auth PRIMERO (necesario para subir archivos)
      print('🔐 Creando usuario en Firebase Auth...');
      String? userId;
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        userId = userCredential.user?.uid;
        print('✅ Usuario creado en Firebase Auth: $userId');
        
        // Esperar a que el token de autenticación esté disponible
        // Esto es importante en móvil para asegurar que el token esté listo
        if (userCredential.user != null) {
          print('⏳ Esperando token de autenticación...');
          await userCredential.user!.reload();
          // Obtener el token para forzar la actualización
          await userCredential.user!.getIdToken(true);
          print('✅ Token de autenticación listo');
        }
      } catch (e) {
        print('❌ Error creando usuario en Firebase Auth: $e');
        // Si el email ya existe, intentar obtener el usuario
        if (e.toString().contains('email-already-in-use')) {
          try {
            final signInCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
            final user = signInCredential.user;
            if (user != null) {
              userId = user.uid;
              // Asegurar que el token esté disponible
              await user.reload();
              await user.getIdToken(true);
              print('✅ Usuario existente autenticado: $userId');
            }
          } catch (signInError) {
            return {
              'success': false,
              'message': 'El email ya está registrado. Por favor, inicia sesión.',
            };
          }
        } else {
          return {
            'success': false,
            'message': 'Error al crear la cuenta: ${e.toString()}',
          };
        }
      }

      // Verificar que el usuario esté autenticado antes de subir
      final currentUser = _auth.currentUser;
      if (userId == null || currentUser == null) {
        return {
          'success': false,
          'message': 'Error: No se pudo autenticar al usuario para subir el documento',
        };
      }
      
      // Verificar que el userId coincida con el usuario actual
      if (currentUser.uid != userId) {
        print('⚠️ Advertencia: userId no coincide con usuario actual');
        userId = currentUser.uid; // Usar el ID del usuario actual
      }
      
      // Verificar que el token esté disponible (importante en móvil)
      try {
        final token = await currentUser.getIdToken();
        if (token == null || token.isEmpty) {
          print('⚠️ Token vacío, esperando un momento...');
          await Future.delayed(const Duration(milliseconds: 500));
          await currentUser.getIdToken(true); // Forzar refresh
        }
        print('✅ Token de autenticación verificado');
      } catch (tokenError) {
        print('⚠️ Error obteniendo token: $tokenError');
        // Continuar de todas formas, el token podría estar disponible
      }
      
      print('✅ Usuario autenticado confirmado: ${currentUser.uid}');

      // 2. Subir el documento a Firebase Storage (ahora con usuario autenticado)
      print('📤 Subiendo documento de verificación...');
      String? documentoUrl;
      try {
        documentoUrl = await _uploadDocument(documentoFile, email, userId);
        
        if (documentoUrl == null) {
          // Si falla la subida, limpiar el usuario creado
          if (_auth.currentUser != null) {
            await _auth.currentUser!.delete();
            await _auth.signOut();
          }
          return {
            'success': false,
            'message': 'Error al subir el documento de verificación',
          };
        }
        print('✅ Documento subido exitosamente: $documentoUrl');
      } catch (uploadError) {
        print('❌ Error subiendo documento: $uploadError');
        // Si falla la subida, limpiar el usuario creado
        try {
          if (_auth.currentUser != null) {
            await _auth.currentUser!.delete();
            await _auth.signOut();
          }
        } catch (deleteError) {
          print('⚠️ Error eliminando usuario después de fallo en subida: $deleteError');
        }
        return {
          'success': false,
          'message': 'Error al subir el documento: ${uploadError.toString()}',
        };
      }

      // 3. Verificar si ya existe una solicitud para este email (opcional pero recomendado)
      print('🔍 Verificando solicitudes existentes...');
      try {
        final existentes = await _firestore
            .collection('solicitudes_vendedores')
            .where('email', isEqualTo: email)
            .get();

        bool existePendienteOAprobada = false;
        for (var doc in existentes.docs) {
          final estado = (doc.data()['estado'] ?? 'pendiente').toString().toLowerCase();
          if (estado == 'pendiente' || estado == 'aprobada') {
            existePendienteOAprobada = true;
            break;
          }
        }

        if (existePendienteOAprobada) {
          // Limpiar usuario creado
          if (_auth.currentUser != null) {
            await _auth.currentUser!.delete();
            await _auth.signOut();
          }
          return {
            'success': false,
            'message': 'Ya existe una solicitud asociada a este correo electrónico',
          };
        }
      } catch (e) {
        print('⚠️ Error verificando solicitudes existentes: $e');
        // Continuar de todas formas
      }

      // 4. Guardar la solicitud en Firestore
      // ⚠️ IMPORTANTE: Usar doc(userId).set() NO add()
      // El ID del documento DEBE ser el user.uid para que el admin lo encuentre
      print('💾 Guardando solicitud en Firestore...');
      final solicitudData = {
        'user_id': userId, // ← Debe coincidir con el ID del documento
        'nombre': nombre,
        'email': email,
        'password_hash': null, // No guardamos la contraseña en la solicitud
        'nombre_tienda': nombreTienda,
        'ubicacion': ubicacion,
        'ubicacion_formatted': ubicacionFormatted ?? ubicacion,
        'ubicacion_lat': ubicacionLat,
        'ubicacion_lng': ubicacionLng,
        'documento_url': documentoUrl,
        'estado': 'pendiente',
        'fecha_solicitud': FieldValue.serverTimestamp(),
        'fecha_revision': null,
        'revisado_por': null,
        'motivo_rechazo': null,
      };

      // ✅ CORRECTO: usar doc(userId).set() NO add()
      await _firestore
          .collection('solicitudes_vendedores')
          .doc(userId) // ← El ID del documento ES el user.uid
          .set(solicitudData);

      print('✅ Solicitud guardada exitosamente con ID: $userId');

      // 4. Cerrar sesión del usuario temporal (no debe iniciar sesión hasta que se apruebe)
      if (_auth.currentUser != null) {
        await _auth.signOut();
        print('🔒 Sesión cerrada. El usuario deberá esperar aprobación.');
      }

      return {
        'success': true,
        'message': 'Solicitud enviada exitosamente. Te notificaremos cuando sea revisada.',
        'solicitudId': userId, // El ID de la solicitud es el user.uid
      };
    } catch (e) {
      print('❌ Error creando solicitud de vendedor: $e');
      return {
        'success': false,
        'message': 'Error al crear la solicitud: ${e.toString()}',
      };
    }
  }

  /// Subir documento de verificación a Firebase Storage
  static Future<String?> _uploadDocument(File documentoFile, String email, String userId) async {
    try {
      // Validar tamaño del archivo (máx. 5MB)
      final fileSize = await documentoFile.length();
      const maxSize = 5 * 1024 * 1024; // 5MB en bytes
      
      if (fileSize > maxSize) {
        throw Exception('El archivo es demasiado grande. Máximo 5MB permitido.');
      }

      // Validar extensión del archivo
      final fileName = documentoFile.path.split('/').last.toLowerCase();
      final extension = fileName.split('.').last;
      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(extension)) {
        throw Exception('Formato no permitido. Solo se permiten JPG, PNG o PDF.');
      }

      // Verificar que el usuario esté autenticado
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado. No se puede subir el documento.');
      }

      // Verificar token antes de subir (importante en móvil)
      try {
        final token = await currentUser.getIdToken();
        print('🔑 Token disponible: ${token != null && token.isNotEmpty}');
        if (token == null || token.isEmpty) {
          print('⚠️ Token vacío, forzando refresh...');
          await currentUser.getIdToken(true);
        }
      } catch (tokenError) {
        print('⚠️ Error verificando token antes de subir: $tokenError');
        // Continuar de todas formas
      }

      // Crear referencia en Storage usando el userId
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageFileName = 'documento_${timestamp}_$fileName';
      final storagePath = 'verificaciones_vendedores/$userId/$storageFileName';
      final storageRef = _storage.ref().child(storagePath);

      print('📤 Subiendo documento a: $storagePath');
      print('👤 Usuario autenticado: ${currentUser.uid}');
      print('📏 Tamaño del archivo: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Subir el archivo
      print('⏳ Iniciando upload...');
      final uploadTask = storageRef.putFile(documentoFile);
      
      // Escuchar el progreso para debugging
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📊 Progreso: ${progress.toStringAsFixed(1)}%');
      });
      
      final snapshot = await uploadTask;
      print('✅ Upload completado');

      // Obtener URL de descarga
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('✅ Documento subido exitosamente: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Error subiendo documento: $e');
      rethrow;
    }
  }

  /// Obtener solicitud por ID
  static Future<SolicitudVendedorModel?> getSolicitudById(String solicitudId) async {
    try {
      final doc = await _firestore
          .collection('solicitudes_vendedores')
          .doc(solicitudId)
          .get();

      if (doc.exists) {
        return SolicitudVendedorModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error obteniendo solicitud: $e');
      return null;
    }
  }

  /// Obtener solicitud por email
  static Future<SolicitudVendedorModel?> getSolicitudByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('solicitudes_vendedores')
          .where('email', isEqualTo: email)
          .orderBy('fecha_solicitud', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return SolicitudVendedorModel.fromJson(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      print('Error obteniendo solicitud por email: $e');
      return null;
    }
  }
}

