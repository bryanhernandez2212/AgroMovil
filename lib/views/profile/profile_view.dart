import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/services/user_role_service.dart';
import 'package:agromarket/services/firebase_service.dart';
import 'package:agromarket/services/places_service.dart';
import 'package:agromarket/services/shipping_service.dart';
import 'package:agromarket/services/vendor_request_service.dart';
import 'package:agromarket/models/solicitud_vendedor_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _selectedCity; // Ciudad seleccionada para vendedores
  File? _selectedImageFile;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Para el formulario de solicitud de vendedor
  final TextEditingController _tiendaSolicitudController = TextEditingController();
  final TextEditingController _ubicacionSolicitudController = TextEditingController();
  File? _documentoSolicitud;
  String? _documentoSolicitudFileName;
  String? _selectedCitySolicitud; // Ciudad seleccionada en el formulario de solicitud

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
          
          // Intentar extraer la ciudad de la ubicación
          final ciudad = ShippingService.extractCityFromAddress(ubicacion);
          if (ciudad != null) {
            _selectedCity = ciudad;
          } else {
            // Si no se puede extraer, usar la primera ciudad disponible
            _selectedCity = ShippingService.getAvailableCities().first;
          }
          
          print('🔍 ProfileView - nombre_tienda: $nombreTienda');
          print('🔍 ProfileView - ubicacion: $ubicacion');
          print('🔍 ProfileView - ciudad seleccionada: $_selectedCity');
        } else {
          // Limpiar campos solo si realmente no es vendedor
          _tiendaController.clear();
          _ubicacionController.clear();
          _selectedPlace = null;
          _selectedCity = null;
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
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Seleccionar imagen',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Color(0xFF115213)),
                  title: Text(
                    'Tomar foto',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFF115213)),
                  title: Text(
                    'Elegir de galería',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : const Color(0xFF115213),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Mi Perfil',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF115213),
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
                          color: isDark ? Colors.white : const Color(0xFF115213),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
        Text(
          "Ubicación",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[400]
                : const Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        if (_isEditing)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Para vendedores, usar dropdown con ciudades disponibles
              if (_isVendedor)
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return DropdownButtonFormField<String>(
                      value: _selectedCity,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Ciudad',
                        labelStyle: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        hintText: 'Selecciona tu ciudad',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: const Icon(Icons.location_city, color: Color(0xFF115213)),
                      ),
                      dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                      items: ShippingService.getAvailableCities().map((ciudad) {
                        return DropdownMenuItem<String>(
                          value: ciudad,
                          child: Text(
                            ciudad,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCity = value;
                          if (value != null) {
                            _ubicacionController.text = value;
                            _selectedPlace = null; // Limpiar selección de Places API
                          }
                        });
                      },
                    );
                  },
                )
              else
                // Para no vendedores, usar Places API como antes
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return TextField(
                      controller: _ubicacionController,
                      enabled: _isEditing,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Ubicación (empieza a escribir...)",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
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
                    );
                  },
                ),
              if (!_isVendedor && _showPredictions && _placePredictions.isNotEmpty)
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
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
                        return Builder(
                          builder: (context) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: Color(0xFF115213)),
                              title: Text(
                                prediction.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              onTap: () {
                                _selectPlace(prediction);
                              },
                            );
                          },
                        );
                      },
                    ),
                  );
                  },
                ),
            ],
          )
        else
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Text(
                  _ubicacionController.text.isEmpty ? "No especificado" : _ubicacionController.text,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF333333),
                  ),
                ),
              );
            },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : const Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        if (enabled)
          TextField(
            controller: controller,
            obscureText: obscure,
            enabled: enabled,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: value,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                ),
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
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF333333),
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
        final hasBothRoles = hasSeller && hasBuyer; // Solo mostrar si tiene ambos roles
        final isOnlyBuyer = hasBuyer && !hasSeller; // Solo tiene rol comprador

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          children: [
            // Solo mostrar "Modo de navegación" si el usuario tiene ambos roles
            if (hasBothRoles) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF115213)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Modo de navegación",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF115213),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      value: UserRoleService.sellerRole,
                      groupValue: currentRole ?? (hasSeller ? UserRoleService.sellerRole : UserRoleService.buyerRole),
                      onChanged: hasSeller ? (val) => _switchRole(true, authController) : null,
                      activeColor: const Color(0xFF115213),
                      title: Text(
                        '🏪 Modo Vendedor',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    RadioListTile<String>(
                      value: UserRoleService.buyerRole,
                      groupValue: currentRole ?? (hasSeller ? UserRoleService.sellerRole : UserRoleService.buyerRole),
                      onChanged: hasBuyer ? (val) => _switchRole(false, authController) : null,
                      activeColor: const Color(0xFF115213),
                      title: Text(
                        '🛒 Modo Comprador',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Mensaje informativo cuando solo tiene un rol
            if (!hasBothRoles) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFFF1F8F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF115213).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnlyBuyer ? Icons.store_outlined : Icons.shopping_cart_outlined,
                      color: const Color(0xFF115213),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOnlyBuyer
                                ? '¿Quieres vender productos?'
                                : '¿Quieres comprar productos?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF115213) : const Color(0xFF1B4332),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOnlyBuyer
                                ? 'Activa el rol de vendedor para publicar y vender tus productos agrícolas. Gestiona tus ventas y crece tu negocio en AgroMarket.'
                                : 'Activa el rol de comprador para explorar y comprar productos de diferentes vendedores en AgroMarket.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[300] : const Color(0xFF4A5568),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF115213)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Gestionar roles",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF115213),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rol Vendedor',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF333333),
                                ),
                              ),
                              Text(
                                'Publicar y vender productos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF666666),
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
                            color: hasBuyer 
                                ? (isDark ? Colors.white : const Color(0xFF1976D2))
                                : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rol Comprador',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF333333),
                                ),
                              ),
                              Text(
                                'Explorar y comprar productos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: hasBuyer,
                        onChanged: (value) => _toggleRole('comprador', value, authController),
                        activeColor: isDark ? Colors.white : const Color(0xFF1976D2),
                      ),
                    ],
                  ),
                ],
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

      // Si se intenta cambiar a vendedor, verificar solicitud aprobada
      if (toSeller) {
        // Verificar si el usuario ya tiene ambos roles usando los datos del AuthController
        final currentUser = authController.currentUser;
        final roles = currentUser?.roles ?? const <String>[];
        final hasSellerRole = roles.any((r) => r.toLowerCase().contains('vend'));
        final hasBuyerRole = roles.any((r) => r.toLowerCase().contains('compr') || r.toLowerCase().contains('buyer'));
        
        if (hasSellerRole && hasBuyerRole) {
          // Si ya tiene ambos roles, cambiar directamente sin solicitud
          print('✅ Usuario ya tiene ambos roles, cambiando directamente a modo vendedor...');
        } else {
          // Si no tiene ambos roles, verificar solicitud
          print('🔍 Verificando solicitud de vendedor para el usuario ${user.uid}...');
          
          final solicitud = await VendorRequestService.getSolicitudById(user.uid);
          
          if (solicitud == null) {
            setState(() {
              _isLoading = false;
            });
            // Mostrar formulario para crear solicitud
            await _showVendorRequestForm();
            return;
          }
          
          final estado = solicitud.estado.toLowerCase();
          print('📋 Estado de la solicitud: $estado');
          
          if (estado == 'pendiente') {
            setState(() {
              _isLoading = false;
            });
            _showErrorSnackBar(
              'Tu solicitud de vendedor está pendiente de revisión. '
              'Te notificaremos cuando sea aprobada.'
            );
            return;
          } else if (estado == 'rechazada') {
            setState(() {
              _isLoading = false;
            });
            // Mostrar diálogo con opción de reenviar solicitud
            await _showRejectedRequestDialog(solicitud);
            return;
          } else if (estado != 'aprobada') {
            setState(() {
              _isLoading = false;
            });
            _showErrorSnackBar(
              'Tu solicitud de vendedor tiene un estado inválido. '
              'Por favor, contacta al administrador.'
            );
            return;
          }
          
          print('✅ Solicitud aprobada, cambiando a modo vendedor...');
        }
      }

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
        // Si se intenta activar el rol de vendedor, verificar que exista una solicitud aprobada
        if (role == 'vendedor') {
          // Verificar si el usuario ya tiene ambos roles
          final rolesFromData = userData?['roles'] as List<dynamic>?;
          final rolesList = rolesFromData?.map((r) => r.toString().toLowerCase()).toList() ?? [];
          final hasSellerRole = rolesList.any((r) => r.contains('vend'));
          final hasBuyerRole = rolesList.any((r) => r.contains('compr') || r.contains('buyer'));
          
          if (hasSellerRole && hasBuyerRole) {
            // Si ya tiene ambos roles, activar directamente sin solicitud
            print('✅ Usuario ya tiene ambos roles, activando rol de vendedor directamente...');
          } else {
            // Si no tiene ambos roles, verificar solicitud
            print('🔍 Verificando solicitud de vendedor para el usuario ${user.uid}...');
            
            // Obtener la solicitud de vendedor (el ID del documento es el user.uid)
            final solicitud = await VendorRequestService.getSolicitudById(user.uid);
            
            if (solicitud == null) {
              setState(() {
                _isLoading = false;
              });
              // Mostrar formulario para crear solicitud
              await _showVendorRequestForm();
              return;
            }
            
            final estado = solicitud.estado.toLowerCase();
            print('📋 Estado de la solicitud: $estado');
            
            if (estado == 'pendiente') {
              setState(() {
                _isLoading = false;
              });
              _showErrorSnackBar(
                'Tu solicitud de vendedor está pendiente de revisión. '
                'Te notificaremos cuando sea aprobada.'
              );
              return;
            } else if (estado == 'rechazada') {
              setState(() {
                _isLoading = false;
              });
              // Mostrar diálogo con opción de reenviar solicitud
              await _showRejectedRequestDialog(solicitud);
              return;
            } else if (estado != 'aprobada') {
              setState(() {
                _isLoading = false;
              });
              _showErrorSnackBar(
                'Tu solicitud de vendedor tiene un estado inválido. '
                'Por favor, contacta al administrador.'
              );
              return;
            }
            
            // Si llegamos aquí, la solicitud está aprobada
            print('✅ Solicitud aprobada, activando rol de vendedor...');
          }
        }
        
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
        
        // Para vendedores, usar la ciudad seleccionada del dropdown
        if (_isVendedor && _selectedCity != null) {
          updateData['ubicacion'] = _selectedCity!;
          updateData['ubicacion_formatted'] = _selectedCity!;
          print('💾 ProfileView - Guardando ciudad seleccionada: $_selectedCity');
        } else if (_selectedPlace != null) {
          // Si se seleccionó un nuevo lugar (para no vendedores), usar sus datos
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

  /// Mostrar formulario para crear solicitud de vendedor
  Future<void> _showVendorRequestForm({SolicitudVendedorModel? solicitudAnterior}) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final user = authController.currentUser;
    
    // Validar si el usuario ya tiene ambos roles
    if (user != null) {
      final roles = user.roles;
      final hasSellerRole = roles.any((r) => r.toLowerCase().contains('vend'));
      final hasBuyerRole = roles.any((r) => r.toLowerCase().contains('compr') || r.toLowerCase().contains('buyer'));
      
      if (hasSellerRole && hasBuyerRole) {
        _showErrorSnackBar('Ya tienes ambos roles activos. No es necesario enviar una nueva solicitud.');
        return;
      }
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (user == null) {
      _showErrorSnackBar('Error: Usuario no autenticado');
      return;
    }

    // Si hay una solicitud anterior, pre-llenar los campos
    if (solicitudAnterior != null) {
      _tiendaSolicitudController.text = solicitudAnterior.nombreTienda;
      _ubicacionSolicitudController.text = solicitudAnterior.ubicacionFormatted ?? solicitudAnterior.ubicacion;
      
      // Intentar extraer la ciudad de la ubicación
      final ciudad = ShippingService.extractCityFromAddress(
        solicitudAnterior.ubicacionFormatted ?? solicitudAnterior.ubicacion
      );
      if (ciudad != null) {
        _selectedCitySolicitud = ciudad;
      } else {
        // Si no se puede extraer, usar la primera ciudad disponible
        _selectedCitySolicitud = ShippingService.getAvailableCities().first;
      }
    } else {
      // Limpiar campos del formulario si no hay solicitud anterior
      _tiendaSolicitudController.clear();
      _ubicacionSolicitudController.clear();
      _selectedCitySolicitud = null;
    }
    
    // Limpiar documento (siempre se debe subir uno nuevo)
    _documentoSolicitud = null;
    _documentoSolicitudFileName = null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Solicitud de Vendedor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completa los siguientes datos para solicitar el rol de vendedor',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Nombre de tienda
                    TextField(
                      controller: _tiendaSolicitudController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de tienda *',
                        hintText: 'Ingresa el nombre de tu tienda',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
                        ),
                        prefixIcon: const Icon(Icons.store, color: Color(0xFF115213)),
                      ),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 16),
                    
                    // Ubicación - Usar dropdown con ciudades disponibles
                    DropdownButtonFormField<String>(
                      value: _selectedCitySolicitud,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Ciudad *',
                        hintText: 'Selecciona tu ciudad',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
                        ),
                        prefixIcon: const Icon(Icons.location_city, color: Color(0xFF115213)),
                      ),
                      dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                      items: ShippingService.getAvailableCities().map((ciudad) {
                        return DropdownMenuItem<String>(
                          value: ciudad,
                          child: Text(
                            ciudad,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedCitySolicitud = value;
                          if (value != null) {
                            _ubicacionSolicitudController.text = value;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Documento
                    GestureDetector(
                      onTap: () => _pickDocumentForRequest(setDialogState),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description, color: Color(0xFF115213)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _documentoSolicitudFileName ?? 'Documento de identificación *',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _documentoSolicitudFileName != null
                                          ? (isDark ? Colors.white : Colors.black)
                                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ),
                                  if (_documentoSolicitudFileName == null)
                                    Text(
                                      'JPG, PNG o PDF (máx. 5MB)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.upload_file,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF115213),
                              side: const BorderSide(color: Color(0xFF115213)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _submitVendorRequest(context, setDialogState, user.id, user.nombre, user.email),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF115213),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Enviar Solicitud'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDocumentForRequest(StateSetter setDialogState) async {
    try {
      final String? fileType = await showDialog<String>(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Seleccionar documento',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image, color: Color(0xFF115213)),
                  title: Text(
                    'Imagen (JPG, PNG)',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  onTap: () => Navigator.pop(context, 'image'),
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF115213)),
                  title: Text(
                    'PDF',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                  onTap: () => Navigator.pop(context, 'pdf'),
                ),
              ],
            ),
          );
        },
      );

      if (fileType == null) return;

      if (fileType == 'image') {
        final ImageSource? source = await showDialog<ImageSource>(
          context: context,
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                'Seleccionar imagen',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Color(0xFF115213)),
                    title: Text(
                      'Tomar foto',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Color(0xFF115213)),
                    title: Text(
                      'Elegir de galería',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            );
          },
        );

        if (source == null) return;

        final XFile? image = await _imagePicker.pickImage(
          source: source,
          imageQuality: 85,
        );

        if (image != null) {
          final file = File(image.path);
          final fileSize = await file.length();
          const maxSize = 5 * 1024 * 1024; // 5MB

          if (fileSize > maxSize) {
            _showErrorSnackBar('El archivo es demasiado grande. Máximo 5MB permitido.');
            return;
          }

          setDialogState(() {
            _documentoSolicitud = file;
            _documentoSolicitudFileName = image.name;
          });
        }
      } else if (fileType == 'pdf') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.single.path != null) {
          final file = File(result.files.single.path!);
          final fileSize = await file.length();
          const maxSize = 5 * 1024 * 1024; // 5MB

          if (fileSize > maxSize) {
            _showErrorSnackBar('El archivo es demasiado grande. Máximo 5MB permitido.');
            return;
          }

          setDialogState(() {
            _documentoSolicitud = file;
            _documentoSolicitudFileName = result.files.single.name;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar documento: $e');
    }
  }

  /// Mostrar diálogo cuando la solicitud fue rechazada
  Future<void> _showRejectedRequestDialog(SolicitudVendedorModel solicitud) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motivo = solicitud.motivoRechazo;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Solicitud Rechazada',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              motivo != null && motivo.isNotEmpty
                  ? 'Motivo del rechazo:\n\n$motivo'
                  : 'Tu solicitud de vendedor fue rechazada. Por favor, revisa la información y vuelve a intentar.',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '¿Deseas enviar una nueva solicitud?',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Mostrar formulario para reenviar solicitud con datos anteriores
              _showVendorRequestForm(solicitudAnterior: solicitud);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF115213),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reenviar Solicitud'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitVendorRequest(BuildContext dialogContext, StateSetter setDialogState, String userId, String nombre, String email) async {
    // Validar si el usuario ya tiene ambos roles
    try {
      final userData = await FirebaseService.getCurrentUserData();
      final rolesFromData = userData?['roles'] as List<dynamic>?;
      final rolesList = rolesFromData?.map((r) => r.toString().toLowerCase()).toList() ?? [];
      final hasSellerRole = rolesList.any((r) => r.contains('vend'));
      final hasBuyerRole = rolesList.any((r) => r.contains('compr') || r.contains('buyer'));
      
      if (hasSellerRole && hasBuyerRole) {
        Navigator.pop(dialogContext); // Cerrar el diálogo
        _showErrorSnackBar('Ya tienes ambos roles activos. No es necesario enviar una nueva solicitud.');
        return;
      }
    } catch (e) {
      print('⚠️ Error validando roles antes de enviar solicitud: $e');
    }

    // Validaciones
    if (_tiendaSolicitudController.text.trim().isEmpty) {
      _showErrorSnackBar('Por favor, ingresa el nombre de tu tienda');
      return;
    }

    if (_selectedCitySolicitud == null || _selectedCitySolicitud!.isEmpty) {
      _showErrorSnackBar('Por favor, selecciona una ciudad');
      return;
    }

    if (_documentoSolicitud == null) {
      _showErrorSnackBar('Por favor, sube un documento de verificación');
      return;
    }

    setDialogState(() {
      _isLoading = true;
    });

    try {
      final result = await VendorRequestService.createVendorRequestForExistingUser(
        userId: userId,
        nombre: nombre,
        email: email,
        nombreTienda: _tiendaSolicitudController.text.trim(),
        ubicacion: _selectedCitySolicitud!,
        ubicacionFormatted: _selectedCitySolicitud!,
        ubicacionLat: null, // No necesitamos coordenadas para ciudades predefinidas
        ubicacionLng: null,
        documentoFile: _documentoSolicitud!,
      );

      if (mounted) {
        Navigator.pop(dialogContext); // Cerrar diálogo
        
        if (result['success']) {
          _showSuccessSnackBar(result['message'] ?? 'Solicitud enviada exitosamente');
        } else {
          _showErrorSnackBar(result['message'] ?? 'Error al enviar la solicitud');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(dialogContext);
        _showErrorSnackBar('Error inesperado: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tiendaController.dispose();
    _ubicacionController.dispose();
    _tiendaSolicitudController.dispose();
    _ubicacionSolicitudController.dispose();
    super.dispose();
  }
}