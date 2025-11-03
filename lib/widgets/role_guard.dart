import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/services/role_service.dart';

class RoleGuard extends StatelessWidget {
  final Widget child;
  final String requiredAction;
  final Widget? fallbackWidget;
  final String? fallbackMessage;

  const RoleGuard({
    super.key,
    required this.child,
    required this.requiredAction,
    this.fallbackWidget,
    this.fallbackMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        final user = authController.currentUser;
        
        if (user == null) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Verificar si el usuario puede realizar la acción
        if (RoleService.canPerformAction(user, requiredAction)) {
          return child;
        }

        // Mostrar widget de fallback o mensaje de error
        if (fallbackWidget != null) {
          return fallbackWidget!;
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  fallbackMessage ?? 'No tienes permisos para acceder a esta función',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tu rol actual: ${RoleService.getPrimaryRole(user)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Widget específico para funcionalidades de vendedor
class VendorGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const VendorGuard({
    super.key,
    required this.child,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      requiredAction: 'create_product',
      fallbackWidget: fallbackWidget,
      fallbackMessage: 'Solo los vendedores pueden acceder a esta función',
      child: child,
    );
  }
}

// Widget específico para funcionalidades de comprador
class BuyerGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallbackWidget;

  const BuyerGuard({
    super.key,
    required this.child,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      requiredAction: 'buy_product',
      fallbackWidget: fallbackWidget,
      fallbackMessage: 'Solo los compradores pueden acceder a esta función',
      child: child,
    );
  }
}
