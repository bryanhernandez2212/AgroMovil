import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String userEmail;
  final String comentario;
  final double calificacion; // 1.0 a 5.0
  final DateTime fechaCreacion;

  CommentModel({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.comentario,
    required this.calificacion,
    required this.fechaCreacion,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? '',
      productId: json['producto_id'] ?? json['productId'] ?? '',
      userId: json['usuario_id'] ?? json['userId'] ?? '',
      userName: json['usuario_nombre'] ?? json['userName'] ?? '',
      userEmail: json['usuario_email'] ?? json['userEmail'] ?? '',
      comentario: json['comentario'] ?? '',
      calificacion: (json['calificacion'] ?? 0.0).toDouble(),
      fechaCreacion: json['fecha_creacion'] != null
          ? (json['fecha_creacion'] is Timestamp
              ? (json['fecha_creacion'] as Timestamp).toDate()
              : DateTime.tryParse(json['fecha_creacion'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'producto_id': productId,
      'usuario_id': userId,
      'usuario_nombre': userName,
      'usuario_email': userEmail,
      'comentario': comentario,
      'calificacion': calificacion,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }
}

