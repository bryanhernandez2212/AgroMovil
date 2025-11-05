import 'package:agromarket/models/product_model.dart';

class CartItemModel {
  final String id; // ID único del item en el carrito
  final String productId; // ID del producto
  final String productName;
  final String productImage;
  final double unitPrice;
  final String unit;
  final int quantity;
  final String sellerId;
  final String sellerName;
  
  CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.unitPrice,
    required this.unit,
    required this.quantity,
    required this.sellerId,
    required this.sellerName,
  });

  // Calcular el precio total de este item
  double get totalPrice => unitPrice * quantity;

  // Crear desde un ProductModel
  factory CartItemModel.fromProduct(ProductModel product, int quantity) {
    return CartItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productId: product.id,
      productName: product.nombre,
      productImage: product.imagenes.isNotEmpty 
          ? product.imagenes.first 
          : (product.imagen ?? product.imagenUrl),
      unitPrice: product.precio,
      unit: product.unidad,
      quantity: quantity,
      sellerId: product.vendedorId,
      sellerName: product.vendedorNombre,
    );
  }

  // Convertir a JSON para almacenamiento
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'unitPrice': unitPrice,
      'unit': unit,
      'quantity': quantity,
      'sellerId': sellerId,
      'sellerName': sellerName,
    };
  }

  // Crear desde JSON
  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      productImage: json['productImage'] ?? '',
      unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
      unit: json['unit'] ?? 'kg',
      quantity: json['quantity'] ?? 1,
      sellerId: json['sellerId'] ?? '',
      sellerName: json['sellerName'] ?? '',
    );
  }

  // Copiar con cantidad actualizada
  CartItemModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    double? unitPrice,
    String? unit,
    int? quantity,
    String? sellerId,
    String? sellerName,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
    );
  }
}

