import 'package:flutter/material.dart';
import 'package:agromarket/models/product_model.dart';
import 'package:agromarket/models/comment_model.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:agromarket/services/product_service.dart';
import 'package:agromarket/controllers/cart_controller.dart';
import 'package:agromarket/views/buyer/shipping_address_view.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuyerProductDetailView extends StatefulWidget {
  final ProductModel? product;
  final Map<String, dynamic>? productMap; // Para compatibilidad
  const BuyerProductDetailView({
    super.key, 
    this.product,
    this.productMap,
  }) : assert(product != null || productMap != null, 'Debe proporcionar product o productMap');

  @override
  State<BuyerProductDetailView> createState() => _BuyerProductDetailViewState();
}

class _BuyerProductDetailViewState extends State<BuyerProductDetailView> {
  int quantity = 1;
  late PageController _pageController;
  int _currentImageIndex = 0;
  double _panStartX = 0.0;
  double _panStartY = 0.0;
  bool _isHorizontalGesture = false;
  
  // Estados para comentarios
  List<CommentModel> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();
  double _selectedRating = 5.0;
  bool _isSubmittingComment = false;
  
  // Estados para información del vendedor
  Map<String, dynamic>? _vendorInfo;
  bool _isLoadingVendorInfo = true;
  
  String? get productId => widget.product?.id;

  // Getters para obtener datos del producto (compatibilidad con ambos formatos)
  double get price => widget.product?.precio ?? (widget.productMap?['price'] as num?)?.toDouble() ?? 0.0;
  String get unit => widget.product?.unidad ?? widget.productMap?['unit']?.toString() ?? '';
  String get name => widget.product?.nombre ?? widget.productMap?['name']?.toString() ?? '';
  String get description => widget.product?.descripcion ?? widget.productMap?['description']?.toString() ?? '';
  int get stock => widget.product?.stock ?? 0;
  String get sellerName => widget.product?.vendedorNombre ?? 'Vendedor';
  
  // Obtener imagen (priorizar array de imágenes)
  String get image {
    if (widget.product != null) {
      if (widget.product!.imagenes.isNotEmpty) {
        return widget.product!.imagenes.first;
      } else if (widget.product!.imagenUrl.isNotEmpty) {
        return widget.product!.imagenUrl;
      } else if (widget.product!.imagen != null && widget.product!.imagen!.isNotEmpty) {
        return widget.product!.imagen!;
      }
    }
    return widget.productMap?['image']?.toString() ?? 'assets/fondo.png';
  }
  
  // Verificar si la imagen es una URL de red o un asset
  bool get isNetworkImage => image.startsWith('http://') || image.startsWith('https://');
  
