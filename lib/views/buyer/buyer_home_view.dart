import 'package:flutter/material.dart';
import 'package:agromarket/models/product_model.dart';
import 'package:agromarket/services/product_service.dart';
import 'package:agromarket/views/buyer/product_detail_view.dart';

class BuyerHomeView extends StatefulWidget {
  final Function(String)? onCategoryTap;
  const BuyerHomeView({super.key, this.onCategoryTap});

  @override
  State<BuyerHomeView> createState() => _BuyerHomeViewState();
}

class _BuyerHomeViewState extends State<BuyerHomeView> {
  final List<Map<String, dynamic>> quickCategories = [
    {
      'label': 'Verduras',
      'icon': Icons.eco_outlined,
      'color': const Color(0xFFE3F2FD),
      'value': 'verduras',
    },
    {
      'label': 'Frutas',
      'icon': Icons.apple_outlined,
      'color': const Color(0xFFFFF3E0),
      'value': 'frutas',
    },
    {
      'label': 'Granos',
      'icon': Icons.grain,
      'color': const Color(0xFFF1F8E9),
      'value': 'granos',
    },
    {
      'label': 'Lácteos',
      'icon': Icons.local_drink_outlined,
      'color': const Color(0xFFE8EAF6),
      'value': 'lacteos',
    },
    {
      'label': 'Orgánicos',
      'icon': Icons.spa_outlined,
      'color': const Color(0xFFE0F2F1),
      'value': 'organicos',
    },
  ];

  final Set<int> _revealedSections = <int>{};

