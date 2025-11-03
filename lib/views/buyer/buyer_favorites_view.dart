import 'package:flutter/material.dart';
import 'package:agromarket/views/buyer/product_detail_view.dart';

class BuyerFavoritesView extends StatefulWidget {
  const BuyerFavoritesView({super.key});

  @override
  State<BuyerFavoritesView> createState() => _BuyerFavoritesViewState();
}

class _BuyerFavoritesViewState extends State<BuyerFavoritesView> {
  // Datos de ejemplo de productos favoritos
  final List<Map<String, dynamic>> favoriteProducts = [
    {
      'name': 'Aguacates',
      'description': 'Recien cortados y frescos',
      'price': 450.0,
      'unit': 'por kilo',
      'image': 'assets/verduras.png',
    },
    {
      'name': 'Aguacates',
      'description': 'Recien cortados y frescos',
      'price': 450.0,
      'unit': 'por kilo',
      'image': 'assets/frutas.png',
    },
    {
      'name': 'Aguacates',
      'description': 'Recien cortados y frescos',
      'price': 450.0,
      'unit': 'por kilo',
      'image': 'assets/granos.png',
    },
    {
      'name': 'Aguacates',
      'description': 'Recien cortados y frescos',
      'price': 450.0,
      'unit': 'por kilo',
      'image': 'assets/verduras.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header con título y búsqueda
            _buildHeader(),
            
            // Lista de productos favoritos
            Expanded(
              child: favoriteProducts.isEmpty
                  ? _buildEmptyState()
                  : _buildProductList(),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir el borde del input
  OutlineInputBorder _buildInputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No tienes productos favoritos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Agrega productos a favoritos para verlos aquí',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: favoriteProducts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final product = favoriteProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
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
                    product['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['description'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${product['price']} ${product['unit']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF115213),
                    ),
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
                image: DecorationImage(
                  image: AssetImage(product['image']),
                  fit: BoxFit.cover,
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
