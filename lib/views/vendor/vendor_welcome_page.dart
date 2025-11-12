import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/models/user_model.dart';
import 'package:agromarket/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorWelcomePageContent extends StatefulWidget {
  const VendorWelcomePageContent({super.key});

  @override
  State<VendorWelcomePageContent> createState() => _VendorWelcomePageContentState();
}

class _VendorWelcomePageContentState extends State<VendorWelcomePageContent> {
  bool _loadingStatus = false;
  bool _creatingAccount = false;
  bool? _chargesEnabled;
  bool? _payoutsEnabled;
  bool? _detailsSubmitted;
  String? _statusMessage;
  String? _lastOnboardingUrl;
  bool _statusRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = Provider.of<AuthController>(context, listen: false);
      final vendorId = authController.currentUser?.id;
      if (vendorId != null) {
        _statusRequested = true;
        _loadVendorStatus(vendorId);
      }
    });
  }

  Future<void> _loadVendorStatus([String? vendorId]) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final targetId = vendorId ?? authController.currentUser?.id;

    if (targetId == null) {
      setState(() {
        _statusMessage = 'No se pudo identificar al vendedor actual.';
      });
      return;
    }

    setState(() {
      _loadingStatus = true;
      _statusMessage = null;
    });

    final response = await ApiService.getVendorStatus(targetId);

    if (!mounted) return;

    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      setState(() {
        _chargesEnabled = data['chargesEnabled'] as bool?;
        _payoutsEnabled = data['payoutsEnabled'] as bool?;
        _detailsSubmitted = data['detailsSubmitted'] as bool?;
        _statusMessage = null;
      });
    } else {
      setState(() {
        _statusMessage = response['message'] as String? ?? 'No se pudo obtener el estado de Stripe Connect.';
      });
    }

    setState(() {
      _loadingStatus = false;
    });
  }

  Future<void> _createOrRefreshVendorAccount() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final vendor = authController.currentUser;

    if (vendor == null) {
      setState(() {
        _statusMessage = 'No se pudo obtener la información del vendedor.';
      });
      return;
    }

    setState(() {
      _creatingAccount = true;
      _statusMessage = null;
    });

    final response = await ApiService.createVendorAccount(
      vendorId: vendor.id,
      email: vendor.email,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      final onboardingUrl = data['onboardingUrl'] as String?;
      setState(() {
        _lastOnboardingUrl = onboardingUrl;
        _statusMessage = 'Cuenta creada correctamente. Completa el formulario para activarla.';
      });

      if (onboardingUrl != null) {
        await _launchOnboarding(onboardingUrl);
      }
    } else {
      setState(() {
        _statusMessage = response['message'] as String? ?? 'No se pudo crear la cuenta del vendedor.';
      });
    }

    setState(() {
      _creatingAccount = false;
    });
  }

  Future<void> _launchOnboarding(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      setState(() {
        _statusMessage = 'El enlace de configuración no es válido.';
      });
      return;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      setState(() {
        _statusMessage = 'No se pudo abrir el enlace de configuración.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final user = authController.currentUser;

        if (user != null && !_statusRequested) {
          _statusRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadVendorStatus(user.id);
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con saludo personalizado
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.store,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡Bienvenido, Vendedor!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.nombre ?? 'Usuario',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Gestiona tu tienda y vende tus productos agrícolas de manera eficiente.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                if (user != null && _statusRequested && !(_chargesEnabled == true && _payoutsEnabled == true)) ...[
                  Container(
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
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Completa tu cuenta de vendedor',
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
                        Text(
                          'Necesitas finalizar la configuración de Stripe Connect para poder publicar productos y recibir pagos.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _creatingAccount
                                  ? null
                                  : () {
                                      if (_lastOnboardingUrl != null) {
                                        _launchOnboarding(_lastOnboardingUrl!);
                                      } else {
                                        _createOrRefreshVendorAccount();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB45309),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _creatingAccount
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.lock_open_rounded),
                              label: Text(_lastOnboardingUrl != null ? 'Reanudar configuración' : 'Configurar ahora'),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: _loadingStatus ? null : () => _loadVendorStatus(user.id),
                              icon: _loadingStatus
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                // Estado de Stripe Connect
                if (user != null && _statusRequested) ...[
                  const Text(
                    'Pagos con Stripe Connect',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStripeConnectActionCard(user),
                  const SizedBox(height: 30),
                ],

                // Estadísticas rápidas
                const Text(
                  'Resumen de tu tienda',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Productos',
                        '12',
                        Icons.inventory,
                        const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Ventas',
                        '8',
                        Icons.shopping_cart,
                        const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Ingresos',
                        '\$1,250',
                        Icons.attach_money,
                        const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Calificación',
                        '4.8',
                        Icons.star,
                        const Color(0xFFFFC107),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Acciones rápidas
                const Text(
                  'Acciones rápidas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),

                const SizedBox(height: 16),

                _buildActionCard(
                  context,
                  'Agregar nuevo producto',
                  'Registra un nuevo producto en tu tienda',
                  Icons.add_circle_outline,
                  const Color(0xFF4CAF50),
                  () {
                    // Navegar a agregar producto
                    // Esto se manejará por la navegación
                  },
                ),

                const SizedBox(height: 12),

                _buildActionCard(
                  context,
                  'Ver mis productos',
                  'Gestiona y edita tus productos existentes',
                  Icons.list_alt,
                  const Color(0xFF2196F3),
                  () {
                    // Navegar a lista de productos
                    // Esto se manejará por la navegación
                  },
                ),

                const SizedBox(height: 12),

                _buildActionCard(
                  context,
                  'Ver estadísticas',
                  'Analiza el rendimiento de tu tienda',
                  Icons.analytics,
                  const Color(0xFF9C27B0),
                  () {
                    // Mostrar estadísticas
                    _showStatsDialog(context);
                  },
                ),

                const SizedBox(height: 30),

                // Consejos para vendedores
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Consejo del día',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mantén actualizada la información de tus productos y sube fotos de alta calidad para atraer más compradores.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estadísticas de tu tienda'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.inventory, color: Colors.blue),
              title: Text('Total de productos'),
              trailing: Text('12'),
            ),
            ListTile(
              leading: Icon(Icons.shopping_cart, color: Colors.green),
              title: Text('Ventas este mes'),
              trailing: Text('8'),
            ),
            ListTile(
              leading: Icon(Icons.attach_money, color: Colors.orange),
              title: Text('Ingresos totales'),
              trailing: Text('\$1,250'),
            ),
            ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text('Calificación promedio'),
              trailing: Text('4.8/5'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStripeConnectActionCard(UserModel user) {
    final chargesEnabled = _chargesEnabled == true;
    final payoutsEnabled = _payoutsEnabled == true;
    final detailsSubmitted = _detailsSubmitted == true;
    final displayName = user.nombre.isNotEmpty ? user.nombre : user.email;

    String subtitle;
    Color badgeColor;
    String badgeText;

    if (chargesEnabled && payoutsEnabled) {
      subtitle = 'Tu cuenta está activa y lista para recibir pagos.';
      badgeText = 'Activa';
      badgeColor = Colors.green;
    } else if (detailsSubmitted) {
      subtitle = 'Estamos revisando tu información. Te notificaremos cuando se active.';
      badgeText = 'En revisión';
      badgeColor = Colors.orange;
    } else {
      subtitle = 'Completa el formulario de Stripe para poder recibir pagos.';
      badgeText = 'Pendiente';
      badgeColor = Colors.red;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF115213).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payment, color: Color(0xFF115213), size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pagos con Stripe Connect',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vendedor: $displayName',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _creatingAccount
                      ? null
                      : () {
                          if (chargesEnabled) {
                            _loadVendorStatus(user.id);
                          } else if (_lastOnboardingUrl != null) {
                            _launchOnboarding(_lastOnboardingUrl!);
                          } else {
                            _createOrRefreshVendorAccount();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF115213),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _creatingAccount
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(chargesEnabled ? Icons.refresh : Icons.open_in_new),
                  label: Text(chargesEnabled
                      ? 'Actualizar estado'
                      : (_lastOnboardingUrl != null ? 'Reabrir configuración' : 'Configurar pagos')),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _loadingStatus ? null : () => _loadVendorStatus(user.id),
                icon: _loadingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: Color(0xFF115213)),
              ),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage!,
                style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Mantener la clase original para compatibilidad
class VendorWelcomePage extends StatelessWidget {
  const VendorWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VendorWelcomePageContent();
  }
}
