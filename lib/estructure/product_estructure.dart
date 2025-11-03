import 'package:agromarket/views/profile/profile_view.dart';
import 'package:agromarket/views/vendor/list_product_view.dart';
import 'package:agromarket/views/vendor/register_product_view.dart';
import 'package:agromarket/views/buyer/buyer_home_view.dart';
import 'package:agromarket/views/buyer/buyer_cart_view.dart';
import 'package:agromarket/views/buyer/buyer_list_productos.dart';
import 'package:agromarket/services/user_role_service.dart';
import 'package:agromarket/widgets/banner_ad_widget.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

class ProductEstructureView extends StatefulWidget {
  final Widget? content;
  final String searchHint;
  final String? title; // 
  final VoidCallback? onProfileTap;
  final VoidCallback? onProductsTap;
  final VoidCallback? onCartTap;
  final Function(String)? onSearchChanged;

  final bool showSearchBar;
  final int currentIndex;

  const ProductEstructureView({
    super.key,
    this.content,
    this.title, 
    this.searchHint = "Buscar...",
    this.onProfileTap,
    this.onProductsTap,
    this.onCartTap,
    this.onSearchChanged,
    this.showSearchBar = true,
    this.currentIndex = 0, // inicializa en home
  });

  @override
  State<ProductEstructureView> createState() => _ProductEstructureViewState();
}

class _ProductEstructureViewState extends State<ProductEstructureView> {
  late int currentIndex;
  Widget? _currentContent;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.currentIndex;
    _currentContent = widget.content ?? _getContentForIndex(currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final currentTitle = _getTitleForIndex(currentIndex);
    final isBuyer = UserRoleService.isBuyer();
    
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: SafeArea(
          top: true,
          bottom: false,
          child: Container(
            color: Colors.white,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Título específico para registro de productos - primero para evitar espacio verde
            if (!isBuyer && currentIndex == 1)
              Container(
                color: Colors.white,
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 8,
                  left: 20,
                  right: 20,
                ),
                child: const Text(
                  'Agregar producto',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115213),
                  ),
                ),
              ),
            
            // Banner "AgroMarket" - solo para compradores en Home
            if (isBuyer && currentIndex == 0)
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
                child: Text(
                  'AgroMarket',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115213),
                  ),
                ),
              ),
            
            // Barra de búsqueda - solo para compradores en Home
            if (isBuyer && currentIndex == 0 && widget.showSearchBar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(30),
                    shadowColor: Colors.black26,
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF115213)),
                        hintText: 'Buscar productos...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: _buildInputBorder(const Color(0xFF115213), 1),
                        focusedBorder: _buildInputBorder(const Color(0xFF115213), 2),
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
                  ),
                ),
              ),
            
            // Título para otras vistas
            if (currentTitle != null)
              Container(
                color: Colors.white,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 8),
                child: Text(
                  currentTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115213),
                  ),
                ),
              ),

            _buildContentArea(),
          ],
        ),
          ),
        ),
      ),
      bottomNavigationBar: Stack(
        children: [
          _buildCurvedNavigationBar(),
          // Banner de AdMob en la parte superior de la barra de navegación
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BannerAdWidget(
              alignment: Alignment.topCenter,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: _currentContent ?? _buildEmptyContent(),
      ),
    );
  }
  Widget _buildEmptyContent() {
    return const Center(
      child: Text(
        'Contenido vacío',
        style: TextStyle(
          color: Color(0xFF666666),
          fontSize: 16,
        ),
      ),
    );
  }

  /// Barra de navegación inferior
  Widget _buildCurvedNavigationBar() {
    return CurvedNavigationBar(
      index: currentIndex,
      height: 75,
      backgroundColor: Colors.transparent,
      color: const Color(0xFF226602),
      buttonBackgroundColor: const Color(0xFF226602),
      animationCurve: Curves.easeInOut,
      animationDuration: const Duration(milliseconds: 600),
      items: _buildNavigationItems(),
      onTap: _onNavigationItemTapped,
    );
  }

  /// Elementos de navegación
  List<Widget> _buildNavigationItems() {
    final isBuyer = UserRoleService.isBuyer();
    
    if (isBuyer) {
      // Navegación para compradores
      return [
        _buildNavItem(Icons.home_outlined, currentIndex == 0), 
        _buildNavItem(Icons.favorite_outline, currentIndex == 1), 
        _buildNavItem(Icons.shopping_cart_outlined, currentIndex == 2), 
        _buildNavItem(Icons.person, currentIndex == 3),
      ];
    } else {
      // Navegación para vendedores
      return [
        _buildNavItem(Icons.home_outlined, currentIndex == 0), 
        _buildNavItem(Icons.add, currentIndex == 1), 
        _buildNavItem(Icons.add, currentIndex == 2), 
        _buildNavItem(Icons.person, currentIndex == 3),
      ];
    }
  }

  /// Maneja los taps de navegación
  void _onNavigationItemTapped(int index) {
    setState(() {
      currentIndex = index;
      _currentContent = _getContentForIndex(index);
    });
  }

  /// Obtiene el contenido correspondiente al índice
  Widget _getContentForIndex(int index) {
    final isBuyer = UserRoleService.isBuyer();
    
    if (isBuyer) {
      // Contenido para compradores
      switch (index) {
        case 0:
          return const BuyerHomeView();
        case 1:
          return const BuyerListProductosView();
        case 2:
          return const BuyerCartView();
        case 3:
          return const ProfileView();
        default:
          return _buildEmptyContent();
      }
    } else {
      // Contenido para vendedores
      switch (index) {
        case 0:
          return _buildHomeContent();
        case 1:
          return const RegisterProductView();
        case 2:
          return const ListProductView();
        case 3:
          return const ProfileView();
        default:
          return _buildEmptyContent();
      }
    }
  }

  /// Obtiene el título correspondiente al índice
  String? _getTitleForIndex(int index) {
    final isBuyer = UserRoleService.isBuyer();
    
    if (isBuyer) {
      // Títulos para compradores
      switch (index) {
        case 0:
          return null; // Home no tiene título, usa el banner "AgroMarket"
        case 1:
          return 'Favoritos';
        case 2:
          return 'Carrito de compras';
        case 3:
          return null; 
        default:
          return null;
      }
    } else {
      // Títulos para vendedores
      switch (index) {
        case 0:
          return null; 
        case 1:
          return null; // Sin título para registro de productos
        case 2:
          return 'Mis productos';
        case 3:
          return null; 
        default:
          return null;
      }
    }
  }


  /// Contenido para la pestaña Home
  Widget _buildHomeContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home,
            size: 80,
            color: Color.fromARGB(255, 255, 255, 255),
          ),
          SizedBox(height: 20),
          Text(
            'Bienvenido a AgroMarket',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115213),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Tu plataforma de productos agrícolas',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }


  /// Ícono individual de navegación
  Widget _buildNavItem(IconData icon, bool isSelected) {
    return Icon(
      icon,
      size: 28,
      color: isSelected ? Colors.white : const Color.fromARGB(255, 255, 255, 255),
    );
  }

  /// Construye el borde del input de búsqueda
  OutlineInputBorder _buildInputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
