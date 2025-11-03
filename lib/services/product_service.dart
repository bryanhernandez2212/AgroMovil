import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/product_model.dart';
import '../models/comment_model.dart';

class ProductService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<Map<String, dynamic>> saveProduct(ProductModel product) async {
    try {
      print('=== INICIANDO GUARDADO DE PRODUCTO ===');
      print('Producto a guardar: ${product.nombre}');
      print('Datos del producto: ${product.toJson()}');
      
      final User? user = _auth.currentUser;
      print('Usuario actual: ${user?.uid}');
      print('Email del usuario: ${user?.email}');
      
      if (user == null) {
        print('ERROR: Usuario no autenticado');
        return {
          'success': false,
          'message': 'Usuario no autenticado. Por favor, inicia sesión nuevamente.',
        };
      }

      final productData = product.toJson();
      print('Datos a guardar en Firestore: $productData');
      print('Probando conexión con Firestore...');
      await _firestore.collection('test').doc('connection_test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': true,
      });
      print('Conexión con Firestore exitosa');
      
      // Guardar en Firestore
      print('Guardando producto en colección "productos"...');
      final docRef = await _firestore.collection('productos').add(productData);
      print('Documento creado con ID: ${docRef.id}');
      
      // Actualizar el ID del producto
      await docRef.update({'id': docRef.id});
      print('ID actualizado en el documento');

