class SolicitudVendedorModel {
  final String? id; // ID del documento en Firestore
  final String nombre;
  final String email;
  final String? passwordHash; // null en solicitudes
  final String nombreTienda;
  final String ubicacion;
  final String? ubicacionFormatted;
  final double? ubicacionLat;
  final double? ubicacionLng;
  final String documentoUrl;
  final String estado; // 'pendiente', 'aprobada', 'rechazada'
  final DateTime fechaSolicitud;
  final DateTime? fechaRevision;
  final String? revisadoPor; // ID del admin que revisó
  final String? motivoRechazo;
  final String? userId; // ID del usuario si ya existe en Firebase Auth

  SolicitudVendedorModel({
    this.id,
    required this.nombre,
    required this.email,
    this.passwordHash,
    required this.nombreTienda,
    required this.ubicacion,
    this.ubicacionFormatted,
    this.ubicacionLat,
    this.ubicacionLng,
    required this.documentoUrl,
    this.estado = 'pendiente',
    required this.fechaSolicitud,
    this.fechaRevision,
    this.revisadoPor,
    this.motivoRechazo,
    this.userId,
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'email': email,
      'password_hash': passwordHash,
      'nombre_tienda': nombreTienda,
      'ubicacion': ubicacion,
      'ubicacion_formatted': ubicacionFormatted,
      'ubicacion_lat': ubicacionLat,
      'ubicacion_lng': ubicacionLng,
      'documento_url': documentoUrl,
      'estado': estado,
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      'fecha_revision': fechaRevision?.toIso8601String(),
      'revisado_por': revisadoPor,
      'motivo_rechazo': motivoRechazo,
      'user_id': userId,
    };
  }

  // Crear desde Map de Firestore
  factory SolicitudVendedorModel.fromJson(Map<String, dynamic> json, String id) {
    // Helper para convertir Timestamp a DateTime
    DateTime? _parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return null;
      if (timestamp is DateTime) return timestamp;
      if (timestamp is String) return DateTime.tryParse(timestamp);
      // Si es Timestamp de Firestore
      try {
        return timestamp.toDate();
      } catch (e) {
        return null;
      }
    }

    return SolicitudVendedorModel(
      id: id,
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      passwordHash: json['password_hash'],
      nombreTienda: json['nombre_tienda'] ?? '',
      ubicacion: json['ubicacion'] ?? '',
      ubicacionFormatted: json['ubicacion_formatted'],
      ubicacionLat: json['ubicacion_lat']?.toDouble(),
      ubicacionLng: json['ubicacion_lng']?.toDouble(),
      documentoUrl: json['documento_url'] ?? '',
      estado: json['estado'] ?? 'pendiente',
      fechaSolicitud: _parseTimestamp(json['fecha_solicitud']) ?? DateTime.now(),
      fechaRevision: _parseTimestamp(json['fecha_revision']),
      revisadoPor: json['revisado_por'],
      motivoRechazo: json['motivo_rechazo'],
      userId: json['user_id'],
    );
  }
}

