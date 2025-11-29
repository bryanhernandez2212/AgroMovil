import 'package:flutter/material.dart';
import 'package:agromarket/models/product_model.dart';
import 'package:agromarket/services/product_service.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/views/vendor/register_product_view.dart';

class ListProductViewContent extends StatefulWidget {
  const ListProductViewContent({super.key});

  @override
  State<ListProductViewContent> createState() => _ListProductViewContentState();
}

class _ListProductViewContentState extends State<ListProductViewContent> {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await ProductService.getProductsBySeller();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando productos: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ProductModel> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    return _products.where((product) {
      return product.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.categoria.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.descripcion.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        return Column(
          children: [
            if (_products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(30),
                  shadowColor: Colors.black26,
                  child: Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDark ? Colors.grey[400] : const Color.fromARGB(255, 13, 19, 13),
                          ),
                          hintText: 'Buscar mis productos...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey,
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          enabledBorder: _buildInputBorder(
                            isDark ? Colors.grey[700]! : const Color(0xFF2E7D32),
                            1,
                          ),
                          focusedBorder: _buildInputBorder(
                            isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                            2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            // Lista de productos
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No se encontraron productos que coincidan'
                                    : 'No tienes productos registrados',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Intenta con otra búsqueda'
                                    : 'Comienza a agregar tus productos ahora',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[500]
                                      : Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadProducts,
                          child: ListView.builder(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: 100 + MediaQuery.of(context).padding.bottom, // Espacio para el menú (75px) + espacio extra para los botones
                            ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(_filteredProducts[index]);
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  OutlineInputBorder _buildInputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Aquí puedes agregar navegación a detalles del producto si es necesario
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: product.imagenUrl.isNotEmpty
                    ? Image.network(
                        product.imagenUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Container(
                            width: 100,
                            height: 100,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          );
                        },
                      )
                    : Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Container(
                            width: 100,
                            height: 100,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF4CAF50).withOpacity(0.2)
                                : const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.categoria.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          product.activo ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: product.activo ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.activo ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                            fontSize: 12,
                            color: product.activo ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.descripcion,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.precio.toStringAsFixed(2)} / ${product.unidad}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          'Stock: ${product.stock}',
                          style: TextStyle(
                            fontSize: 14,
                            color: product.stock > 0
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ],
            ),
                    const SizedBox(height: 12),
                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Botón Editar
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _editProduct(product),
                            icon: Icon(
                              Icons.edit,
                              size: 18,
                              color: isDark ? Colors.black : Colors.black,
                            ),
                            label: const Text(
                              'Editar',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(217, 255, 251, 144),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón Eliminar
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _deleteProduct(product),
                            icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                            label: const Text(
                              'Eliminar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 215, 55, 55),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para editar producto
  void _editProduct(ProductModel product) async {
    // Navegar a la vista de registro con el producto para editar
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegisterProductViewContent(productToEdit: product),
      ),
    );
    
    // Si el resultado es true, recargar la lista
    if (result == true) {
      await _loadProducts();
    }
  }

  // Método para eliminar producto
  Future<void> _deleteProduct(ProductModel product) async {
    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar el producto "${product.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Mostrar indicador de carga
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Eliminar el producto
      final result = await ProductService.deleteProduct(product.id);
      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar el indicador de carga
      if (result['success']) {
        await _loadProducts();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto eliminado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class ProductsView extends StatelessWidget {
  const ProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListProductViewContent();
  }
}