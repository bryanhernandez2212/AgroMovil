import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/cart_controller.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:agromarket/views/buyer/shipping_address_view.dart';

class BuyerCartView extends StatefulWidget {
  const BuyerCartView({super.key});

  @override
  State<BuyerCartView> createState() => _BuyerCartViewState();
}

class _BuyerCartViewState extends State<BuyerCartView> {
  @override
  void initState() {
    super.initState();
    // Cargar el carrito cuando se abre la vista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartController>(context, listen: false).loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Selector<CartController, bool>(
          selector: (_, controller) => controller.isLoading,
          builder: (context, isLoading, _) {
            if (isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
                ),
              );
            }
            
            return Selector<CartController, List<String>>(
              selector: (_, controller) => controller.cartItems.map((item) => item.productId).toList(),
              builder: (context, productIds, _) {
                final cartController = Provider.of<CartController>(context, listen: false);
                
                if (productIds.isEmpty) {
                  return _buildEmptyCart();
                }

                return Column(
                  children: [
                    // Encabezado
                    _buildHeader(),
                    
                    // Lista de productos - usando un widget que solo se actualiza cuando cambia la lista
                    Expanded(
                      child: _CartItemsListWidget(cartController: cartController),
                    ),
                    
                    // Resumen y total
                    _CartSummaryWidget(cartController: cartController),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          const Text(
            'Mi Carrito',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const Spacer(),
          Selector<CartController, int>(
            selector: (_, controller) => controller.totalItemCount,
            builder: (context, totalItemCount, _) {
              return Text(
                '$totalItemCount producto${totalItemCount != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : const Color(0xFF2E7D32),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: isDark ? Colors.grey[600] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Tu carrito está vacío',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Agrega productos para comenzar a comprar',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}

// Widget optimizado para el item del carrito que solo se actualiza cuando cambia
class _CartItemWidget extends StatefulWidget {
  final CartItemModel item;
  final CartController cartController;

  const _CartItemWidget({
    super.key,
    required this.item,
    required this.cartController,
  });

  @override
  State<_CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<_CartItemWidget> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cartController = widget.cartController;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.productImage,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      width: 80,
                      height: 80,
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                      child: Icon(
                        Icons.image_not_supported,
                        color: isDark ? Colors.grey[600] : Colors.grey,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      width: 80,
                      height: 80,
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // Información del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vendedor: ${item.sellerName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF115213),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Botón eliminar
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showDeleteDialog(context, item, cartController),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Selector de cantidad y total - solo se actualiza cuando cambia este item
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                  // Selector de cantidad
                  Row(
                    children: [
                      RepaintBoundary(
                        child: Selector<CartController, int>(
                          selector: (_, controller) {
                            final currentItem = controller.cartItems.firstWhere(
                              (cartItem) => cartItem.productId == item.productId,
                              orElse: () => item,
                            );
                            return currentItem.quantity;
                          },
                          builder: (context, quantity, _) {
                            return _buildQuantityButton(
                              icon: Icons.remove,
                              onTap: _isUpdating ? null : () => _updateQuantity(context, item, -1, cartController),
                              enabled: quantity > 1 && !_isUpdating,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      RepaintBoundary(
                        child: Selector<CartController, int>(
                          selector: (_, controller) {
                            final currentItem = controller.cartItems.firstWhere(
                              (cartItem) => cartItem.productId == item.productId,
                              orElse: () => item,
                            );
                            return currentItem.quantity;
                          },
                          builder: (context, quantity, _) {
                            return Text(
                              '$quantity',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onTap: _isUpdating ? null : () => _updateQuantity(context, item, 1, cartController),
                        enabled: !_isUpdating,
                      ),
                    ],
                  ),
                  
                  // Total del item - solo se actualiza cuando cambia
                  RepaintBoundary(
                    child: Selector<CartController, double>(
                      selector: (_, controller) {
                        final currentItem = controller.cartItems.firstWhere(
                          (cartItem) => cartItem.productId == item.productId,
                          orElse: () => item,
                        );
                        return currentItem.totalPrice;
                      },
                      builder: (context, totalPrice, _) {
                        return Text(
                          '\$${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF115213),
                          ),
                        );
                      },
                    ),
                  ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled && onTap != null ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF115213) : Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.grey[500],
          size: 18,
        ),
      ),
    );
  }

  Future<void> _updateQuantity(BuildContext context, CartItemModel item, int delta, CartController cartController) async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });

    try {
      // Obtener la cantidad actual del carrito justo antes de actualizar
      // para asegurar que tenemos el valor más reciente
      final currentItem = cartController.cartItems.firstWhere(
        (cartItem) => cartItem.productId == item.productId,
        orElse: () => item,
      );
      
      final currentQuantity = currentItem.quantity;
      final newQuantity = currentQuantity + delta;
      
      if (newQuantity < 1) {
        if (mounted) {
          setState(() {
            _isUpdating = false;
          });
        }
        return;
      }
      
      final result = await cartController.updateQuantity(item.productId, newQuantity);
      
      if (!result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al actualizar cantidad'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showDeleteDialog(BuildContext context, CartItemModel item, CartController cartController) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Eliminar producto',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          '¿Deseas eliminar ${item.productName} del carrito?',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.black,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await cartController.removeFromCart(item.productId);
              
              if (context.mounted) {
                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.productName} eliminado del carrito'),
                      backgroundColor: const Color(0xFF115213),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Error al eliminar'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget optimizado para el resumen del carrito que solo se actualiza cuando cambia el total
class _CartSummaryWidget extends StatelessWidget {
  final CartController cartController;

  const _CartSummaryWidget({required this.cartController});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Total - solo se actualiza cuando cambia
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                Selector<CartController, double>(
                  selector: (_, controller) => controller.totalPrice,
                  builder: (context, totalPrice, _) {
                    return Text(
                      '\$${totalPrice.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF115213),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Botón continuar compra
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShippingAddressView(
                        cartItems: cartController.cartItems,
                        cartTotal: cartController.totalPrice,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF115213),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continuar con la compra',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para la lista de items que solo se actualiza cuando cambia la estructura de la lista
class _CartItemsListWidget extends StatelessWidget {
  final CartController cartController;

  const _CartItemsListWidget({required this.cartController});

  @override
  Widget build(BuildContext context) {
    // Obtener los items sin escuchar cambios - la lista solo se reconstruirá cuando cambie la cantidad de items
    final items = cartController.cartItems;
    return ListView.builder(
      key: const ValueKey('cart_items_list'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        // Cada item widget se actualizará independientemente usando sus propios Selector
        // El widget completo del item está envuelto en RepaintBoundary para aislar actualizaciones
        return _CartItemWidget(
          key: ValueKey(items[index].productId),
          item: items[index],
          cartController: cartController,
        );
      },
    );
  }
}
