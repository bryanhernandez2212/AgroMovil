import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/views/profile/profile_view.dart';
import 'package:agromarket/views/profile/notifications_view.dart';
import 'package:agromarket/views/profile/chat_view.dart';
import 'package:agromarket/views/about/about_view.dart';
import 'package:agromarket/services/user_role_service.dart';
import 'package:agromarket/views/buyer/my_orders_view.dart';
import 'package:agromarket/views/vendor/seller_orders_view.dart';
import 'package:agromarket/views/auth/login_view.dart';
import 'package:agromarket/services/notification_service.dart';
import 'package:agromarket/controllers/theme_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class UserProfileMenuView extends StatefulWidget {
  const UserProfileMenuView({super.key});

  @override
  State<UserProfileMenuView> createState() => _UserProfileMenuViewState();
}

class _UserProfileMenuViewState extends State<UserProfileMenuView> {
  bool _statusRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = Provider.of<AuthController>(context, listen: false);
      final user = authController.currentUser;
      if (user != null && UserRoleService.isSeller()) {
        _statusRequested = true;
      }
    });
  }

  Future<void> _openWebDashboard() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final user = authController.currentUser;
    if (user == null) return;

    final uri = Uri.parse('https://dashboard.stripe.com/login');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openSupportPage() async {
    try {
      final uri = Uri.parse('https://agromarkett.up.railway.app/soporte');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo abrir la página de soporte'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir la página: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// Trunca el nombre si excede el máximo de caracteres
  String _truncateName(String name, {int maxLength = 25}) {
    if (name.length <= maxLength) {
      return name;
    }
    return '${name.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authController = Provider.of<AuthController>(context);
    final userModel = authController.currentUser;
    final isVendedor = UserRoleService.isSeller();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomInset + 32),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Header con foto, nombre e ícono de perfil
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Foto del usuario
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E7D32) : const Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: userModel?.fotoPerfil != null
                            ? Image.network(
                                userModel!.fotoPerfil!,
                                fit: BoxFit.cover,
                                width: 70,
                                height: 70,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Nombre del usuario
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _truncateName(
                              userModel?.nombre ?? user?.displayName ?? 'Usuario',
                              maxLength: 25,
                            ),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user?.email != null)
                            Text(
                              user!.email!,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Ícono para ir al perfil
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileView(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              if (isVendedor && _statusRequested)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Configura tus pagos',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Completa Stripe Connect para publicar productos y recibir compras.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _openWebDashboard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB45309),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Abrir portal web'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Botones de opciones
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildMenuButton(
                      context,
                      icon: Icons.notifications_outlined,
                      title: 'Notificaciones',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsView(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuButton(
                      context,
                      icon: isVendedor ? Icons.sell_outlined : Icons.shopping_bag_outlined,
                      title: isVendedor ? 'Ventas' : 'Mis compras',
                      onTap: () {
                        if (isVendedor) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SellerOrdersView(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyOrdersView(),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuButton(
                      context,
                      icon: Icons.chat_bubble_outline,
                      title: 'Chat',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatView(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuButton(
                      context,
                      icon: Icons.help_outline,
                      title: 'Ayuda',
                      onTap: () => _openSupportPage(),
                    ),
                    const SizedBox(height: 8),
                    _buildMenuButton(
                      context,
                      icon: Icons.info_outline,
                      title: 'Acerca de',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutView(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildThemeToggleButton(context),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Botones de acción crítica al final
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildMenuButton(
                      context,
                      icon: Icons.logout,
                      title: 'Cerrar Sesión',
                      onTap: () => _showLogoutDialog(context, authController),
                      isDestructive: false,
                    ),
                    const SizedBox(height: 8),
                    _buildMenuButton(
                      context,
                      icon: Icons.delete_outline,
                      title: 'Eliminar Cuenta',
                      onTap: () => _showDeleteDialog(context),
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDestructive ? Colors.red : (isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32));
    final backgroundColor = isDestructive ? Colors.red.withOpacity(0.1) : (isDark ? const Color(0xFF4CAF50).withOpacity(0.1) : const Color(0xFF2E7D32).withOpacity(0.1));
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive 
                ? Colors.red.withOpacity(0.3) 
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDestructive 
                      ? Colors.red 
                      : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                ),
              ),
            ),
            if (!isDestructive)
              Icon(
                Icons.chevron_right,
                color: iconColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggleButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ThemeController>(
      builder: (context, themeController, child) {
        final isDarkMode = themeController.isDarkMode;
        
        return InkWell(
          onTap: () {
            themeController.toggleTheme();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? const Color(0xFF4CAF50).withOpacity(0.1) 
                        : const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isDarkMode ? 'Modo claro' : 'Modo oscuro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    themeController.toggleTheme();
                  },
                  activeColor: isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, AuthController authController) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          Consumer<AuthController>(
            builder: (dialogContext, authController, child) {
              return TextButton(
                onPressed: authController.isLoggingOut ? null : () async {
                  // Prevenir múltiples clics
                  if (authController.isLoggingOut) {
                    print('⚠️ Logout ya en progreso, ignorando clic');
                    return;
                  }
                  
                  print('🔘 Usuario confirmó logout');
                  
                  // Cerrar el diálogo primero
                  Navigator.of(dialogContext).pop();
                  
                  // Navegar a login PRIMERO para evitar que se vea la app sin usuario
                  final navigator = NotificationService.navigatorKey.currentState;
                  if (navigator != null) {
                    print('🧭 Navegando a login ANTES del logout...');
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                    print('✅ Navegación a login completada');
                  }
                  
                  // Esperar un momento para que la navegación se procese
                  await Future.delayed(const Duration(milliseconds: 100));
                  
                  // Hacer logout después de navegar para limpiar el estado
                  print('🚪 Iniciando logout...');
                  await authController.logout();
                  print('✅ Logout completado');
                },
                child: authController.isLoggingOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cerrar sesión'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Función de eliminación no implementada'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
