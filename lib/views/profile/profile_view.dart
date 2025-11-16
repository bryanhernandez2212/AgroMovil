import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/views/about/about_view.dart';
import 'package:agromarket/services/user_role_service.dart';
import 'package:agromarket/services/firebase_service.dart';
import 'package:agromarket/services/places_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tiendaController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  List<PlacePrediction> _placePredictions = [];
  bool _showPredictions = false;
  PlaceDetails? _selectedPlace;
  bool _isVendedor = false;
  File? _selectedImageFile;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Cargar datos después de que el frame esté listo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    if (authController.currentUser != null) {
      _nameController.text = authController.currentUser!.nombre;
      _emailController.text = authController.currentUser!.email;
      
      // Cargar datos adicionales desde Firestore
      final userData = await FirebaseService.getCurrentUserData();
      if (userData != null) {
        // Cargar foto de perfil si existe
        if (userData['foto_perfil'] != null) {
          setState(() {
            _profileImageUrl = userData['foto_perfil'] as String;
          });
        }
        // Verificar solo el modo de navegación actual (rol_activo)
        // El rol_activo puede ser 'vendedor' o 'comprador'
        final rolActivo = userData['rol_activo']?.toString().toLowerCase().trim() ?? 'comprador';
        final wasVendedor = _isVendedor;
        _isVendedor = rolActivo == 'vendedor';
        
        print('🔍 ProfileView - rol_activo raw: ${userData['rol_activo']}');
        print('🔍 ProfileView - rol_activo procesado: $rolActivo');
        print('🔍 ProfileView - _isVendedor: $_isVendedor');
        print('🔍 ProfileView - ¿Mostrar campos? $_isVendedor');
        
        // Actualizar estado si cambió
        if (mounted && wasVendedor != _isVendedor) {
          setState(() {
            // Forzar actualización del estado
          });
        }
        
        if (_isVendedor) {
          // Cargar datos del vendedor
          final nombreTienda = userData['nombre_tienda'] ?? '';
          final ubicacion = userData['ubicacion'] ?? userData['ubicacion_formatted'] ?? '';
          
          _tiendaController.text = nombreTienda;
          _ubicacionController.text = ubicacion;
          
          print('🔍 ProfileView - nombre_tienda: $nombreTienda');
          print('🔍 ProfileView - ubicacion: $ubicacion');
        } else {
          // Limpiar campos solo si realmente no es vendedor
          _tiendaController.clear();
          _ubicacionController.clear();
          _selectedPlace = null;
        }
        
        // Forzar actualización del widget después de cargar datos
        if (mounted) {
          setState(() {
            // Actualizar estado para reflejar los cambios
          });
        }
      }
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || query.length < 3) {
      setState(() {
        _placePredictions = [];
        _showPredictions = false;
      });
      return;
    }

    final predictions = await PlacesService.getPlacePredictions(query);
    setState(() {
      _placePredictions = predictions;
      _showPredictions = predictions.isNotEmpty;
    });
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    final details = await PlacesService.getPlaceDetails(prediction.placeId);
    setState(() {
      _selectedPlace = details;
      _ubicacionController.text = prediction.description;
      _showPredictions = false;
      _placePredictions = [];
    });
  }

  Future<void> _pickProfileImage() async {
    try {
      // Mostrar diálogo para elegir fuente
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seleccionar imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF115213)),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF115213)),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar imagen: $e');
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_selectedImageFile == null) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_${user.uid}_$timestamp.jpg';
      final storageRef = storage.ref().child('perfiles/$fileName');

      print('📤 Subiendo foto de perfil...');
      final uploadTask = storageRef.putFile(_selectedImageFile!);
      final snapshot = await uploadTask;
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('✅ Foto de perfil subida exitosamente: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('❌ Error subiendo foto de perfil: $e');
      throw Exception('Error al subir la imagen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF115213)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Mi Perfil',
              style: TextStyle(
                color: Color(0xFF115213),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  
                  // Header con botón de editar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                        GestureDetector(
                          onTap: _isEditing ? _pickProfileImage : null,
                          child: Container(
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
                            child: ClipOval(
                              child: _selectedImageFile != null
                                  ? Image.file(
                                      _selectedImageFile!,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                    )
                                  : _profileImageUrl != null
                                      ? Image.network(
                                          _profileImageUrl!,
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) => const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                            ),
                          ),
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickProfileImage,
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
          
          // Campos adicionales para vendedores (solo cuando rol_activo es 'vendedor')
          if (_isVendedor) ...[
            const SizedBox(height: 20),
            _buildInfoField(
              label: "Nombre de tienda",
              value: _tiendaController.text.isEmpty ? "No especificado" : _tiendaController.text,
              controller: _tiendaController,
              enabled: _isEditing,
            ),
            const SizedBox(height: 20),
            _buildLocationField(),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Ubicación",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        if (_isEditing)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ubicacionController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  hintText: "Ubicación (empieza a escribir...)",
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
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF115213)),
                ),
                onChanged: (value) {
                  _searchPlaces(value);
                },
                onTap: () {
                  if (_ubicacionController.text.isNotEmpty) {
                    _searchPlaces(_ubicacionController.text);
                  }
                },
              ),
              if (_showPredictions && _placePredictions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _placePredictions.length,
                    itemBuilder: (context, index) {
                      final prediction = _placePredictions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: Color(0xFF115213)),
                        title: Text(
                          prediction.description,
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () {
                          _selectPlace(prediction);
                        },
                      );
                    },
                  ),
                ),
            ],
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
              _ubicacionController.text.isEmpty ? "No especificado" : _ubicacionController.text,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
              ),
            ),
          ),
      ],
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
          ],
        );
      },
    );
  }

  Future<void> _switchRole(bool toSeller, AuthController authController) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Actualizar rol_activo en Firestore
      final newRolActivo = toSeller ? 'vendedor' : 'comprador';
      print('🔄 ProfileView - Cambiando rol_activo a: $newRolActivo (toSeller: $toSeller)');
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'rol_activo': newRolActivo,
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('✅ ProfileView - rol_activo actualizado en Firestore');

      // Cambiar el rol en el servicio local
      if (toSeller) {
        UserRoleService.setUserRole(UserRoleService.sellerRole);
      } else {
        UserRoleService.setUserRole(UserRoleService.buyerRole);
      }

      // Recargar datos del usuario
      await authController.reloadUserData();
      await _loadUserData();
      
      // Actualizar el estado local
      setState(() {
        _isVendedor = newRolActivo == 'vendedor';
        _isLoading = false;
        print('🔄 ProfileView - Estado actualizado: _isVendedor = $_isVendedor');
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error al cambiar modo de navegación: ${e.toString()}');
    }
  }

  Future<void> _toggleRole(String role, bool enable, AuthController authController) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener datos actuales del usuario
      final userData = await FirebaseService.getCurrentUserData();
      final currentRolActivo = userData?['rol_activo'] ?? 'comprador';

      if (enable) {
        // Agregar el rol al array en Firestore
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({
          'roles': FieldValue.arrayUnion([role]),
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        // Si se activa el rol de vendedor y no está activo, actualizarlo
        if (role == 'vendedor' && currentRolActivo != 'vendedor') {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .update({
            'rol_activo': 'vendedor',
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        
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
        
        // Si se desactiva el rol de vendedor y estaba activo, cambiar a comprador
        if (role == 'vendedor' && currentRolActivo == 'vendedor') {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .update({
            'rol_activo': 'comprador',
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        
        _showSuccessSnackBar('¡Rol desactivado exitosamente!');
      }

      // Recargar datos del usuario
      await authController.reloadUserData();
      await _loadUserData(); // Recargar también los campos locales
      
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
        _selectedImageFile = null; // Limpiar imagen seleccionada si se cancela
        _loadUserData(); // Recargar datos originales
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _selectedImageFile = null; // Limpiar imagen seleccionada
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

    // Validaciones adicionales para vendedores
    if (_isVendedor) {
      if (_tiendaController.text.trim().isEmpty) {
        _showErrorSnackBar("El nombre de tienda no puede estar vacío");
        return;
      }
      
      if (_ubicacionController.text.trim().isEmpty) {
        _showErrorSnackBar("La ubicación no puede estar vacía");
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Subir foto de perfil si se seleccionó una nueva
      String? newProfileImageUrl;
      if (_selectedImageFile != null) {
        newProfileImageUrl = await _uploadProfileImage();
        if (newProfileImageUrl != null) {
          setState(() {
            _profileImageUrl = newProfileImageUrl;
            _selectedImageFile = null; // Limpiar archivo temporal
          });
        }
      }

      final updateData = <String, dynamic>{
        'nombre': _nameController.text.trim(),
        if (newProfileImageUrl != null) 'foto_perfil': newProfileImageUrl,
      };

      // Agregar campos de vendedor si aplica
      if (_isVendedor) {
        final nombreTienda = _tiendaController.text.trim();
        final ubicacion = _ubicacionController.text.trim();
        
        updateData['nombre_tienda'] = nombreTienda;
        
        // Si se seleccionó un nuevo lugar, usar sus datos
        if (_selectedPlace != null) {
          updateData['ubicacion'] = _selectedPlace!.formattedAddress;
          updateData['ubicacion_formatted'] = _selectedPlace!.formattedAddress;
          if (_selectedPlace!.lat != null && _selectedPlace!.lng != null) {
            updateData['ubicacion_lat'] = _selectedPlace!.lat;
            updateData['ubicacion_lng'] = _selectedPlace!.lng;
          }
          print('💾 ProfileView - Guardando nueva ubicación seleccionada: ${_selectedPlace!.formattedAddress}');
        } else if (ubicacion.isNotEmpty) {
          // Mantener la ubicación actual si no se seleccionó una nueva
          updateData['ubicacion'] = ubicacion;
          updateData['ubicacion_formatted'] = ubicacion;
          print('💾 ProfileView - Guardando ubicación actual: $ubicacion');
          // Nota: No actualizamos las coordenadas si no se seleccionó un nuevo lugar
        } else {
          print('⚠️ ProfileView - Ubicación vacía, no se actualizará');
        }
        
        print('💾 ProfileView - nombre_tienda a guardar: $nombreTienda');
      }

      print('💾 ProfileView - Guardando datos: $updateData');
      final success = await FirebaseService.updateUserData(updateData);
      
      if (success) {
        print('✅ ProfileView - Datos guardados exitosamente');
        
        // Recargar datos del usuario
        final authController = Provider.of<AuthController>(context, listen: false);
        await authController.reloadUserData();
        
        // Recargar datos locales y actualizar estado
        await _loadUserData();
        
        // Asegurar que el estado se actualice correctamente
        setState(() {
          _isEditing = false;
          _isLoading = false;
          _selectedPlace = null; // Limpiar selección
          
          // Verificar que los datos se cargaron correctamente
          print('💾 ProfileView - Después de guardar:');
          print('   - _isVendedor: $_isVendedor');
          print('   - nombre_tienda: ${_tiendaController.text}');
          print('   - ubicacion: ${_ubicacionController.text}');
        });
        
        _showSuccessSnackBar("Perfil actualizado correctamente");
      } else {
        throw Exception('Error al actualizar en Firestore');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar("Error al actualizar el perfil: $e");
    }
  }


  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF115213),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tiendaController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }
}