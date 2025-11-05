import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agromarket/models/cart_item_model.dart';

class CartService {
  static const String _cartKey = 'shopping_cart';

  // Obtener todos los items del carrito
  static Future<List<CartItemModel>> getCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      
      if (cartJson == null || cartJson.isEmpty) {
        return [];
      }

      final List<dynamic> cartList = jsonDecode(cartJson);
      return cartList.map((item) => CartItemModel.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Agregar producto al carrito
  static Future<Map<String, dynamic>> addToCart(CartItemModel item) async {
    try {
      final cartItems = await getCartItems();
      
      // Verificar si el producto ya está en el carrito
      final existingItemIndex = cartItems.indexWhere(
        (cartItem) => cartItem.productId == item.productId,
      );

      if (existingItemIndex != -1) {
        // Si ya existe, actualizar la cantidad
        final existingItem = cartItems[existingItemIndex];
        cartItems[existingItemIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + item.quantity,
        );
      } else {
        // Si no existe, agregarlo
        cartItems.add(item);
      }

      // Guardar en SharedPreferences
      await _saveCartItems(cartItems);

      return {
        'success': true,
        'message': 'Producto agregado al carrito',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error agregando producto al carrito: ${e.toString()}',
      };
    }
  }

  // Actualizar cantidad de un item
  static Future<Map<String, dynamic>> updateItemQuantity(
    String productId,
    int newQuantity,
  ) async {
    try {
      if (newQuantity <= 0) {
        return await removeFromCart(productId);
      }

      final cartItems = await getCartItems();
      final itemIndex = cartItems.indexWhere(
        (item) => item.productId == productId,
      );

      if (itemIndex == -1) {
        return {
          'success': false,
          'message': 'Producto no encontrado en el carrito',
        };
      }

      cartItems[itemIndex] = cartItems[itemIndex].copyWith(quantity: newQuantity);
      await _saveCartItems(cartItems);

      return {
        'success': true,
        'message': 'Cantidad actualizada',
      };
    } catch (e) { 
      return {
        'success': false,
        'message': 'Error actualizando cantidad: ${e.toString()}',
      };
    }
  }

  // Eliminar producto del carrito
  static Future<Map<String, dynamic>> removeFromCart(String productId) async {
    try {
      final cartItems = await getCartItems();
      cartItems.removeWhere((item) => item.productId == productId);
      await _saveCartItems(cartItems);

      return {
        'success': true,
        'message': 'Producto eliminado del carrito',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error eliminando producto: ${e.toString()}',
      };
    }
  }

  // Limpiar todo el carrito
  static Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
    } catch (e) {
    }
  }

  // Obtener el total del carrito
  static Future<double> getCartTotal() async {
    try {
      final cartItems = await getCartItems();
      double total = 0.0;
      for (var item in cartItems) {
        total += item.totalPrice;
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // Obtener el número total de items (sumando cantidades)
  static Future<int> getTotalItemCount() async {
    try {
      final cartItems = await getCartItems();
      int total = 0;
      for (var item in cartItems) {
        total += item.quantity;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  // Guardar items en SharedPreferences
  static Future<void> _saveCartItems(List<CartItemModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(
        items.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(_cartKey, cartJson);
    } catch (e) {
      rethrow;
    }
  }
}

