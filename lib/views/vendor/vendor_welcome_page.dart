import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/services/product_service.dart';
import 'package:agromarket/services/order_service.dart';
import 'package:agromarket/estructure/product_estructure.dart';
import 'package:agromarket/views/profile/chat_view.dart';
import 'package:agromarket/views/vendor/seller_orders_view.dart';

class VendorWelcomePageContent extends StatefulWidget {
  const VendorWelcomePageContent({super.key});

  @override
  State<VendorWelcomePageContent> createState() => _VendorWelcomePageContentState();
}

class _VendorWelcomePageContentState extends State<VendorWelcomePageContent> {
  int _productCount = 0;
  bool _loadingProducts = false;
  int _newSalesCount = 0;
  bool _loadingSales = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProductCount();
      _loadNewSalesCount();
    });
  }

  Future<void> _loadProductCount() async {
    setState(() {
      _loadingProducts = true;
    });
    try {
      final products = await ProductService.getProductsBySeller();
      if (mounted) {
        setState(() {
          _productCount = products.length;
          _loadingProducts = false;
        });
      }
    } catch (e) {
      print('Error cargando productos: $e');
      if (mounted) {
        setState(() {
          _loadingProducts = false;
        });
      }
    }
  }

  Future<void> _loadNewSalesCount() async {
    setState(() {
      _loadingSales = true;
    });
    try {
      final orders = await OrderService.getVendorOrders();
      // Contar solo las ventas nuevas: aquellas con estado 'pagado' o 'pendiente'
      final newSales = orders.where((order) {
        final estado = order.estado.toLowerCase();
        return estado == 'pagado' || estado == 'pendiente';
      }).length;
      
      if (mounted) {
        setState(() {
          _newSalesCount = newSales;
          _loadingSales = false;
        });
      }
    } catch (e) {
      print('Error cargando nuevas ventas: $e');
      if (mounted) {
        setState(() {
          _loadingSales = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final user = authController.currentUser;

        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final double bottomSpacer = 100; // Espacio para la barra de navegación
        
        // Header con saludo como el comprador (fijo)
        final userName = user?.nombre;
        final fullName = (userName != null && userName.trim().isNotEmpty)
            ? userName.trim()
            : 'Usuario';
        
        // Truncar el nombre si es muy largo (máximo 18 caracteres)
        String displayName = fullName;
        if (displayName.length > 18) {
          displayName = '${displayName.substring(0, 18 - 3)}...';
        }
        
        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header fijo
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'AgroMarket',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bienvenido',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF2E7D32),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Contenido scrolleable
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: bottomSpacer + bottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                // Resumen de productos
                _buildProductSummary(),

                const SizedBox(height: 30),

                // Estadísticas rápidas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resumen de tu tienda',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Productos',
                        _loadingProducts ? '...' : '$_productCount',
                        Icons.inventory,
                        const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSalesStatCard(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Ingresos',
                        '\$1,250',
                        Icons.attach_money,
                        const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Calificación',
                        '4.8',
                        Icons.star,
                        const Color(0xFFFFC107),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Acciones rápidas
                Text(
                  'Acciones rápidas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white 
                        : const Color(0xFF2E7D32),
                  ),
                ),

                const SizedBox(height: 16),

                // Ir a agregar producto
                _buildActionCard(
                  context,
                  'Agregar producto',
                  'Registra un nuevo producto en tu tienda',
                  Icons.add_circle_outline,
                  const Color(0xFF4CAF50),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ProductEstructureView(currentIndex: 1),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Ir a chats
                _buildActionCard(
                  context,
                  'Mis chats',
                  'Responde dudas y coordina con tus compradores',
                  Icons.chat_bubble_outline,
                  const Color(0xFF2196F3),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatView(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Ver todas las ventas
                _buildActionCard(
                  context,
                  'Ver todas las ventas',
                  'Gestiona y revisa todas tus ventas',
                  Icons.shopping_cart,
                  const Color(0xFF4CAF50),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SellerOrdersView(),
                      ),
                    ).then((_) {
                      // Recargar el conteo cuando regrese de la vista de ventas
                      _loadNewSalesCount();
                    });
                  },
                ),

                      SizedBox(height: bottomPadding + 16), // Espacio adicional al final
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductSummary() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        // Navegar a la vista de productos
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProductEstructureView(currentIndex: 2), // Vista de lista de productos
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E7D32).withOpacity(0.2) : const Color(0xFF2E7D32).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2E7D32).withOpacity(0.5) : const Color(0xFF2E7D32).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Mis productos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF2E7D32),
                        ),
                      ),
                      const Spacer(),
                      if (_loadingProducts)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white : const Color(0xFF2E7D32),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_productCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestiona y edita tus productos',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesStatCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.shopping_cart, color: const Color(0xFF4CAF50), size: 28),
          const SizedBox(height: 8),
          Text(
            _loadingSales ? '...' : (_newSalesCount > 0 ? '$_newSalesCount' : '0'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _newSalesCount == 1 ? 'Nueva venta' : 'Nuevas ventas',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

}

// Mantener la clase original para compatibilidad
class VendorWelcomePage extends StatelessWidget {
  const VendorWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VendorWelcomePageContent();
  }
}

