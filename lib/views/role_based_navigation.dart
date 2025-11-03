import 'package:agromarket/views/vendor/list_product_view.dart';
import 'package:agromarket/views/vendor/register_product_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/services/role_service.dart';
import 'package:agromarket/views/profile/profile_view.dart';

class RoleBasedNavigation extends StatefulWidget {
  const RoleBasedNavigation({super.key});

  @override
  State<RoleBasedNavigation> createState() => _RoleBasedNavigationState();
}

class _RoleBasedNavigationState extends State<RoleBasedNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final user = authController.currentUser;
        
        if (user == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Verificar si el usuario está activo
        if (!RoleService.isUserActive(user)) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu cuenta está desactivada',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contacta al administrador para más información',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Determinar las vistas según el rol
        final views = _getViewsForRole(user.rolActivo);
        final bottomNavItems = _getBottomNavItemsForRole(user.rolActivo);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            title: Row(
              children: [
                Text('AgroMovil'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.rolActivo),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRoleDisplayName(user.rolActivo),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            elevation: 0,
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: views,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF2E7D32),
              unselectedItemColor: Colors.grey[600],
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: bottomNavItems,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _getViewsForRole(String role) {
    switch (role) {
      case 'vendedor':
        return [
          const ListProductView(), // Lista de productos del vendedor
          const RegisterProductView(), // Registrar producto
          const ProfileView(), // Perfil
        ];
      case 'comprador':
      default:
        return [ // Vista principal para compradores
          const ProfileView(), // Perfil
        ];
    }
  }

  List<BottomNavigationBarItem> _getBottomNavItemsForRole(String role) {
    switch (role) {
      case 'vendedor':
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Mis Productos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Agregar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ];
      case 'comprador':
      default:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Comprar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ];
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'vendedor':
        return Colors.orange;
      case 'comprador':
        return Colors.blue;
      case 'administrador':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'vendedor':
        return 'VENDEDOR';
      case 'comprador':
        return 'COMPRADOR';
      case 'administrador':
        return 'ADMIN';
      default:
        return role.toUpperCase();
    }
  }
}
