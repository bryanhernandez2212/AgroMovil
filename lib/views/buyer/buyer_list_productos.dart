import 'package:flutter/material.dart';
import 'package:agromarket/models/product_model.dart';
import 'package:agromarket/services/product_service.dart';
import 'package:agromarket/views/buyer/product_detail_view.dart';

class BuyerListProductosView extends StatefulWidget {
  final String? categoryFilter; // Filtro opcional por categoría
  const BuyerListProductosView({super.key, this.categoryFilter});

  @override
  State<BuyerListProductosView> createState() => _BuyerListProductosViewState();
}

class _BuyerListProductosViewState extends State<BuyerListProductosView> {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Set<String> _selectedCategories = {}; // Categorías seleccionadas en los filtros
  List<String> _availableCategories = []; // Todas las categorías disponibles
  String? _priceSort; // 'asc' para menor a mayor, 'desc' para mayor a menor, null para sin ordenar

  @override
  void initState() {
    super.initState();
    // Si viene con filtro de categoría desde el widget, agregarlo a los seleccionados
    if (widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty) {
      _selectedCategories.add(widget.categoryFilter!);
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await ProductService.getAllActiveProducts();
      if (!mounted) return;
      
      // Obtener todas las categorías únicas de los productos
      final categories = products.map((p) => p.categoria).toSet().toList()..sort();
      
      setState(() {
        _products = products;
        _availableCategories = categories;
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
    var filtered = _products;
    
    // Filtrar por categorías seleccionadas
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((product) {
        return _selectedCategories.contains(product.categoria);
      }).toList();
    }
    
    // Filtrar por búsqueda si hay query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.categoria.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.descripcion.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Ordenar por precio si hay un criterio de ordenamiento
    if (_priceSort != null) {
      if (_priceSort == 'asc') {
        // De más bajo a más alto
        filtered.sort((a, b) => a.precio.compareTo(b.precio));
      } else if (_priceSort == 'desc') {
        // De más alto a más bajo
        filtered.sort((a, b) => b.precio.compareTo(a.precio));
      }
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header con búsqueda y filtro
            _buildHeader(),
            
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
                                    : 'No hay productos disponibles',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Intenta con otra búsqueda'
                                    : 'Vuelve más tarde para ver productos',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadProducts,
                          child: _buildProductList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título "Productos" o nombre de la categoría
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty
                  ? widget.categoryFilter!
                  : 'Productos',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF115213),
              ),
            ),
          ),
          // Barra de búsqueda y botón de filtro
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(25),
                      shadowColor: Colors.black26,
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF115213), size: 20),
                          hintText: 'Buscar productos...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          enabledBorder: _buildInputBorder(const Color(0xFF115213), 1),
                          focusedBorder: _buildInputBorder(const Color(0xFF115213), 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Botón de filtro
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _selectedCategories.isNotEmpty 
                      ? const Color(0xFF115213) 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF115213),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showFilterDialog(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: _selectedCategories.isNotEmpty 
                              ? Colors.white 
                              : const Color(0xFF115213),
                          size: 20,
                        ),
                        if (_selectedCategories.isNotEmpty)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 14,
                                minHeight: 14,
                              ),
                              child: Text(
                                '${_selectedCategories.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Método para construir el borde del input
  OutlineInputBorder _buildInputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final tempSelectedCategories = Set<String>.from(_selectedCategories);
    String? tempPriceSort = _priceSort;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
            // Header del diálogo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: Color(0xFF115213),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Filtrar por categoría',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                    if (tempSelectedCategories.isNotEmpty || tempPriceSort != null)
                      TextButton(
                        onPressed: () {
                          tempSelectedCategories.clear();
                          tempPriceSort = null;
                          setDialogState(() {});
                        },
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: const Color(0xFF1A1A1A),
                    ),
                  ],
                ),
              ),
              
              // Filtro por precio
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          color: Color(0xFF115213),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Ordenar por precio',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPriceSortOption(
                            context,
                            'asc',
                            'Más barato',
                            tempPriceSort == 'asc',
                            () {
                              tempPriceSort = tempPriceSort == 'asc' ? null : 'asc';
                              setDialogState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPriceSortOption(
                            context,
                            'desc',
                            'Más caro',
                            tempPriceSort == 'desc',
                            () {
                              tempPriceSort = tempPriceSort == 'desc' ? null : 'desc';
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Lista de categorías
              Expanded(
                child: _availableCategories.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay categorías disponibles',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _availableCategories.length,
                        itemBuilder: (context, index) {
                          final category = _availableCategories[index];
                          final isSelected = tempSelectedCategories.contains(category);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected 
                                    ? const Color(0xFF115213) 
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            color: isSelected 
                                ? const Color(0xFF115213).withOpacity(0.1)
                                : Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              dense: true,
                              title: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                  color: isSelected 
                                      ? const Color(0xFF115213) 
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF115213),
                                      size: 20,
                                    )
                                  : const Icon(
                                      Icons.radio_button_unchecked,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                              onTap: () {
                                if (tempSelectedCategories.contains(category)) {
                                  tempSelectedCategories.remove(category);
                                } else {
                                  tempSelectedCategories.add(category);
                                }
                                setDialogState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
              
            // Botones de acción
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(
                          color: Color(0xFF115213),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF115213),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories = tempSelectedCategories;
                          _priceSort = tempPriceSort;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF115213),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Aplicar${tempSelectedCategories.isNotEmpty || tempPriceSort != null ? ' (${tempSelectedCategories.length + (tempPriceSort != null ? 1 : 0)})' : ''}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

  Widget _buildPriceSortOption(
    BuildContext context,
    String value,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF115213).withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF115213)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF115213),
                size: 18,
              ),
            if (isSelected) const SizedBox(width: 6),
            Icon(
              value == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
              color: isSelected 
                  ? const Color(0xFF115213)
                  : Colors.grey[600],
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected 
                    ? FontWeight.bold 
                    : FontWeight.normal,
                color: isSelected 
                    ? const Color(0xFF115213)
                    : const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.separated(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 100 + MediaQuery.of(context).padding.bottom, // Espacio para el menú de navegación
      ),
      itemCount: _filteredProducts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(ProductModel product) {
    // Obtener la primera imagen del producto
    String imageUrl = product.imagenes.isNotEmpty 
        ? product.imagenes.first 
        : (product.imagenUrl.isNotEmpty ? product.imagenUrl : product.imagen ?? '');
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BuyerProductDetailView(product: product),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Información del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.descripcion,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  Text(
                    '\$${product.precio.toStringAsFixed(2)} / ${product.unidad}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF115213),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Mostrar calificación y comentarios
                  Row(
                    children: [
                      if (product.calificacionPromedio > 0) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          product.calificacionPromedio.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${product.totalCalificaciones})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.comment_outlined, color: Colors.grey, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Sin calificaciones',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
              // Imagen del producto
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

