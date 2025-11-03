class UserRoleService {
  // Variable estática para almacenar el rol actual
  static String? _currentRole;
  
  // Roles disponibles
  static const String sellerRole = 'seller';
  static const String buyerRole = 'buyer';
  
  /// Guarda el rol del usuario
  static void setUserRole(String role) {
    _currentRole = role;
  }
  
  /// Obtiene el rol del usuario
  static String? getUserRole() {
    return _currentRole;
  }
  
  /// Verifica si el usuario es vendedor
  static bool isSeller() {
    return _currentRole == sellerRole;
  }
  
  /// Verifica si el usuario es comprador
  static bool isBuyer() {
    return _currentRole == buyerRole;
  }
  
  /// Limpia el rol del usuario (para logout)
  static void clearUserRole() {
    _currentRole = null;
  }
}
