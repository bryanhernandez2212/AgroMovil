import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/product_model.dart';

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

  // Subir imagen del producto
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
}
