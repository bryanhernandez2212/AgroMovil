import 'package:agromarket/models/user_model.dart';

class RoleService {
  // Verificar si el usuario tiene un rol específico
  static bool hasRole(UserModel user, String role) {
    return user.roles.contains(role);
  }

  // Verificar si el usuario es vendedor
  static bool isVendor(UserModel user) {
    return hasRole(user, 'vendedor');
  }

  // Verificar si el usuario es comprador
  static bool isBuyer(UserModel user) {
    return hasRole(user, 'comprador');
  }

  // Verificar si el usuario es administrador
  static bool isAdmin(UserModel user) {
    return hasRole(user, 'administrador');
  }

  // Verificar si el usuario puede acceder a funcionalidades de vendedor
  static bool canAccessVendorFeatures(UserModel user) {
    return isVendor(user) || isAdmin(user);
  }

  // Verificar si el usuario puede acceder a funcionalidades de comprador
  static bool canAccessBuyerFeatures(UserModel user) {
    return isBuyer(user) || isVendor(user) || isAdmin(user);
  }

  // Obtener el rol principal del usuario
  static String getPrimaryRole(UserModel user) {
    return user.rolActivo;
  }

  // Verificar si el usuario está activo
  static bool isUserActive(UserModel user) {
    return user.activo;
  }

  // Verificar si el usuario puede realizar una acción específica
  static bool canPerformAction(UserModel user, String action) {
    if (!isUserActive(user)) return false;

    switch (action) {
      case 'create_product':
      case 'edit_product':
      case 'delete_product':
      case 'view_my_products':
        return canAccessVendorFeatures(user);
      
      case 'buy_product':
      case 'view_products':
      case 'add_to_cart':
        return canAccessBuyerFeatures(user);
      
      case 'manage_users':
      case 'view_all_products':
        return isAdmin(user);
      
      default:
        return false;
    }
  }

  // Obtener permisos del usuario
  static List<String> getUserPermissions(UserModel user) {
    if (!isUserActive(user)) return [];

    List<String> permissions = [];

    if (isBuyer(user)) {
      permissions.addAll([
        'buy_product',
        'view_products',
        'add_to_cart',
        'view_profile',
        'edit_profile',
      ]);
    }

    if (isVendor(user)) {
      permissions.addAll([
        'create_product',
        'edit_product',
        'delete_product',
        'view_my_products',
        'manage_orders',
      ]);
    }

    if (isAdmin(user)) {
      permissions.addAll([
        'manage_users',
        'view_all_products',
        'manage_system',
        'view_analytics',
      ]);
    }

    return permissions;
  }
}
