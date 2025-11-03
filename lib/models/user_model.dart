class UserModel {
  final String id; // Cambiado de int a String para Firebase UID
  final String nombre;
  final String email;
  final bool activo;
  final String rolActivo;
  final List<String> roles;
  final DateTime? fechaRegistro;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.nombre,
    required this.email,
    this.activo = true,
    this.rolActivo = 'comprador',
    this.roles = const ['comprador'],
    this.fechaRegistro,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      activo: json['activo'] ?? true,
      rolActivo: json['rol_activo'] ?? 'comprador',
      roles: json['roles'] != null 
          ? List<String>.from(json['roles'])
          : ['comprador'],
      fechaRegistro: json['fecha_registro'] != null 
          ? DateTime.tryParse(json['fecha_registro'].toString())
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'activo': activo,
      'rol_activo': rolActivo,
      'roles': roles,
      if (fechaRegistro != null) 'fecha_registro': fechaRegistro!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UserModel(id: $id, nombre: $nombre, email: $email, activo: $activo, rolActivo: $rolActivo, roles: $roles)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id && other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