  // Obtener todas las imágenes del producto
  List<String> get allImages {
    if (widget.product != null) {
      List<String> images = [];
      // Agregar imágenes del array
      if (widget.product!.imagenes.isNotEmpty) {
        images.addAll(widget.product!.imagenes);
      } else {
        // Si no hay array, usar imagenUrl o imagen
        if (widget.product!.imagenUrl.isNotEmpty) {
          images.add(widget.product!.imagenUrl);
        } else if (widget.product!.imagen != null && widget.product!.imagen!.isNotEmpty) {
          images.add(widget.product!.imagen!);
        }
      }
      return images;
    }
    // Fallback para productMap
    String img = widget.productMap?['image']?.toString() ?? 'assets/fondo.png';
    return img.isNotEmpty ? [img] : ['assets/fondo.png'];
  }
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (productId != null) {
      _loadComments();
    }
    if (widget.product != null && widget.product!.vendedorId.isNotEmpty) {
      _loadVendorInfo();
    }
  }
  
  Future<void> _loadVendorInfo() async {
    if (widget.product == null || widget.product!.vendedorId.isEmpty) return;
    
    setState(() {
      _isLoadingVendorInfo = true;
    });
    
    try {
      final info = await ProductService.getVendorInfo(widget.product!.vendedorId);
      if (mounted) {
        setState(() {
          _vendorInfo = info;
          _isLoadingVendorInfo = false;
        });
      }
    } catch (e) {
      print('Error cargando información del vendedor: $e');
      if (mounted) {
        setState(() {
          _isLoadingVendorInfo = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }
  
  Future<void> _loadComments() async {
    if (productId == null) return;
    
    setState(() {
      _isLoadingComments = true;
    });
    
    try {
      final comments = await ProductService.getProductComments(productId!);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print('Error cargando comentarios: $e');
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }
  
  Future<void> _submitComment() async {
    if (productId == null) return;
    
    final comentario = _commentController.text.trim();
    if (comentario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe un comentario'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para comentar'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmittingComment = true;
    });
    
    final result = await ProductService.addComment(
      productId!,
      comentario,
      _selectedRating,
    );
    
    if (mounted) {
      setState(() {
        _isSubmittingComment = false;
      });
      
      if (result['success']) {
        _commentController.clear();
        _selectedRating = 5.0;
        await _loadComments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comentario agregado exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al agregar comentario'),
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
  }

  void _decrement() {
    setState(() {
      if (quantity > 1) quantity--;
    });
  }

  void _increment() {
    setState(() {
      if (stock == 0) {
        // Sin límite de stock, permitir incrementar
      quantity++;
      } else if (quantity < stock) {
      quantity++;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock disponible: $stock ${unit}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });
  }

  Future<void> _addToCart() async {
    if (widget.product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo obtener la información del producto'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cartController = Provider.of<CartController>(context, listen: false);
    
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
        ),
      ),
    );

    try {
      final result = await cartController.addToCart(widget.product!, quantity);
      
      // Cerrar loading
      if (mounted) Navigator.pop(context);
      
      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${widget.product!.nombre} agregado al carrito'),
                ],
              ),
              backgroundColor: const Color(0xFF115213),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Error al agregar al carrito'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar loading si hay error
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _buyNow() async {
    if (widget.product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo obtener la información del producto'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final cartController = Provider.of<CartController>(context, listen: false);
    
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
        ),
      ),
    );

    try {
      // Agregar producto al carrito
      final result = await cartController.addToCart(widget.product!, quantity);
      
      // Cerrar loading
      if (mounted) Navigator.pop(context);
      
      if (result['success']) {
        // Recargar el carrito para obtener los items actualizados
        await cartController.loadCart();
        
        if (mounted) {
          // Navegar directamente a la dirección de envío
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShippingAddressView(
                cartItems: [CartItemModel.fromProduct(widget.product!, quantity)],
                cartTotal: widget.product!.precio * quantity,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Error al agregar al carrito'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar loading si hay error
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = price * quantity;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenido con scroll (incluyendo imágenes)
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: 100 + MediaQuery.of(context).padding.bottom, // Espacio para el menú de navegación
              ),
        child: Column(
          children: [
                  // Imagen principal
            _buildHeaderImage(context),
                  // Contenido del producto
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        // Título del producto
                    Text(
                      name,
                      style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Descripción
                    Text(
                      description,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF666666),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Precio y calificación en una fila limpia
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Precio
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '\$',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    Text(
                                      price.toStringAsFixed(0),
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                        height: 1.0,
                                      ),
                                    ),
                                    if (price % 1 != 0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 2, bottom: 4),
                                        child: Text(
                                          price.toStringAsFixed(1).split('.').last,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'por $unit',
                      style: const TextStyle(
                        fontSize: 14,
                                    color: Color(0xFF666666),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Calificación si existe
                            if (widget.product != null && widget.product!.calificacionPromedio > 0)
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 20),
                                  const SizedBox(width: 6),
                    Text(
                                    widget.product!.calificacionPromedio.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  Text(
                                    ' (${widget.product!.totalCalificaciones})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Información de stock
                        Row(
                          children: [
                            Icon(
                              stock > 0 ? Icons.check_circle : Icons.cancel,
                              color: stock > 0 ? const Color(0xFF115213) : Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              stock > 0 ? 'Stock disponible: $stock $unit' : 'Sin stock disponible',
                        style: TextStyle(
                                fontSize: 14,
                                color: stock > 0 ? const Color(0xFF115213) : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                          ],
                    ),
                        const SizedBox(height: 32),

                        const SizedBox(height: 24),
                        
                        // Selector de cantidad
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                            _roundIconButton(
                              icon: Icons.remove, 
                              onTap: _decrement,
                              enabled: quantity > 1,
                            ),
                            const SizedBox(width: 32),
                        Text(
                          '$quantity',
                          style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(width: 32),
                            _roundIconButton(
                              icon: Icons.add, 
                              onTap: _increment,
                              enabled: stock == 0 || (stock > 0 && quantity < stock),
                            ),
                          ],
                        ),
                        if (stock > 0 && quantity > stock)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                                Icon(Icons.warning_amber_rounded, 
                                  color: Colors.red.shade700, 
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Máximo disponible: $stock $unit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                        const SizedBox(height: 24),
                        
                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '\$${total.toStringAsFixed(2)} MXN',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Botones de acción
                    _filledPillButton(
                      label: 'Comprar ahora',
                      onTap: _buyNow,
                        ),
                        const SizedBox(height: 12),
                        _primaryHollowButton(
                          label: 'Agregar al carrito',
                          onTap: _addToCart,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  // Divisor entre botones y vendedor
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 32),
                  
                  // Sección de información del vendedor
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildVendorSection(),
                  ),
                  
                  const SizedBox(height: 32),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: Colors.grey[200],
                  ),
                  const SizedBox(height: 24),
                  
                  // Sección de comentarios
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildCommentsSection(),
            ),
          ],
        ),
      ),
            // Botón de regreso flotante
        Positioned(
          top: 10,
          left: 10,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF1A1A1A),
                size: 24,
              ),
            ),
          ),
        ),
      ],
        ),
      ),
    );
  }
  
  Widget _buildVendorSection() {
    // Mostrar loading mientras se carga la información
    if (_isLoadingVendorInfo) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
          ),
        ),
      );
    }
    
    // Usar información del vendedor si está disponible, sino usar datos del producto
    final vendorName = _vendorInfo?['nombre'] ?? widget.product?.vendedorNombre ?? sellerName;
    final vendorLocation = _vendorInfo?['ubicacion'] ?? 'No especificada';
    final totalProducts = _vendorInfo?['totalProductos'] ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vendedor',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF115213).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  vendorName.isNotEmpty ? vendorName[0].toUpperCase() : 'V',
                  style: const TextStyle(
                    color: Color(0xFF115213),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendorName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                    ),
                    const SizedBox(height: 8),
                  _buildVendorInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Ubicación',
                    value: vendorLocation,
                  ),
                  const SizedBox(height: 8),
                  _buildVendorInfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'Productos',
                    value: '$totalProducts producto${totalProducts != 1 ? 's' : ''} registrado${totalProducts != 1 ? 's' : ''}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildVendorInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF115213),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    final user = FirebaseAuth.instance.currentUser;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Row(
          children: [
            const Text(
              'Comentarios',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            if (widget.product != null && widget.product!.calificacionPromedio > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      widget.product!.calificacionPromedio.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${widget.product!.totalCalificaciones})',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        
        // Formulario para agregar comentario
        if (user != null)
          _buildCommentForm()
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Inicia sesión para dejar un comentario',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 32),
        
        // Lista de comentarios
        if (_isLoadingComments)
                    const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
              ),
            ),
          )
        else if (_comments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 64,
                    color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                    'Aún no hay comentarios',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sé el primero en comentar',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _comments.asMap().entries.map((entry) {
              final index = entry.key;
              final comment = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index == _comments.length - 1 ? 0 : 16),
                child: _buildCommentCard(comment),
              );
            }).toList(),
          ),
      ],
    );
  }
  
  Widget _buildCommentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF115213).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF115213),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Deja tu comentario',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Selector de calificación mejorado
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Calificación',
                        style: TextStyle(
                  fontSize: 14,
                          fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final rating = (index + 1).toDouble();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = rating;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 1),
                      child: Icon(
                        _selectedRating >= rating ? Icons.star : Icons.star_border,
                        color: _selectedRating >= rating ? Colors.amber : Colors.grey[400],
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                      child: Text(
                  _selectedRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 20),
          
          // Campo de texto mejorado
          TextField(
            controller: _commentController,
            maxLines: 5,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Escribe tu experiencia con este producto...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
              ),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
                    const SizedBox(height: 20),
          
          // Botón enviar mejorado
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF115213),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmittingComment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.send_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Enviar comentario',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
                              ),
                            ),
                          ],
      ),
    );
  }
  
  Widget _buildCommentCard(CommentModel comment) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              // Avatar mejorado
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF115213).withOpacity(0.2),
                      const Color(0xFF115213).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    comment.userName.isNotEmpty 
                        ? comment.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Color(0xFF115213),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        // Estrellas de calificación compactas
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 1),
                              child: Icon(
                                comment.calificacion >= (index + 1) 
                                    ? Icons.star 
                                    : Icons.star_border,
                                color: comment.calificacion >= (index + 1) 
                                    ? Colors.amber 
                                    : Colors.grey[300],
                                size: 16,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(comment.fechaCreacion),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Texto del comentario
          Text(
            comment.comentario,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
              height: 1.6,
              letterSpacing: 0.2,
              ),
            ),
          ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Hace un momento';
        }
        return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
      }
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  Widget _buildHeaderImage(BuildContext context) {
    final images = allImages;
    final hasMultipleImages = images.length > 1;
    
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: hasMultipleImages
                ? _buildScrollablePageView(images)
                : _buildSingleImage(images.isNotEmpty ? images.first : 'assets/fondo.png'),
          ),
        ),
        // Indicadores de página si hay múltiples imágenes
        if (hasMultipleImages)
        Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildScrollablePageView(List<String> images) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (details) {
        _panStartX = details.position.dx;
        _panStartY = details.position.dy;
        setState(() {
          _isHorizontalGesture = false;
        });
      },
      onPointerMove: (details) {
        final dx = (details.position.dx - _panStartX).abs();
        final dy = (details.position.dy - _panStartY).abs();
        
        // Si el gesto es principalmente horizontal, marcar como horizontal
        if (dx > dy && dx > 15) {
          if (!_isHorizontalGesture) {
            setState(() {
              _isHorizontalGesture = true;
            });
          }
        }
      },
      onPointerUp: (details) {
        // Si fue un gesto horizontal, cambiar de página basado en la dirección
        if (_isHorizontalGesture) {
          final dx = details.position.dx - _panStartX;
          if (dx < -50 && _currentImageIndex < images.length - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else if (dx > 50 && _currentImageIndex > 0) {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
        setState(() {
          _isHorizontalGesture = false;
        });
      },
      child: PageView.builder(
        controller: _pageController,
        // Deshabilitar scroll automático del PageView para que no bloquee gestos verticales
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        onPageChanged: (index) {
          setState(() {
            _currentImageIndex = index;
          });
        },
        itemCount: images.length,
        itemBuilder: (context, index) {
          final img = images[index];
          final isNetwork = img.startsWith('http://') || img.startsWith('https://');
          return isNetwork
              ? Image.network(
                  img,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 50,
                        ),
                      ),
                    );
                  },
                )
              : Image.asset(
                  img,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 50,
                        ),
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  Widget _buildSingleImage(String img) {
    final isNetwork = img.startsWith('http://') || img.startsWith('https://');
    return isNetwork
        ? Image.network(
            img,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 50,
                  ),
                ),
              );
            },
          )
        : Image.asset(
            img,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 50,
                  ),
                ),
              );
            },
          );
  }
  Widget _roundIconButton({
    required IconData icon, 
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF115213) : Colors.grey[300],
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
            BoxShadow(
                    color: const Color(0xFF115213).withOpacity(0.3),
                    blurRadius: 8,
              offset: const Offset(0, 4),
            ),
                ]
              : [],
        ),
        child: Icon(
          icon, 
          color: enabled ? Colors.white : Colors.grey[500],
          size: 20,
        ),
      ),
    );
  }
  Widget _primaryHollowButton({required String label, required VoidCallback onTap}) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF115213),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF115213).withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF115213),
            ),
          ),
        ),
      ),
    );
  }
  Widget _filledPillButton({required String label, required VoidCallback onTap}) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF115213),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF115213).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

