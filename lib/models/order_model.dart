import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productoId;
  final String nombre;
  final String imagen;
  final double precioUnitario;
  final double precioTotal;
  final int cantidad;
  final String unidad;
  final String vendedorId;
  final String estadoPedido;
  final DateTime? fechaActualizacionEstado;

  OrderItem({
    required this.productoId,
    required this.nombre,
    required this.imagen,
    required this.precioUnitario,
    required this.precioTotal,
    required this.cantidad,
    required this.unidad,
    required this.vendedorId,
    this.estadoPedido = 'preparando',
    this.fechaActualizacionEstado,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productoId: json['producto_id'] ?? '',
      nombre: json['nombre'] ?? '',
      imagen: json['imagen'] ?? '',
      precioUnitario: (json['precio_unitario'] ?? 0.0).toDouble(),
      precioTotal: (json['precio_total'] ?? 0.0).toDouble(),
      cantidad: json['cantidad'] ?? 0,
      unidad: json['unidad'] ?? 'kg',
      vendedorId: json['vendedor_id'] ?? '',
      estadoPedido: json['estado_pedido'] ?? 'preparando',
      fechaActualizacionEstado: json['fecha_actualizacion_estado'] != null
          ? (json['fecha_actualizacion_estado'] is Timestamp
              ? (json['fecha_actualizacion_estado'] as Timestamp).toDate()
              : DateTime.tryParse(json['fecha_actualizacion_estado'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'producto_id': productoId,
      'nombre': nombre,
      'imagen': imagen,
      'precio_unitario': precioUnitario,
      'precio_total': precioTotal,
      'cantidad': cantidad,
      'unidad': unidad,
      'vendedor_id': vendedorId,
      'estado_pedido': estadoPedido,
      if (fechaActualizacionEstado != null)
        'fecha_actualizacion_estado': fechaActualizacionEstado!.toIso8601String(),
    };
  }
}

class OrderModel {
  final String id;
  final String usuarioId;
  final String usuarioNombre;
  final String usuarioEmail;
  final String ciudad;
  final String telefono;
  final String? direccionEntrega;
  final String formatted;
  final double envio;
  final double subtotal;
  final double impuestos;
  final double total;
  final String estado;
  final String estadoPedido;
  final String metodoPago;
  final String? paymentIntentId;
  final DateTime fechaCompra;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacionEstado;
  final List<OrderItem> productos;

  OrderModel({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.usuarioEmail,
    required this.ciudad,
    required this.telefono,
    this.direccionEntrega,
    required this.formatted,
    required this.envio,
    required this.subtotal,
    required this.impuestos,
    required this.total,
    required this.estado,
    required this.estadoPedido,
    required this.metodoPago,
    this.paymentIntentId,
    required this.fechaCompra,
    required this.fechaCreacion,
    this.fechaActualizacionEstado,
    required this.productos,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItem> productosList = [];
    if (json['productos'] != null && json['productos'] is List) {
      productosList = (json['productos'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return OrderModel(
      id: json['id'] ?? '',
      usuarioId: json['usuario_id'] ?? '',
      usuarioNombre: json['usuario_nombre'] ?? '',
      usuarioEmail: json['usuario_email'] ?? '',
      ciudad: json['ciudad'] ?? '',
      telefono: json['telefono'] ?? '',
      direccionEntrega: json['direccion_entrega'] != null 
          ? (json['direccion_entrega'] is String 
              ? json['direccion_entrega'] 
              : json['direccion_entrega'].toString())
          : null,
      formatted: json['formatted'] ?? '',
      envio: (json['envio'] ?? 0.0).toDouble(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      impuestos: (json['impuestos'] ?? 0.0).toDouble(),
      total: (json['total'] ?? 0.0).toDouble(),
      estado: json['estado'] ?? 'pendiente',
      estadoPedido: json['estado_pedido'] ?? 'preparando',
      metodoPago: json['metodo_pago'] ?? 'tarjeta',
      paymentIntentId: json['payment_intent_id'],
      fechaCompra: json['fecha_compra'] != null
          ? (json['fecha_compra'] is Timestamp
              ? (json['fecha_compra'] as Timestamp).toDate()
              : DateTime.tryParse(json['fecha_compra'].toString()) ?? DateTime.now())
          : DateTime.now(),
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.tryParse(json['fecha_creacion'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fechaActualizacionEstado: json['fecha_actualizacion_estado'] != null
          ? (json['fecha_actualizacion_estado'] is Timestamp
              ? (json['fecha_actualizacion_estado'] as Timestamp).toDate()
              : DateTime.tryParse(json['fecha_actualizacion_estado'].toString()))
          : null,
      productos: productosList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'usuario_email': usuarioEmail,
      'ciudad': ciudad,
      'telefono': telefono,
      if (direccionEntrega != null && direccionEntrega!.isNotEmpty) 'direccion_entrega': direccionEntrega,
      'formatted': formatted,
      'envio': envio,
      'subtotal': subtotal,
      'impuestos': impuestos,
      'total': total,
      'estado': estado,
      'estado_pedido': estadoPedido,
      'metodo_pago': metodoPago,
      if (paymentIntentId != null) 'payment_intent_id': paymentIntentId,
      'fecha_compra': fechaCompra.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      if (fechaActualizacionEstado != null)
        'fecha_actualizacion_estado': fechaActualizacionEstado!.toIso8601String(),
      'productos': productos.map((item) => item.toJson()).toList(),
    };
  }

  // Crear orden desde el carrito
  factory OrderModel.fromCart({
    required String usuarioId,
    required String usuarioNombre,
    required String usuarioEmail,
    required String ciudad,
    required String telefono,
    String? direccionEntrega,
    required String metodoPago,
    required List<OrderItem> productos,
    double? envio,
    String? paymentIntentId,
  }) {
    double subtotal = productos.fold(0.0, (sum, item) => sum + item.precioTotal);
    double costoEnvio = envio ?? 0.0;
    double impuestos = subtotal * 0.10; // 10% de impuestos
    double total = subtotal + costoEnvio + impuestos;

    String formatted = '$ciudad (Tel: $telefono)';

    return OrderModel(
      id: '',
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      usuarioEmail: usuarioEmail,
      ciudad: ciudad,
      telefono: telefono,
      direccionEntrega: direccionEntrega,
      formatted: formatted,
      envio: costoEnvio,
      subtotal: subtotal,
      impuestos: impuestos,
      total: total,
      estado: 'pagado',
      estadoPedido: 'preparando',
      metodoPago: metodoPago,
      paymentIntentId: paymentIntentId,
      fechaCompra: DateTime.now(),
      fechaCreacion: DateTime.now(),
      productos: productos,
    );
  }

  // Método copyWith para actualizar propiedades
  OrderModel copyWith({
    String? id,
    String? usuarioId,
    String? usuarioNombre,
    String? usuarioEmail,
    String? ciudad,
    String? telefono,
    String? direccionEntrega,
    String? formatted,
    double? envio,
    double? subtotal,
    double? impuestos,
    double? total,
    String? estado,
    String? estadoPedido,
    String? metodoPago,
    String? paymentIntentId,
    DateTime? fechaCompra,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacionEstado,
    List<OrderItem>? productos,
  }) {
    return OrderModel(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      usuarioNombre: usuarioNombre ?? this.usuarioNombre,
      usuarioEmail: usuarioEmail ?? this.usuarioEmail,
      ciudad: ciudad ?? this.ciudad,
      telefono: telefono ?? this.telefono,
      direccionEntrega: direccionEntrega ?? this.direccionEntrega,
      formatted: formatted ?? this.formatted,
      envio: envio ?? this.envio,
      subtotal: subtotal ?? this.subtotal,
      impuestos: impuestos ?? this.impuestos,
      total: total ?? this.total,
      estado: estado ?? this.estado,
      estadoPedido: estadoPedido ?? this.estadoPedido,
      metodoPago: metodoPago ?? this.metodoPago,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      fechaCompra: fechaCompra ?? this.fechaCompra,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacionEstado: fechaActualizacionEstado ?? this.fechaActualizacionEstado,
      productos: productos ?? this.productos,
    );
  }
}

