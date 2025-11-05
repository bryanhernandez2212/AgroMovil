import 'package:flutter/material.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:agromarket/models/product_model.dart';
import 'package:agromarket/services/cart_service.dart';
import 'package:agromarket/services/stock_service.dart';

class CartController extends ChangeNotifier {
  List<CartItemModel> _cartItems = [];
  bool _isLoading = false;

  List<CartItemModel> get cartItems => _cartItems;
  bool get isLoading => _isLoading;
  bool get isEmpty => _cartItems.isEmpty;

  // Calcular el total del carrito
  double get totalPrice {
    return _cartItems.fold(0.0, (total, item) => total + item.totalPrice);
  }

  // Calcular el total de items (sumando cantidades)
  int get totalItemCount {
    return _cartItems.fold(0, (total, item) => total + item.quantity);
  }

  CartController() {
    loadCart();
  }

  // Cargar carrito desde almacenamiento
  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      _cartItems = await CartService.getCartItems();
      
      // Verificar y limpiar productos sin stock
      final itemsToRemove = <String>[];
      
      for (var item in _cartItems) {
        final stockValidation = await StockService.validateStock(item.productId, item.quantity);
        
        if (!stockValidation['success']) {
          print('⚠️ Producto ${item.productName} sin stock, eliminando del carrito');
          itemsToRemove.add(item.productId);
        }
      }
      
      // Eliminar productos sin stock
      if (itemsToRemove.isNotEmpty) {
        for (var productId in itemsToRemove) {
          await CartService.removeFromCart(productId);
        }
        // Recargar carrito después de limpiar
        _cartItems = await CartService.getCartItems();
      }
    } catch (e) {
      print('❌ Error cargando carrito: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Agregar producto al carrito
  Future<Map<String, dynamic>> addToCart(ProductModel product, int quantity) async {
    try {
      // Validar stock antes de agregar al carrito
      final stockValidation = await StockService.validateStock(product.id, quantity);
      
      if (!stockValidation['success']) {
        return {
          'success': false,
          'message': stockValidation['message'] ?? 'Stock insuficiente',
          'available': stockValidation['available'] ?? 0,
        };
      }

      final cartItem = CartItemModel.fromProduct(product, quantity);
      final result = await CartService.addToCart(cartItem);

      if (result['success']) {
        await loadCart(); // Recargar carrito
        return result;
      } else {
        return result;
      }
    } catch (e) {
      print('❌ Error agregando al carrito: $e');
      return {
        'success': false,
        'message': 'Error agregando producto: ${e.toString()}',
      };
    }
  }

  // Actualizar cantidad de un item
  Future<Map<String, dynamic>> updateQuantity(String productId, int newQuantity) async {
    try {
      if (newQuantity <= 0) {
        return await removeFromCart(productId);
      }

      // Validar stock antes de actualizar cantidad
      final stockValidation = await StockService.validateStock(productId, newQuantity);
      
      if (!stockValidation['success']) {
        return {
          'success': false,
          'message': stockValidation['message'] ?? 'Stock insuficiente',
          'available': stockValidation['available'] ?? 0,
        };
      }

      final result = await CartService.updateItemQuantity(productId, newQuantity);
      
      if (result['success']) {
        await loadCart(); // Recargar carrito
      }
      
      return result;
    } catch (e) {
      print('❌ Error actualizando cantidad: $e');
      return {
        'success': false,
        'message': 'Error actualizando cantidad: ${e.toString()}',
      };
    }
  }

  // Eliminar producto del carrito
  Future<Map<String, dynamic>> removeFromCart(String productId) async {
    try {
      final result = await CartService.removeFromCart(productId);
      
      if (result['success']) {
        await loadCart(); // Recargar carrito
      }
      
      return result;
    } catch (e) {
      print('❌ Error eliminando del carrito: $e');
      return {
        'success': false,
        'message': 'Error eliminando producto: ${e.toString()}',
      };
    }
  }

  // Limpiar todo el carrito
  Future<void> clearCart() async {
    try {
      await CartService.clearCart();
      await loadCart(); // Recargar carrito
    } catch (e) {
      print('❌ Error limpiando carrito: $e');
    }
  }
}

