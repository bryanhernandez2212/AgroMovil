import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartService {
  static const String _cartKeyPrefix = 'shopping_cart_';
  static const String _oldCartKey = 'shopping_cart'; // Clave antigua para migración

  // Obtener la clave del carrito para un usuario específico
  static String _getCartKey(String? userId) {
    if (userId == null || userId.isEmpty) {
      // Si no hay usuario, usar una clave genérica (no debería pasar en producción)
      return '${_cartKeyPrefix}guest';
    }
    return '$_cartKeyPrefix$userId';
  }

  // Limpiar el carrito antiguo (migración)
  static Future<void> _clearOldCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_oldCartKey)) {
        await prefs.remove(_oldCartKey);
        print('✅ Carrito antiguo limpiado (migración)');
      }
    } catch (e) {
      print('⚠️ Error limpiando carrito antiguo: $e');
    }
  }

  // Obtener el ID del usuario actual
  static String? _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Obtener todos los items del carrito
  static Future<List<CartItemModel>> getCartItems([String? userId]) async {
    try {
      final currentUserId = userId ?? _getCurrentUserId();
      if (currentUserId == null) {
        // Limpiar carrito antiguo si existe
        await _clearOldCart();
        return []; // No hay usuario autenticado, retornar carrito vacío
      }

      // Limpiar carrito antiguo en la primera carga del nuevo sistema
      await _clearOldCart();

      final prefs = await SharedPreferences.getInstance();
      final cartKey = _getCartKey(currentUserId);
      final cartJson = prefs.getString(cartKey);
      
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
  static Future<Map<String, dynamic>> addToCart(CartItemModel item, [String? userId]) async {
    try {
      final currentUserId = userId ?? _getCurrentUserId();
      if (currentUserId == null) {
        return {
          'success': false,
          'message': 'Debes iniciar sesión para agregar productos al carrito',
        };
      }

      final cartItems = await getCartItems(currentUserId);
      
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
      await _saveCartItems(cartItems, currentUserId);

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
    int newQuantity, [
    String? userId,
  ]) async {
    try {
      final currentUserId = userId ?? _getCurrentUserId();
      if (currentUserId == null) {
        return {
          'success': false,
          'message': 'Debes iniciar sesión para actualizar el carrito',
        };
      }

      if (newQuantity <= 0) {
        return await removeFromCart(productId, currentUserId);
      }

      final cartItems = await getCartItems(currentUserId);
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
      await _saveCartItems(cartItems, currentUserId);

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
  static Future<Map<String, dynamic>> removeFromCart(String productId, [String? userId]) async {
    try {
      final currentUserId = userId ?? _getCurrentUserId();
      if (currentUserId == null) {
        return {
          'success': false,
          'message': 'Debes iniciar sesión para eliminar productos del carrito',
        };
      }

      final cartItems = await getCartItems(currentUserId);
      cartItems.removeWhere((item) => item.productId == productId);
      await _saveCartItems(cartItems, currentUserId);

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

  // Limpiar todo el carrito de un usuario específico
  static Future<void> clearCart([String? userId]) async {
    try {
      final currentUserId = userId ?? _getCurrentUserId();
      if (currentUserId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final cartKey = _getCartKey(currentUserId);
      await prefs.remove(cartKey);
    } catch (e) {
      print('❌ Error limpiando carrito: $e');
    }
  }

  // Limpiar el carrito del usuario anterior (útil cuando cambia de usuario)
  static Future<void> clearCartForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartKey = _getCartKey(userId);
      await prefs.remove(cartKey);
    } catch (e) {
      print('❌ Error limpiando carrito del usuario $userId: $e');
    }
  }

  // Obtener el total del carrito
  static Future<double> getCartTotal([String? userId]) async {
    try {
      final cartItems = await getCartItems(userId);
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
  static Future<int> getTotalItemCount([String? userId]) async {
    try {
      final cartItems = await getCartItems(userId);
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
  static Future<void> _saveCartItems(List<CartItemModel> items, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartKey = _getCartKey(userId);
      final cartJson = jsonEncode(
        items.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(cartKey, cartJson);
    } catch (e) {
      rethrow;
    }
  }
}

