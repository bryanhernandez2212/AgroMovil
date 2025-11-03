import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final bool activo;
  final String categoria;
  final String descripcion;
  final DateTime fechaPublicacion;
  final DateTime? fechaActualizacion;
  final String imagenUrl; // Compatibilidad con código existente
  final String? imagen; // Imagen principal
  final List<String> imagenes; // Array de imágenes (hasta 5)
  final String nombre;
  final double precio;
  final int stock;
  final String unidad;
  final String vendedorEmail;
  final String vendedorId;
  final String vendedorNombre;
  final double calificacionPromedio;
  final int totalCalificaciones;
  final int vendido;

  ProductModel({
    required this.id,
    required this.activo,
    required this.categoria,
    required this.descripcion,
    required this.fechaPublicacion,
    this.fechaActualizacion,
    required this.imagenUrl,
    this.imagen,
    this.imagenes = const [],
    required this.nombre,
    required this.precio,
    required this.stock,
    required this.unidad,
    required this.vendedorEmail,
    required this.vendedorId,
    required this.vendedorNombre,
    this.calificacionPromedio = 0.0,
    this.totalCalificaciones = 0,
    this.vendido = 0,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Manejar imagenes como array o convertir de string si es necesario
    List<String> imagenesList = [];
    if (json['imagenes'] != null) {
      if (json['imagenes'] is List) {
        imagenesList = List<String>.from(json['imagenes']);
      }
    }
    
    // La imagen principal puede venir de 'imagen' o 'imagen_url'
    String imagenPrincipal = json['imagen'] ?? json['imagen_url'] ?? '';
    
    // Si hay imagenes pero no imagen principal, usar la primera
    if (imagenPrincipal.isEmpty && imagenesList.isNotEmpty) {
      imagenPrincipal = imagenesList.first;
    }
    
    return ProductModel(
      id: json['id'] ?? '',
      activo: json['activo'] ?? true,
      categoria: json['categoria'] ?? '',
      descripcion: json['descripcion'] ?? '',
      fechaPublicacion: json['fecha_publicacion'] != null 
          ? (json['fecha_publicacion'] is Timestamp
              ? (json['fecha_publicacion'] as Timestamp).toDate()
              : DateTime.tryParse(json['fecha_publicacion'].toString()) ?? DateTime.now())
          : DateTime.now(),
      fechaActualizacion: json['fecha_actualizacion'] != null
          ? (json['fecha_actualizacion'] is Timestamp
              ? (json['fecha_actualizacion'] as Timestamp).toDate()
              : DateTime.tryParse(json['fecha_actualizacion'].toString()))
          : null,
      imagenUrl: imagenPrincipal, // Compatibilidad
      imagen: imagenPrincipal,
      imagenes: imagenesList,
      nombre: json['nombre'] ?? '',
      precio: (json['precio'] ?? 0.0).toDouble(),
      stock: json['stock'] ?? 0,
      unidad: json['unidad'] ?? 'kg',
      vendedorEmail: json['vendedor_email'] ?? json['vendedorEmail'] ?? '',
      vendedorId: json['vendedor_id'] ?? json['vendedorId'] ?? '',
      vendedorNombre: json['vendedor_nombre'] ?? json['vendedorNombre'] ?? '',
      calificacionPromedio: (json['calificacion_promedio'] ?? 0.0).toDouble(),
      totalCalificaciones: json['total_calificaciones'] ?? 0,
      vendido: json['vendido'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    // Determinar la imagen principal (primera del array o imagen individual)
    String imagenPrincipal = imagen ?? (imagenes.isNotEmpty ? imagenes.first : imagenUrl);
    
    return {
      'id': id,
      'activo': activo,
      'categoria': categoria,
      'descripcion': descripcion,
      'fecha_publicacion': fechaPublicacion.toIso8601String(),
      if (fechaActualizacion != null) 'fecha_actualizacion': fechaActualizacion!.toIso8601String(),
      'imagen': imagenPrincipal,
      'imagen_url': imagenPrincipal, // Compatibilidad
      'imagenes': imagenes,
      'nombre': nombre,
      'precio': precio,
      'stock': stock,
      'unidad': unidad,
      'vendedor_email': vendedorEmail,
      'vendedor_id': vendedorId,
      'vendedor_nombre': vendedorNombre,
      'calificacion_promedio': calificacionPromedio,
      'total_calificaciones': totalCalificaciones,
      'vendido': vendido,
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
    List<String> imagenes = const [],
    required String vendedorEmail,
    required String vendedorId,
    required String vendedorNombre,
    String? id,
  }) {
    // Determinar la imagen principal (primera del array o imagen individual)
    String imagenPrincipal = imagenes.isNotEmpty ? imagenes.first : imagenUrl;
    
    return ProductModel(
      id: id ?? '',
      activo: true,
      categoria: categoria,
      descripcion: descripcion,
      fechaPublicacion: DateTime.now(),
      fechaActualizacion: id != null ? DateTime.now() : null, // Si hay ID, es actualización
      imagenUrl: imagenPrincipal, // Compatibilidad
      imagen: imagenPrincipal,
      imagenes: imagenes,
      nombre: nombre,
      precio: precio,
      stock: stock,
      unidad: unidad,
      vendedorEmail: vendedorEmail,
      vendedorId: vendedorId,
      vendedorNombre: vendedorNombre,
      calificacionPromedio: 0.0,
      totalCalificaciones: 0,
      vendido: 0,
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
