import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/views/auth/login_view.dart';
import 'package:agromarket/views/about/about_view.dart';
import 'package:agromarket/services/user_role_service.dart';
import 'package:agromarket/estructure/product_estructure.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authController = Provider.of<AuthController>(context, listen: false);
    if (authController.currentUser != null) {
      _nameController.text = authController.currentUser!.nombre;
      _emailController.text = authController.currentUser!.email;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Header con título y botón de editar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Mi Perfil",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF115213),
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleEditMode,
                        icon: Icon(
                          _isEditing ? Icons.close : Icons.edit,
                          color: const Color(0xFF115213),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  // Foto de perfil
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF115213),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFF115213),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Información del usuario
                  _buildInfoCard(authController),
                  
                  const SizedBox(height: 30),

                  // Botones de acción
                  if (_isEditing) _buildEditButtons() else _buildActionButtons(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(AuthController authController) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoField(
            label: "Nombre completo",
            value: authController.currentUser?.nombre ?? "No disponible",
            controller: _nameController,
            enabled: _isEditing,
          ),
          
          const SizedBox(height: 20),
          
          _buildInfoField(
            label: "Correo electrónico",
            value: authController.currentUser?.email ?? "No disponible",
            controller: _emailController,
            enabled: _isEditing,
          ),
          
          const SizedBox(height: 20),
          
          _buildInfoField(
            label: "Contraseña",
            value: "••••••••",
            controller: _passwordController,
            enabled: _isEditing,
            obscure: true,
            isPassword: true,
          ),
          
          const SizedBox(height: 20),
          
          _buildInfoField(
            label: "Miembro desde",
            value: authController.currentUser?.createdAt != null 
                ? _formatDate(authController.currentUser!.createdAt!)
                : "No disponible",
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
    TextEditingController? controller,
    bool enabled = false,
    bool obscure = false,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        if (enabled)
          TextField(
            controller: controller,
            obscureText: obscure,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: value,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF115213),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Guardar cambios",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),     
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _cancelEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF115213),
              side: const BorderSide(color: Color(0xFF115213)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Cancelar",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final user = authController.currentUser;
        final currentRole = UserRoleService.getUserRole();
        
        final roles = user?.roles ?? const <String>[];
        final hasSeller = roles.any((r) => r.toLowerCase().contains('vend'));
        final hasBuyer = roles.any((r) => r.toLowerCase().contains('compr') || r.toLowerCase().contains('buyer'));

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF115213)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Modo de navegación",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF115213),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    value: UserRoleService.sellerRole,
                    groupValue: currentRole ?? (hasSeller ? UserRoleService.sellerRole : UserRoleService.buyerRole),
                    onChanged: hasSeller ? (val) => _switchRole(true, authController) : null,
                    activeColor: const Color(0xFF115213),
                    title: const Text('🏪 Modo Vendedor'),
                  ),
                  RadioListTile<String>(
                    value: UserRoleService.buyerRole,
                    groupValue: currentRole ?? (hasSeller ? UserRoleService.sellerRole : UserRoleService.buyerRole),
                    onChanged: hasBuyer ? (val) => _switchRole(false, authController) : null,
                    activeColor: const Color(0xFF115213),
                    title: const Text('🛒 Modo Comprador'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF115213)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Gestionar roles",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF115213),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.store,
                            color: hasSeller ? const Color(0xFF4CAF50) : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rol Vendedor',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              Text(
                                'Publicar y vender productos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: hasSeller,
                        onChanged: (value) => _toggleRole('vendedor', value, authController),
                        activeColor: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_cart,
                            color: hasBuyer ? const Color(0xFF1976D2) : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rol Comprador',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              Text(
                                'Explorar y comprar productos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: hasBuyer,
                        onChanged: (value) => _toggleRole('comprador', value, authController),
                        activeColor: const Color(0xFF1976D2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _navigateToAbout,
                icon: const Icon(Icons.info_outline, size: 20),
                label: const Text("Acerca de"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF115213),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showLogoutDialog,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text("Cerrar Sesión"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F5C8),
                  foregroundColor: const Color(0xFF115213),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _showDeleteDialog,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text("Eliminar Cuenta"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _switchRole(bool toSeller, AuthController authController) {
    // Cambiar el rol en el servicio
    if (toSeller) {
      UserRoleService.setUserRole(UserRoleService.sellerRole);
    } else {
      UserRoleService.setUserRole(UserRoleService.buyerRole);
    }
    
    // Navegar a la estructura con el nuevo rol
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ProductEstructureView(),
      ),
    );
  }

  Future<void> _toggleRole(String role, bool enable, AuthController authController) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      if (enable) {
        // Agregar el rol al array en Firestore
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({
          'roles': FieldValue.arrayUnion([role]),
          'updated_at': FieldValue.serverTimestamp(),
        });
        _showSuccessSnackBar('¡Rol activado exitosamente!');
      } else {
        // Remover el rol del array en Firestore
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({
          'roles': FieldValue.arrayRemove([role]),
          'updated_at': FieldValue.serverTimestamp(),
        });
        _showSuccessSnackBar('¡Rol desactivado exitosamente!');
      }

      // Recargar datos del usuario
      await authController.reloadUserData();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error al modificar rol: ${e.toString()}');
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _loadUserData(); // Recargar datos originales
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _loadUserData(); // Recargar datos originales
    });
  }

  void _navigateToAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutView()),
    );
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar("El nombre no puede estar vacío");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Aquí puedes agregar la lógica para actualizar el perfil
      // final authController = Provider.of<AuthController>(context, listen: false);
      // await authController.updateProfile(...)
      
      await Future.delayed(const Duration(seconds: 1)); // Simular llamada API
      
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
      
      _showSuccessSnackBar("Perfil actualizado correctamente");
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar("Error al actualizar el perfil: $e");
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final authController = Provider.of<AuthController>(context, listen: false);
              await authController.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
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
              _showErrorSnackBar("Función de eliminación no implementada");
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF115213),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}