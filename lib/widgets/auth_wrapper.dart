import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/views/auth/login_view.dart';
import 'package:agromarket/views/auth/options_views.dart';
import 'package:agromarket/estructure/product_estructure.dart';
import 'package:agromarket/services/user_role_service.dart';
import 'package:agromarket/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Widget que maneja la navegación basada en el estado de autenticación
/// Verifica si hay una sesión activa y redirige automáticamente
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  /// Verifica el estado de autenticación al iniciar la app
  Future<void> _checkInitialAuth() async {
    try {
      final authController = Provider.of<AuthController>(context, listen: false);
      
      // Verificar si hay un usuario autenticado en Firebase
      if (FirebaseService.isUserSignedIn()) {
        print('✅ Usuario autenticado encontrado, cargando datos...');
        // Cargar datos del usuario
        await authController.checkAuthStatus();
      } else {
        print('ℹ️ No hay sesión activa');
      }
    } catch (e) {
      print('❌ Error verificando autenticación inicial: $e');
    }
  }

  /// Navega a la pantalla apropiada según el estado del usuario
  void _navigateToAppropriateScreen(BuildContext context, AuthController authController) {
    if (_hasNavigated) return; // Evitar múltiples navegaciones
    
    final user = authController.currentUser;
    if (user == null) return;
    
    final roles = user.roles;

    _hasNavigated = true;

    if (roles.length <= 1) {
      // Un solo rol: dirigir directo a su estructura
      final singleRole = roles.isNotEmpty ? roles.first : 'comprador';
      if (singleRole.toLowerCase().contains('vend')) {
        UserRoleService.setUserRole(UserRoleService.sellerRole);
      } else {
        UserRoleService.setUserRole(UserRoleService.buyerRole);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProductEstructureView()),
      );
    } else {
      // Tiene más de un rol: mostrar opciones
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OptionPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseService.authStateChanges,
      builder: (context, snapshot) {
        // Mostrar pantalla de carga mientras se verifica la autenticación inicial
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Consumer<AuthController>(
          builder: (context, authController, child) {
            // Si hay un usuario autenticado en Firebase y en el controller
            if (snapshot.hasData && 
                authController.isLoggedIn && 
                authController.currentUser != null) {
              // Usar un Future.microtask para navegar después del build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_hasNavigated) {
                  _navigateToAppropriateScreen(context, authController);
                }
              });
              
              // Mostrar pantalla de carga mientras navega
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Si no está autenticado, mostrar la pantalla de login
            // Resetear el flag de navegación cuando el usuario cierra sesión
            if (!snapshot.hasData) {
              _hasNavigated = false;
            }
            
            return const LoginPage();
          },
        );
      },
    );
  }
}