      print('=== PRODUCTO GUARDADO EXITOSAMENTE ===');
      print('ID del producto: ${docRef.id}');
      return {
        'success': true,
        'message': 'Producto guardado exitosamente',
        'productId': docRef.id,
      };
    } catch (e) {
      print('=== ERROR GUARDANDO PRODUCTO ===');
      print('Error: $e');
      print('Stack trace: ${e.toString()}');
      return {
        'success': false,
        'message': 'Error guardando producto: ${e.toString()}',
      };
    }
  }

  // Subir imagen del producto (método individual)
  static Future<Map<String, dynamic>> uploadProductImage(File imageFile, String productName) async {
    try {
      print('Subiendo imagen para producto: $productName');
      
      // Obtener el usuario actual
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      // Crear nombre único para el archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${productName.replaceAll(' ', '_')}.jpg';
      final storageRef = _storage.ref().child('productos/${user.uid}/$fileName');

      // Subir la imagen
      print('Subiendo imagen a Firebase Storage...');
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      
      // Obtener la URL de descarga
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('Imagen subida exitosamente: $downloadUrl');
      return {
        'success': true,
        'message': 'Imagen subida exitosamente',
        'imageUrl': downloadUrl,
      };
    } catch (e) {
      print('Error subiendo imagen: $e');
      return {
        'success': false,
        'message': 'Error subiendo imagen: ${e.toString()}',
      };
    }
  }

  // Subir múltiples imágenes del producto (hasta 5)
  static Future<Map<String, dynamic>> uploadProductImages(List<File> imageFiles, String productName, String productId) async {
    try {
      print('Subiendo ${imageFiles.length} imágenes para producto: $productName');
      
      // Validar que no exceda el límite de 5 imágenes
      if (imageFiles.length > 5) {
        return {
          'success': false,
          'message': 'Máximo 5 imágenes permitidas',
        };
      }
      
      // Obtener el usuario actual
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      List<String> imageUrls = [];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Subir cada imagen
      for (int i = 0; i < imageFiles.length; i++) {
        final fileName = 'imagen_${i}_$timestamp.jpg';
        final storageRef = _storage.ref().child('productos/$productId/$fileName');

        print('Subiendo imagen ${i + 1}/${imageFiles.length} a Firebase Storage...');
        final uploadTask = storageRef.putFile(imageFiles[i]);
        final snapshot = await uploadTask;
        
        // Obtener la URL de descarga
        final downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
        
        print('Imagen ${i + 1} subida exitosamente: $downloadUrl');
      }

      print('Todas las imágenes subidas exitosamente. Total: ${imageUrls.length}');
      return {
        'success': true,
        'message': 'Imágenes subidas exitosamente',
        'imageUrls': imageUrls,
      };
    } catch (e) {
      print('Error subiendo imágenes: $e');
      return {
        'success': false,
        'message': 'Error subiendo imágenes: ${e.toString()}',
      };
    }
  }

  // Obtener productos del vendedor actual
  static Future<List<ProductModel>> getProductsBySeller() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('productos')
          .where('vendedor_id', isEqualTo: user.uid)
          .get();

      // Ordenar en memoria después de obtener los datos
      final products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ProductModel.fromJson(data);
      }).toList();

      // Ordenar por fecha de publicación descendente
      products.sort((a, b) => b.fechaPublicacion.compareTo(a.fechaPublicacion));

      return products;
    } catch (e) {
      print('Error obteniendo productos: $e');
      return [];
    }
  }

  // Obtener todos los productos activos
  static Future<List<ProductModel>> getAllActiveProducts() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('productos')
          .where('activo', isEqualTo: true)
          .get();

      // Ordenar en memoria después de obtener los datos
      final products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ProductModel.fromJson(data);
      }).toList();

      // Ordenar por fecha de publicación descendente
      products.sort((a, b) => b.fechaPublicacion.compareTo(a.fechaPublicacion));

      return products;
    } catch (e) {
      print('Error obteniendo productos activos: $e');
      return [];
    }
  }

  // Actualizar producto
  static Future<Map<String, dynamic>> updateProduct(String productId, ProductModel product) async {
    try {
      await _firestore.collection('productos').doc(productId).update(product.toJson());
      
      return {
        'success': true,
        'message': 'Producto actualizado exitosamente',
      };
    } catch (e) {
      print('Error actualizando producto: $e');
      return {
        'success': false,
        'message': 'Error actualizando producto: ${e.toString()}',
      };
    }
  }

  // Eliminar producto
  static Future<Map<String, dynamic>> deleteProduct(String productId) async {
    try {
      await _firestore.collection('productos').doc(productId).delete();
      
      return {
        'success': true,
        'message': 'Producto eliminado exitosamente',
      };
    } catch (e) {
      print('Error eliminando producto: $e');
      return {
        'success': false,
        'message': 'Error eliminando producto: ${e.toString()}',
      };
    }
  }

  // Obtener categorías disponibles
  static Future<List<String>> getCategories() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('categorias').get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => doc.id).toList();
      } else {
        // Categorías por defecto si no hay en la base de datos
        return ['frutas', 'verduras', 'semillas'];
      }
    } catch (e) {
      print('Error obteniendo categorías: $e');
      // Categorías por defecto si hay error
      return ['frutas', 'verduras', 'semillas'];
    }
  }

  // Obtener unidades disponibles
  static List<String> getUnits() {
    return ['kg', 'g', 'lb', 'oz', 'unidad', 'docena', 'caja', 'bolsa'];
  }

  // Obtener comentarios de un producto
  static Future<List<CommentModel>> getProductComments(String productId) async {
    try {
      print('📖 Obteniendo comentarios del producto: $productId');
      
      final QuerySnapshot snapshot = await _firestore
          .collection('productos')
          .doc(productId)
          .collection('comentarios')
          .orderBy('fecha_creacion', descending: true)
          .get();

      print('   - Total de comentarios encontrados: ${snapshot.docs.length}');

      final comments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final comment = CommentModel.fromJson(data);
        print('   - Comentario ID: ${comment.id}, Usuario: ${comment.userName}, Calificación: ${comment.calificacion}');
        return comment;
      }).toList();

      return comments;
    } catch (e, stackTrace) {
      print('❌ Error obteniendo comentarios: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Agregar comentario a un producto
  static Future<Map<String, dynamic>> addComment(
    String productId,
    String comentario,
    double calificacion,
  ) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      // Validar calificación
      if (calificacion < 1.0 || calificacion > 5.0) {
        return {
          'success': false,
          'message': 'La calificación debe estar entre 1 y 5',
        };
      }

      // Obtener nombre del usuario de Firestore si está disponible
      String userName = user.displayName ?? 'Usuario';
      try {
        final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          userName = userData?['nombre'] ?? user.displayName ?? 'Usuario';
        }
      } catch (e) {
        print('No se pudo obtener nombre del usuario de Firestore: $e');
      }

      final commentData = {
        'id': '', // Se actualizará después
        'producto_id': productId,
        'usuario_id': user.uid,
        'usuario_nombre': userName,
        'usuario_email': user.email ?? '',
        'comentario': comentario.trim(),
        'calificacion': calificacion,
        'fecha_creacion': FieldValue.serverTimestamp(),
      };

      print('💬 Guardando comentario en Firestore...');
      print('   - Producto ID: $productId');
      print('   - Usuario: $userName (${user.email})');
      print('   - Calificación: $calificacion');
      print('   - Comentario: ${comentario.substring(0, comentario.length > 50 ? 50 : comentario.length)}...');

      // Guardar comentario en la subcolección
      // Estructura: productos/{productId}/comentarios/{commentId}
      final docRef = await _firestore
          .collection('productos')
          .doc(productId)
          .collection('comentarios')
          .add(commentData);

      // Actualizar ID del comentario
      await docRef.update({'id': docRef.id});

      print('✅ Comentario guardado exitosamente con ID: ${docRef.id}');
      print('   - Ruta: productos/$productId/comentarios/${docRef.id}');

      // Recalcular calificación promedio del producto
      await _updateProductRating(productId);

      return {
        'success': true,
        'message': 'Comentario agregado exitosamente',
        'commentId': docRef.id,
      };
    } catch (e, stackTrace) {
      print('❌ Error agregando comentario: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error agregando comentario: ${e.toString()}',
      };
    }
  }

  // Obtener información completa del vendedor
  static Future<Map<String, dynamic>> getVendorInfo(String vendorId) async {
    try {
      // Obtener datos del usuario/vendedor
      final userDoc = await _firestore.collection('usuarios').doc(vendorId).get();
      
      Map<String, dynamic> vendorData = {
        'nombre': '',
        'email': '',
        'ubicacion': '',
        'totalProductos': 0,
      };
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        vendorData['nombre'] = userData['nombre'] ?? '';
        vendorData['email'] = userData['email'] ?? '';
        vendorData['ubicacion'] = userData['ubicacion'] ?? userData['direccion'] ?? 'No especificada';
      }
      
      // Contar productos activos del vendedor
      final productsSnapshot = await _firestore
          .collection('productos')
          .where('vendedor_id', isEqualTo: vendorId)
          .where('activo', isEqualTo: true)
          .get();
      
      vendorData['totalProductos'] = productsSnapshot.docs.length;
      
      return vendorData;
    } catch (e) {
      print('Error obteniendo información del vendedor: $e');
      return {
        'nombre': '',
        'email': '',
        'ubicacion': 'No disponible',
        'totalProductos': 0,
      };
    }
  }

  // Actualizar calificación promedio del producto
  static Future<void> _updateProductRating(String productId) async {
    try {
      print('⭐ Recalculando calificación promedio del producto: $productId');
      
      final comments = await getProductComments(productId);
      
      if (comments.isEmpty) {
        print('   - No hay comentarios, estableciendo calificación a 0');
        await _firestore.collection('productos').doc(productId).update({
          'calificacion_promedio': 0.0,
          'total_calificaciones': 0,
        });
        return;
      }

      double sumaCalificaciones = 0.0;
      for (var comment in comments) {
        sumaCalificaciones += comment.calificacion;
      }

      final promedio = sumaCalificaciones / comments.length;

      print('   - Calificación promedio: ${promedio.toStringAsFixed(2)}');
      print('   - Total de calificaciones: ${comments.length}');

      await _firestore.collection('productos').doc(productId).update({
        'calificacion_promedio': promedio,
        'total_calificaciones': comments.length,
      });

      print('✅ Calificación actualizada en el producto');
    } catch (e, stackTrace) {
      print('❌ Error actualizando calificación: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
