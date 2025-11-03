class ProductModel {
  final String id;
  final bool activo;
  final String categoria;
  final String descripcion;
  final DateTime fechaPublicacion;
  final String imagenUrl;
  final String nombre;
  final double precio;
  final int stock;
  final String unidad;
  final String vendedorEmail;
  final String vendedorId;
  final String vendedorNombre;

  ProductModel({
    required this.id,
    required this.activo,
    required this.categoria,
    required this.descripcion,
    required this.fechaPublicacion,
    required this.imagenUrl,
    required this.nombre,
    required this.precio,
    required this.stock,
    required this.unidad,
    required this.vendedorEmail,
    required this.vendedorId,
    required this.vendedorNombre,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      activo: json['activo'] ?? true,
      categoria: json['categoria'] ?? '',
      descripcion: json['descripcion'] ?? '',
      fechaPublicacion: json['fecha_publicacion'] != null 
          ? DateTime.tryParse(json['fecha_publicacion'].toString()) ?? DateTime.now()
          : DateTime.now(),
      imagenUrl: json['imagen_url'] ?? '',
      nombre: json['nombre'] ?? '',
      precio: (json['precio'] ?? 0.0).toDouble(),
      stock: json['stock'] ?? 0,
      unidad: json['unidad'] ?? 'kg',
      vendedorEmail: json['vendedor_email'] ?? '',
      vendedorId: json['vendedor_id'] ?? '',
      vendedorNombre: json['vendedor_nombre'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activo': activo,
      'categoria': categoria,
      'descripcion': descripcion,
      'fecha_publicacion': fechaPublicacion.toIso8601String(),
      'imagen_url': imagenUrl,
      'nombre': nombre,
      'precio': precio,
      'stock': stock,
      'unidad': unidad,
      'vendedor_email': vendedorEmail,
      'vendedor_id': vendedorId,
      'vendedor_nombre': vendedorNombre,
    };
  }

  // Método para crear un producto desde el formulario de registro
  factory ProductModel.fromForm({
    required String nombre,
    required String categoria,
    required String descripcion,
    required double precio,
    required int stock,
    required String unidad,
    required String imagenUrl,
    required String vendedorEmail,
    required String vendedorId,
    required String vendedorNombre,
    String? id,
  }) {
    return ProductModel(
      id: id ?? '',
      activo: true,
      categoria: categoria,
      descripcion: descripcion,
      fechaPublicacion: DateTime.now(),
      imagenUrl: imagenUrl,
      nombre: nombre,
      precio: precio,
      stock: stock,
      unidad: unidad,
      vendedorEmail: vendedorEmail,
      vendedorId: vendedorId,
      vendedorNombre: vendedorNombre,
    );
  }

  @override
  String toString() {
    return 'ProductModel(id: $id, nombre: $nombre, precio: $precio, stock: $stock, categoria: $categoria)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