  List<ProductModel> _bestSellerProducts = [];
  List<ProductModel> _recommendedProducts = [];
  ProductModel? _highlightProduct;
  bool _isLoadingShowcase = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var i = 0; i < 4; i++) {
        Future.delayed(Duration(milliseconds: 140 * i), () {
          if (!mounted) return;
          setState(() {
            _revealedSections.add(i);
          });
        });
      }
    });

    _loadShowcaseProducts();
  }

  Future<void> _loadShowcaseProducts() async {
    try {
      final products = await ProductService.getAllActiveProducts();
      if (!mounted) return;

      final activeProducts = products.where((product) => product.activo).toList();

      final bestSellers = List<ProductModel>.from(activeProducts)
        ..sort((a, b) => b.vendido.compareTo(a.vendido));

      final recommendations = List<ProductModel>.from(activeProducts)
        ..sort((a, b) {
          final ratingComparison = b.calificacionPromedio.compareTo(a.calificacionPromedio);
          if (ratingComparison != 0) return ratingComparison;
          return b.totalCalificaciones.compareTo(a.totalCalificaciones);
        });

      setState(() {
        _bestSellerProducts = bestSellers.take(6).toList();
        _recommendedProducts = recommendations.take(4).toList();
        _highlightProduct = _bestSellerProducts.isNotEmpty
            ? _bestSellerProducts.first
            : (_recommendedProducts.isNotEmpty ? _recommendedProducts.first : null);
        _isLoadingShowcase = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bestSellerProducts = [];
        _recommendedProducts = [];
        _highlightProduct = null;
        _isLoadingShowcase = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomSpacer = kBottomNavigationBarHeight * 0.35;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: bottomSpacer + bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnimatedSection(
                  index: 0,
                  child: _buildQuickCategories(),
                ),
                const SizedBox(height: 28),
                _buildAnimatedSection(
                  index: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                        title: 'Más vendidos',
                        actionLabel: 'Ver todo',
                        onActionTap: () {},
                      ),
                      const SizedBox(height: 16),
                      _buildBestSellerList(),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buildAnimatedSection(
                  index: 2,
                  child: _buildDealBanner(),
                ),
                const SizedBox(height: 28),
                _buildAnimatedSection(
                  index: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                        title: 'Recomendados para ti',
                        actionLabel: 'Ver más',
                        onActionTap: () {},
                      ),
                      const SizedBox(height: 16),
                      _buildRecommendationsGrid(),
                    ],
                  ),
                ),
                SizedBox(height: bottomPadding + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedSection({
    required int index,
    required Widget child,
    double offsetY = 0.08,
  }) {
    final isVisible = _revealedSections.contains(index);
    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      offset: isVisible ? Offset.zero : Offset(0, offsetY),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        opacity: isVisible ? 1 : 0,
        child: child,
      ),
    );
  }

  Widget _buildQuickCategories() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: quickCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = quickCategories[index];
          return _QuickCategoryChip(
            label: category['label'] as String,
            icon: category['icon'] as IconData,
            background: category['color'] as Color,
            onTap: () => widget.onCategoryTap?.call(category['value'] as String),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B4332),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF7043),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: Row(
              children: [
                Text(actionLabel),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBestSellerList() {
    if (_isLoadingShowcase) {
      return _buildBestSellerSkeleton();
    }

    if (_bestSellerProducts.isEmpty) {
      return _buildHorizontalEmptyState('Aún no hay productos destacados.');
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _bestSellerProducts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final product = _bestSellerProducts[index];
          final imageUrl = _resolveProductImage(product);
          final priceLabel = '\$${_formatPrice(product.precio)} / ${product.unidad}';
          return _BestSellerCard(
            product: product,
            imageUrl: imageUrl,
            priceLabel: priceLabel,
            rating: product.calificacionPromedio,
            onTap: () => _openProductDetail(product),
          );
        },
      ),
    );
  }

  Widget _buildBestSellerSkeleton() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) => Container(
          width: 150,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalEmptyState(String message) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _resolveProductImage(ProductModel product) {
    if (product.imagenes.isNotEmpty && product.imagenes.first.isNotEmpty) {
      return product.imagenes.first;
    }
    if (product.imagen != null && product.imagen!.isNotEmpty) {
      return product.imagen!;
    }
    if (product.imagenUrl.isNotEmpty) {
      return product.imagenUrl;
    }
    return '';
  }

  String _formatPrice(double value) {
    final isInteger = value % 1 == 0;
    return isInteger ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  void _openProductDetail(ProductModel product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BuyerProductDetailView(product: product),
      ),
    );
  }

  Widget _buildDealBanner() {
    if (_isLoadingShowcase) {
      return _buildDealSkeleton();
    }

    final product = _highlightProduct;
    if (product == null) {
      return _buildDealEmptyState();
    }

    final imageUrl = _resolveProductImage(product);
    final priceLabel = '\$${_formatPrice(product.precio)} / ${product.unidad}';
    const accent = Color(0xFFFF7043);

    return Container(
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accent.withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product.categoria.isNotEmpty ? product.categoria : 'Producto destacado',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B4332),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B4332),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _truncate(product.descripcion, maxLength: 110),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4E5D5B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          priceLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (product.calificacionPromedio > 0)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFA726), size: 18),
                            const SizedBox(width: 4),
                            Text(
                              product.calificacionPromedio.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B4332),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => _openProductDetail(product),
                    style: TextButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.local_fire_department_outlined, size: 18),
                    label: const Text('Ver producto'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildDealImagePlaceholder(color: accent),
                    )
                  : _buildDealImagePlaceholder(color: accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealSkeleton() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }

  Widget _buildDealEmptyState() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Aún no hay promociones destacadas. Revisa más tarde.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDealImagePlaceholder({Color color = const Color(0xFFFF7043)}) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Color(0xFFFF7043)),
    );
  }

  String _truncate(String text, {int maxLength = 90}) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength - 3)}...';
  }

  Widget _buildRecommendationsGrid() {
    if (_isLoadingShowcase) {
      return _buildRecommendationsSkeleton();
    }

    if (_recommendedProducts.isEmpty) {
      return _buildVerticalEmptyState('Pronto verás recomendaciones personalizadas.');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recommendedProducts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final product = _recommendedProducts[index];
        return _RecommendationCard(
          product: product,
          imageUrl: _resolveProductImage(product),
          priceLabel: '\$${_formatPrice(product.precio)}',
          unitLabel: product.unidad,
          tag: product.categoria,
          animationDelay: Duration(milliseconds: 100 * index),
          onTap: () => _openProductDetail(product),
        );
      },
    );
  }

  Widget _buildRecommendationsSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildVerticalEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback? onTap;

  const _QuickCategoryChip({
    required this.label,
    required this.icon,
    required this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: const Color(0xFFFF7043), size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3F3D56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestSellerCard extends StatelessWidget {
  final ProductModel product;
  final String imageUrl;
  final String priceLabel;
  final double rating;
  final VoidCallback? onTap;

  const _BestSellerCard({
    required this.product,
    required this.imageUrl,
    required this.priceLabel,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRating = rating > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 110,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                      ),
                    )
                  : Container(
                      height: 110,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasRating ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 18,
                        color: hasRating ? const Color(0xFFFFA726) : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasRating ? rating.toStringAsFixed(1) : 'Nuevo',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: hasRating ? const Color(0xFF3F3D56) : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2F2E41),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF7043),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final ProductModel product;
  final String imageUrl;
  final String priceLabel;
  final String unitLabel;
  final String tag;
  final Duration animationDelay;
  final VoidCallback? onTap;

  const _RecommendationCard({
    required this.product,
    required this.imageUrl,
    required this.priceLabel,
    required this.unitLabel,
    required this.tag,
    required this.animationDelay,
    this.onTap,
  });

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Future.delayed(widget.animationDelay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      widget.imageUrl.isNotEmpty
                          ? Image.network(
                              widget.imageUrl,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 120,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                              ),
                            )
                          : Container(
                              height: 120,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                            ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.product.calificacionPromedio > 0
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 16,
                                color: widget.product.calificacionPromedio > 0
                                    ? const Color(0xFFFFA726)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.product.calificacionPromedio > 0
                                    ? widget.product.calificacionPromedio.toStringAsFixed(1)
                                    : 'Nuevo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3F3D56),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7043).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF7043),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2F2E41),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.priceLabel} / ${widget.unitLabel}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B4332),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
