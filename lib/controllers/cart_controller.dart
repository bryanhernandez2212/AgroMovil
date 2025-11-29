import 'package:flutter/material.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:agromarket/models/product_model.dart';
import 'package:agromarket/services/cart_service.dart';
import 'package:agromarket/services/stock_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartController extends ChangeNotifier {
  List<CartItemModel> _cartItems = [];
  bool _isLoading = false;
  final Set<String> _updatingProductIds = {}; // Rastrear productos que se están actualizando
  String? _currentUserId; // ID del usuario actual

  List<CartItemModel> get cartItems => _cartItems;
  bool get isLoading => _isLoading;
  bool get isEmpty => _cartItems.isEmpty;
  bool isUpdating(String productId) => _updatingProductIds.contains(productId);

  // Obtener el ID del usuario actual
  String? get currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Calcular el total del carrito
  double get totalPrice {
    return _cartItems.fold(0.0, (total, item) => total + item.totalPrice);
  }

  // Calcular el total de items (sumando cantidades)
  int get totalItemCount {
    return _cartItems.fold(0, (total, item) => total + item.quantity);
  }

  CartController() {
    _initializeCart();
  }

  // Inicializar el carrito y escuchar cambios de usuario
  void _initializeCart() {
    // Cargar carrito inicial
    loadCart();
    
    // Escuchar cambios de autenticación para cambiar el carrito cuando cambia el usuario
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      final newUserId = user?.uid;
      
      // Solo limpiar el carrito si cambió a OTRO usuario (no cuando se hace logout)
      if (_currentUserId != null && newUserId != null && _currentUserId != newUserId) {
        print('🔄 Usuario cambió de $_currentUserId a $newUserId. Limpiando carrito anterior.');
        // Limpiar el carrito del usuario anterior solo cuando cambia a otro usuario
        CartService.clearCartForUser(_currentUserId!);
      }
      
      // Si se hizo logout (newUserId es null pero _currentUserId no), NO limpiar
      // El carrito permanece guardado para cuando vuelva a iniciar sesión
      if (_currentUserId != null && newUserId == null) {
        print('🔓 Usuario cerró sesión. El carrito se mantiene guardado.');
        // Limpiar solo la vista (no el almacenamiento)
        _cartItems = [];
        _currentUserId = null;
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Actualizar el ID del usuario actual
      _currentUserId = newUserId;
      
      // Cargar el carrito del nuevo usuario (o vacío si no hay usuario)
      loadCart();
    });
  }

  // Cargar carrito desde almacenamiento
  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = currentUserId;
      _cartItems = await CartService.getCartItems(userId);
      
      // Si no hay usuario, el carrito estará vacío (correcto)
      if (userId == null) {
        _cartItems = [];
        _isLoading = false;
        notifyListeners();
        return;
      }
      
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
          await CartService.removeFromCart(productId, userId);
        }
        // Recargar carrito después de limpiar
        _cartItems = await CartService.getCartItems(userId);
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

      final userId = currentUserId;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Debes iniciar sesión para agregar productos al carrito',
        };
      }

      final cartItem = CartItemModel.fromProduct(product, quantity);
      final result = await CartService.addToCart(cartItem, userId);

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

  // Actualizar cantidad de un item con actualización optimista
  Future<Map<String, dynamic>> updateQuantity(String productId, int newQuantity) async {
    // Evitar múltiples actualizaciones simultáneas del mismo producto
    if (_updatingProductIds.contains(productId)) {
      return {
        'success': false,
        'message': 'Actualización en curso, por favor espera',
      };
    }

    try {
      // Marcar que este producto se está actualizando
      _updatingProductIds.add(productId);

      // Obtener el item actual - siempre obtener el más reciente
      final index = _cartItems.indexWhere((item) => item.productId == productId);
      if (index == -1) {
        _updatingProductIds.remove(productId);
        return {
          'success': false,
          'message': 'Producto no encontrado en el carrito',
        };
      }

      // Obtener el valor más reciente del item actual
      final currentItem = _cartItems[index];
      final currentQuantity = currentItem.quantity;
      
      // Validar cantidad
      if (newQuantity <= 0) {
        _updatingProductIds.remove(productId);
        return await removeFromCart(productId);
      }
      
      // Verificar que la nueva cantidad sea diferente de la actual
      if (currentQuantity == newQuantity) {
        _updatingProductIds.remove(productId);
        return {
          'success': true,
          'message': 'Cantidad ya está en el valor solicitado',
        };
      }

      // Crear copia del item anterior para poder revertir si es necesario
      final previousItem = CartItemModel(
        id: currentItem.id,
        productId: currentItem.productId,
        productName: currentItem.productName,
        productImage: currentItem.productImage,
        unitPrice: currentItem.unitPrice,
        unit: currentItem.unit,
        quantity: currentItem.quantity,
        sellerId: currentItem.sellerId,
        sellerName: currentItem.sellerName,
      );

      // Actualización optimista: crear nueva lista y actualizar item
      _cartItems = List<CartItemModel>.from(_cartItems);
      _cartItems[index] = currentItem.copyWith(quantity: newQuantity);
      
      // Notificar inmediatamente para actualizar la UI
      notifyListeners();

      // Validar stock y guardar en segundo plano
      final stockValidation = await StockService.validateStock(productId, newQuantity);
      
      if (!stockValidation['success']) {
        // Revertir el cambio si falla la validación
        _cartItems = List<CartItemModel>.from(_cartItems);
        _cartItems[index] = previousItem;
        notifyListeners();
        _updatingProductIds.remove(productId);
        
        return {
          'success': false,
          'message': stockValidation['message'] ?? 'Stock insuficiente',
          'available': stockValidation['available'] ?? 0,
        };
      }

      // Guardar en almacenamiento local (no bloquea)
      try {
        final userId = currentUserId;
        if (userId == null) {
          _updatingProductIds.remove(productId);
          return {
            'success': false,
            'message': 'Debes iniciar sesión para actualizar el carrito',
          };
        }
        await CartService.updateItemQuantity(productId, newQuantity, userId);
      } catch (error) {
        print('⚠️ Error guardando cantidad en almacenamiento: $error');
        // Si falla guardar, revertir el cambio
        _cartItems = List<CartItemModel>.from(_cartItems);
        _cartItems[index] = previousItem;
        notifyListeners();
        _updatingProductIds.remove(productId);
        
        return {
          'success': false,
          'message': 'Error guardando: ${error.toString()}',
        };
      }
      
      _updatingProductIds.remove(productId);
      return {
        'success': true,
        'message': 'Cantidad actualizada',
      };
    } catch (e) {
      print('❌ Error actualizando cantidad: $e');
      _updatingProductIds.remove(productId);
      
      // Revertir el cambio en caso de error
      final index = _cartItems.indexWhere((item) => item.productId == productId);
      if (index != -1) {
        // Recargar desde el almacenamiento para tener el valor correcto
        loadCart();
      }
      
      return {
        'success': false,
        'message': 'Error actualizando cantidad: ${e.toString()}',
      };
    }
  }

  // Eliminar producto del carrito
  Future<Map<String, dynamic>> removeFromCart(String productId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Debes iniciar sesión para eliminar productos del carrito',
        };
      }

      final result = await CartService.removeFromCart(productId, userId);
      
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
      final userId = currentUserId;
      await CartService.clearCart(userId);
      await loadCart(); // Recargar carrito
    } catch (e) {
      print('❌ Error limpiando carrito: $e');
    }
  }
}

