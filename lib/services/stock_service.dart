import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agromarket/models/product_model.dart';

class StockService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtener el stock actual de un producto desde Firestore
  static Future<Map<String, dynamic>> getProductStock(String productId) async {
    try {
      final doc = await _firestore.collection('productos').doc(productId).get();
      
      if (!doc.exists) {
        return {
          'success': false,
          'message': 'Producto no encontrado',
          'stock': 0,
        };
      }

      final data = doc.data()!;
      final stock = data['stock'] ?? 0;
      final activo = data['activo'] ?? true;

      return {
        'success': true,
        'stock': stock is int ? stock : int.tryParse(stock.toString()) ?? 0,
        'activo': activo,
        'product': ProductModel.fromJson({...data, 'id': doc.id}),
      };
    } catch (e) {
      print('❌ StockService: Error obteniendo stock: $e');
      return {
        'success': false,
        'message': 'Error obteniendo stock: ${e.toString()}',
        'stock': 0,
      };
    }
  }

  /// Validar si hay stock suficiente para una cantidad específica
  static Future<Map<String, dynamic>> validateStock(
    String productId,
    int requestedQuantity,
  ) async {
    try {
      final stockResult = await getProductStock(productId);
      
      if (!stockResult['success']) {
        return {
          'success': false,
          'message': stockResult['message'] ?? 'Error validando stock',
          'available': 0,
          'requested': requestedQuantity,
        };
      }

      final availableStock = stockResult['stock'] as int;
      final activo = stockResult['activo'] as bool;

      if (!activo) {
        return {
          'success': false,
          'message': 'El producto no está disponible',
          'available': availableStock,
          'requested': requestedQuantity,
        };
      }

      if (availableStock == 0) {
        return {
          'success': false,
          'message': 'Producto agotado',
          'available': 0,
          'requested': requestedQuantity,
        };
      }

      if (requestedQuantity > availableStock) {
        return {
          'success': false,
          'message': 'Stock insuficiente. Disponible: $availableStock',
          'available': availableStock,
          'requested': requestedQuantity,
        };
      }

      return {
        'success': true,
        'message': 'Stock disponible',
        'available': availableStock,
        'requested': requestedQuantity,
      };
    } catch (e) {
      print('❌ StockService: Error validando stock: $e');
      return {
        'success': false,
        'message': 'Error validando stock: ${e.toString()}',
        'available': 0,
        'requested': requestedQuantity,
      };
    }
  }

  /// Actualizar el stock de un producto después de una compra
  static Future<Map<String, dynamic>> updateStock(
    String productId,
    int quantitySold,
  ) async {
    try {
      // Verificar que el usuario esté autenticado
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ StockService: Usuario no autenticado');
        return {
          'success': false,
          'message': 'Usuario no autenticado. Por favor inicia sesión.',
        };
      }

      print('📦 StockService: Actualizando stock para producto $productId');
      print('   - Usuario autenticado: ${user.uid}');
      print('   - Cantidad vendida: $quantitySold');

      final docRef = _firestore.collection('productos').doc(productId);
      
      // Primero obtener el stock actual para validar
      final doc = await docRef.get();
      
      if (!doc.exists) {
        return {
          'success': false,
          'message': 'Producto no encontrado',
        };
      }

      final data = doc.data()!;
      final currentStock = data['stock'] is int 
          ? data['stock'] as int 
          : int.tryParse(data['stock'].toString()) ?? 0;
      final currentVendido = data['vendido'] is int 
          ? data['vendido'] as int 
          : int.tryParse(data['vendido'].toString()) ?? 0;

      // Validar que hay stock suficiente
      if (currentStock < quantitySold) {
        return {
          'success': false,
          'message': 'Stock insuficiente. Disponible: $currentStock, Solicitado: $quantitySold',
        };
      }

      final newStock = currentStock - quantitySold;
      final newVendido = currentVendido + quantitySold;

      print('   - Stock actual: $currentStock');
      print('   - Stock nuevo: $newStock');
      print('   - Vendido anterior: $currentVendido');
      print('   - Vendido nuevo: $newVendido');

      // Usar FieldValue.increment para operaciones atómicas (más eficiente que transacciones)
      await docRef.update({
        'stock': FieldValue.increment(-quantitySold),
        'vendido': FieldValue.increment(quantitySold),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Stock actualizado exitosamente',
        'oldStock': currentStock,
        'newStock': newStock,
        'oldVendido': currentVendido,
        'newVendido': newVendido,
      };
    } catch (e) {
      print('❌ StockService: Error actualizando stock: $e');
      return {
        'success': false,
        'message': 'Error actualizando stock: ${e.toString()}',
      };
    }
  }

  /// Validar y actualizar stock para múltiples productos (para una orden completa)
  static Future<Map<String, dynamic>> validateAndUpdateStockForOrder(
    Map<String, int> products, // {productId: quantity}
  ) async {
    try {
      print('📦 StockService: Validando stock para orden completa');
      print('   - Productos: ${products.length}');

      // Primero validar todo el stock
      final validationResults = <String, Map<String, dynamic>>{};
      
      for (var entry in products.entries) {
        final productId = entry.key;
        final quantity = entry.value;
        
        final validation = await validateStock(productId, quantity);
        validationResults[productId] = validation;
        
        if (!validation['success']) {
          print('❌ StockService: Producto $productId no tiene stock suficiente');
          return {
            'success': false,
            'message': validation['message'] ?? 'Stock insuficiente',
            'productId': productId,
            'available': validation['available'],
            'requested': validation['requested'],
          };
        }
      }

      // Si todo está bien, actualizar el stock para todos los productos
      final updateResults = <String, Map<String, dynamic>>{};
      
      for (var entry in products.entries) {
        final productId = entry.key;
        final quantity = entry.value;
        
        final updateResult = await updateStock(productId, quantity);
        updateResults[productId] = updateResult;
        
        if (!updateResult['success']) {
          print('❌ StockService: Error actualizando stock para $productId');
          // Intentar revertir los cambios anteriores
          // (Por simplicidad, aquí solo reportamos el error)
          return {
            'success': false,
            'message': updateResult['message'] ?? 'Error actualizando stock',
            'productId': productId,
            'updateResults': updateResults,
          };
        }
      }

      print('✅ StockService: Stock validado y actualizado para todos los productos');
      return {
        'success': true,
        'message': 'Stock actualizado exitosamente',
        'updateResults': updateResults,
      };
    } catch (e) {
      print('❌ StockService: Error en validación/actualización de stock: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Verificar productos sin stock en el carrito y devolver lista de productos no disponibles
  static Future<List<Map<String, dynamic>>> checkCartItemsStock(
    List<Map<String, dynamic>> cartItems, // [{productId, quantity}, ...]
  ) async {
    final unavailableItems = <Map<String, dynamic>>[];
    
    for (var item in cartItems) {
      final productId = item['productId'] as String;
      final quantity = item['quantity'] as int;
      
      final validation = await validateStock(productId, quantity);
      
      if (!validation['success']) {
        unavailableItems.add({
          'productId': productId,
          'productName': item['productName'] ?? 'Producto desconocido',
          'quantity': quantity,
          'available': validation['available'] ?? 0,
          'message': validation['message'] ?? 'Producto no disponible',
        });
      }
    }
    
    return unavailableItems;
  }
}

