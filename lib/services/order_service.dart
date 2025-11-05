import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agromarket/models/order_model.dart';
import 'package:agromarket/services/stock_service.dart';

class OrderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Guardar orden en Firestore
  static Future<Map<String, dynamic>> saveOrder(OrderModel order) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      print('💾 Guardando orden en Firestore...');
      print('   - Total: \$${order.total.toStringAsFixed(2)}');
      print('   - Productos: ${order.productos.length}');
      print('   - Ciudad: ${order.ciudad}');
      print('   - Teléfono: ${order.telefono}');
      print('   - Formatted: ${order.formatted}');
      print('   - Dirección entrega: ${order.direccionEntrega ?? "No especificada"}');

      // Crear documento en la colección 'compras'
      final orderData = order.toJson();
      orderData['fecha_compra'] = FieldValue.serverTimestamp();
      orderData['fecha_creacion'] = order.fechaCreacion.toIso8601String();

      // Asegurar que formatted siempre esté presente y tenga el formato correcto
      if (!orderData.containsKey('formatted') || orderData['formatted'] == null || orderData['formatted'].toString().isEmpty) {
        orderData['formatted'] = '${order.ciudad} (Tel: ${order.telefono})';
        print('⚠️ Formatted no estaba presente, se agregó: ${orderData['formatted']}');
      }

      // Verificar que formatted tenga el formato correcto: "Ciudad (Tel: XXXXXXXXXX)"
      final formattedValue = orderData['formatted'].toString();
      if (!formattedValue.contains('(Tel:') || !formattedValue.contains(order.telefono)) {
        orderData['formatted'] = '${order.ciudad} (Tel: ${order.telefono})';
        print('⚠️ Formatted no tenía el formato correcto, se corrigió: ${orderData['formatted']}');
      }

      // Remover direccion_entrega si está vacío o null (según el formato correcto)
      if (orderData.containsKey('direccion_entrega') && 
          (orderData['direccion_entrega'] == null || orderData['direccion_entrega'].toString().isEmpty)) {
        orderData.remove('direccion_entrega');
        print('ℹ️ direccion_entrega estaba vacía, se removió del documento');
      }

      print('📦 Datos que se guardarán:');
      print('   - formatted: ${orderData['formatted']}');
      if (orderData.containsKey('direccion_entrega')) {
        print('   - direccion_entrega: ${orderData['direccion_entrega']}');
      } else {
        print('   - direccion_entrega: (no se guardará - formato correcto)');
      }
      print('   - ciudad: ${orderData['ciudad']}');
      print('   - telefono: ${orderData['telefono']}');

      // Validar y actualizar stock antes de guardar la orden
      print('📦 Validando y actualizando stock para la orden...');
      final productsToUpdate = <String, int>{};
      for (var producto in order.productos) {
        productsToUpdate[producto.productoId] = producto.cantidad;
      }

      final stockResult = await StockService.validateAndUpdateStockForOrder(productsToUpdate);
      
      if (!stockResult['success']) {
        print('❌ Error validando/actualizando stock: ${stockResult['message']}');
        return {
          'success': false,
          'message': stockResult['message'] ?? 'Error validando stock',
        };
      }

      print('✅ Stock validado y actualizado exitosamente');

      // Guardar en Firestore
      final docRef = await _firestore.collection('compras').add(orderData);

      // Actualizar el ID de la orden
      await docRef.update({'id': docRef.id});

      print('✅ Orden guardada exitosamente con ID: ${docRef.id}');
      print('   - Ruta: compras/${docRef.id}');

      final updatedOrder = OrderModel(
        id: docRef.id,
        usuarioId: order.usuarioId,
        usuarioNombre: order.usuarioNombre,
        usuarioEmail: order.usuarioEmail,
        ciudad: order.ciudad,
        telefono: order.telefono,
        direccionEntrega: order.direccionEntrega,
        formatted: order.formatted,
        envio: order.envio,
        subtotal: order.subtotal,
        impuestos: order.impuestos,
        total: order.total,
        estado: order.estado,
        estadoPedido: order.estadoPedido,
        metodoPago: order.metodoPago,
        paymentIntentId: order.paymentIntentId,
        fechaCompra: order.fechaCompra,
        fechaCreacion: order.fechaCreacion,
        fechaActualizacionEstado: order.fechaActualizacionEstado,
        productos: order.productos,
      );

      return {
        'success': true,
        'message': 'Orden guardada exitosamente',
        'orderId': docRef.id,
        'order': updatedOrder,
      };
    } catch (e, stackTrace) {
      print('❌ Error guardando orden: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error guardando orden: ${e.toString()}',
      };
    }
  }

  // Obtener órdenes del usuario actual
  static Future<List<OrderModel>> getUserOrders() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        print('⚠️ OrderService: Usuario no autenticado');
        return [];
      }

      print('📦 OrderService: Obteniendo órdenes para usuario: ${user.uid}');

      QuerySnapshot snapshot;
      try {
        // Intentar con ordenamiento
        snapshot = await _firestore
            .collection('compras')
            .where('usuario_id', isEqualTo: user.uid)
            .orderBy('fecha_compra', descending: true)
            .get();
      } catch (e) {
        // Si falla por falta de índice, intentar sin ordenamiento
        print('⚠️ OrderService: Error con ordenamiento, intentando sin orden: $e');
        snapshot = await _firestore
            .collection('compras')
            .where('usuario_id', isEqualTo: user.uid)
            .get();
      }

      print('📦 OrderService: Se encontraron ${snapshot.docs.length} órdenes');
      
      // Convertir documentos a lista y ordenar manualmente si es necesario
      var docs = snapshot.docs.toList();
      if (docs.length > 1) {
        // Ordenar manualmente por fecha si no se pudo ordenar en la consulta
        docs.sort((a, b) {
          final fechaA = a.data() as Map<String, dynamic>;
          final fechaB = b.data() as Map<String, dynamic>;
          final timestampA = fechaA['fecha_compra'];
          final timestampB = fechaB['fecha_compra'];
          
          if (timestampA == null && timestampB == null) return 0;
          if (timestampA == null) return 1;
          if (timestampB == null) return -1;
          
          DateTime dateA;
          DateTime dateB;
          
          if (timestampA is Timestamp) {
            dateA = timestampA.toDate();
          } else if (timestampA is String) {
            dateA = DateTime.tryParse(timestampA) ?? DateTime.now();
          } else {
            return 1;
          }
          
          if (timestampB is Timestamp) {
            dateB = timestampB.toDate();
          } else if (timestampB is String) {
            dateB = DateTime.tryParse(timestampB) ?? DateTime.now();
          } else {
            return -1;
          }
          
          return dateB.compareTo(dateA);
        });
      }

      final orders = <OrderModel>[];
      for (var doc in docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          
          print('📦 OrderService: Procesando orden ${doc.id}');
          print('   - usuario_id: ${data['usuario_id']}');
          print('   - total: ${data['total']}');
          print('   - productos: ${data['productos'] != null ? (data['productos'] as List).length : 0}');
          
          final order = OrderModel.fromJson(data);
          orders.add(order);
          print('✅ OrderService: Orden ${doc.id} procesada correctamente');
        } catch (e, stackTrace) {
          print('❌ OrderService: Error procesando orden ${doc.id}: $e');
          print('Stack trace: $stackTrace');
          // Continuar con las demás órdenes
        }
      }

      print('✅ OrderService: Total de órdenes procesadas: ${orders.length}');
      return orders;
    } catch (e, stackTrace) {
      print('❌ OrderService: Error obteniendo órdenes: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
}

// Extensión para crear copia con ID actualizado
extension OrderModelExtension on OrderModel {
  OrderModel copyWith({String? id}) {
    return OrderModel(
      id: id ?? this.id,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      usuarioEmail: usuarioEmail,
      ciudad: ciudad,
      telefono: telefono,
      direccionEntrega: direccionEntrega,
      formatted: formatted,
      envio: envio,
      subtotal: subtotal,
      impuestos: impuestos,
      total: total,
      estado: estado,
      estadoPedido: estadoPedido,
      metodoPago: metodoPago,
      paymentIntentId: paymentIntentId,
      fechaCompra: fechaCompra,
      fechaCreacion: fechaCreacion,
      fechaActualizacionEstado: fechaActualizacionEstado,
      productos: productos,
    );
  }
}

