import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/services/places_service.dart';
import 'package:agromarket/services/vendor_request_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _empresaController = TextEditingController();
  final _ubicacionController = TextEditingController();
  bool _obscureText = true;
  bool _obscureRepeatText = true;
  String _selectedRole = 'comprador';
  final List<String> _availableRoles = ['comprador', 'vendedor'];
  bool _privacyAccepted = false;
  List<PlacePrediction> _placePredictions = [];
  bool _showPredictions = false;
  PlaceDetails? _selectedPlace;
  File? _selectedDocument;
  String? _documentFileName;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _empresaController.dispose();
    _ubicacionController.dispose();
    super.dispose();
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

  Future<void> _pickDocument() async {
    try {
      // Mostrar diálogo para elegir tipo de archivo
      final String? fileType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seleccionar documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFF115213)),
                title: const Text('Imagen (JPG, PNG)'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF115213)),
                title: const Text('PDF'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
            ],
          ),
        ),
      );

      if (fileType == null) return;

      if (fileType == 'image') {
        // Usar image_picker para imágenes
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
          imageQuality: 85,
        );

        if (image != null) {
          // Validar tamaño (máx. 5MB)
          final file = File(image.path);
          final fileSize = await file.length();
          const maxSize = 5 * 1024 * 1024; // 5MB

          if (fileSize > maxSize) {
            if (mounted) {
              _showErrorSnackBar('El archivo es demasiado grande. Máximo 5MB permitido.');
            }
            return;
          }

          setState(() {
            _selectedDocument = file;
            _documentFileName = image.name;
          });
        }
      } else if (fileType == 'pdf') {
        // Usar file_picker para PDFs
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.single.path != null) {
          final file = File(result.files.single.path!);
          
          // Validar tamaño (máx. 5MB)
          final fileSize = await file.length();
          const maxSize = 5 * 1024 * 1024; // 5MB

          if (fileSize > maxSize) {
            if (mounted) {
              _showErrorSnackBar('El archivo es demasiado grande. Máximo 5MB permitido.');
            }
            return;
          }

          setState(() {
            _selectedDocument = file;
            _documentFileName = result.files.single.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al seleccionar documento: $e');
      }
    }
  }

  Future<void> _register() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    
    // Validaciones básicas
    if (_nombreController.text.isEmpty) {
      _showErrorSnackBar('Por favor, ingresa tu nombre completo');
      return;
    }
    
    if (_emailController.text.isEmpty) {
      _showErrorSnackBar('Por favor, ingresa tu correo electrónico');
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar('Por favor, ingresa una contraseña segura');
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Las contraseñas no coinciden. Verifica e inténtalo de nuevo');
      return;
    }
    
    if (_passwordController.text.length < 6) {
      _showErrorSnackBar('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    // Si es vendedor, validar campos adicionales y documento
    if (_selectedRole == 'vendedor') {
      if (_empresaController.text.isEmpty) {
        _showErrorSnackBar('Por favor, ingresa el nombre de tu tienda');
        return;
      }
      
      if (_selectedPlace == null) {
        _showErrorSnackBar('Por favor, selecciona una ubicación');
        return;
      }
      
      if (_selectedDocument == null) {
        _showErrorSnackBar('Por favor, sube un documento de verificación');
        return;
      }
    }

    // Si es vendedor, usar el servicio de solicitudes
    if (_selectedRole == 'vendedor') {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final result = await VendorRequestService.createVendorRequest(
          nombre: _nombreController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nombreTienda: _empresaController.text.trim(),
          ubicacion: _selectedPlace!.formattedAddress,
          ubicacionFormatted: _selectedPlace!.formattedAddress,
          ubicacionLat: _selectedPlace!.lat,
          ubicacionLng: _selectedPlace!.lng,
          documentoFile: _selectedDocument!,
        );

        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          
          if (result['success']) {
            _showSuccessSnackBar(
              result['message'] ?? 'Solicitud enviada exitosamente. Te notificaremos cuando sea revisada.'
            );
            // Limpiar formulario
            _nombreController.clear();
            _emailController.clear();
            _passwordController.clear();
            _confirmPasswordController.clear();
            _empresaController.clear();
            _ubicacionController.clear();
            _selectedPlace = null;
            _selectedDocument = null;
            _documentFileName = null;
            setState(() {});
          } else {
            _showErrorSnackBar(result['message'] ?? 'Error al enviar la solicitud. Inténtalo de nuevo');
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          _showErrorSnackBar('Error inesperado: ${e.toString()}');
        }
      }
      return;
    }

    // Si es comprador, usar el flujo normal de registro
    final success = await authController.register(
      _nombreController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _selectedRole,
    );

    if (success && mounted) {
      _showSuccessSnackBar('¡Cuenta creada exitosamente! Ya puedes iniciar sesión');
    } else if (mounted) {
      _showErrorSnackBar(authController.errorMessage ?? 'Error al crear la cuenta. Inténtalo de nuevo');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF115213),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Iniciar Sesión',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showPrivacyNotice() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header simple
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Aviso de Privacidad',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content simple
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'La aplicación AgroMarket, desarrollada por la Empresa, con domicilio en Ocosingo, Chiapas, es responsable del uso y protección de los datos personales de sus usuarios.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSimpleSection(
                          'Datos que recopilamos',
                          [
                            'AgroMarket recaba los siguientes datos personales, según el tipo de usuario:',
                            '',
                            '• Compradores: nombre completo, correo electrónico, contraseña, datos bancarios y ubicación.',
                            '',
                            '• Vendedores: nombre completo, correo electrónico, contraseña, ubicación, datos bancarios y nombre del negocio.',
                            '',
                            'Estos datos son necesarios para garantizar el correcto funcionamiento de la plataforma y ofrecer los servicios disponibles dentro de la aplicación.',
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSimpleSection(
                          'Finalidad del tratamiento',
                          [
                            'Los datos personales que recopilamos se utilizarán para:',
                            '',
                            '• Crear y administrar su cuenta de usuario (comprador o vendedor).',
                            '• Facilitar las transacciones de compra y venta dentro de la plataforma.',
                            '• Verificar la identidad de los usuarios y garantizar la seguridad de las operaciones.',
                            '• Enviar notificaciones y actualizaciones relacionadas con sus actividades.',
                            '• Mejorar la calidad y confiabilidad de los servicios ofrecidos.',
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSimpleSection(
                          'Transferencia de datos personales',
                          [
                            'Sus datos personales podrán ser compartidos con proveedores tecnológicos que brindan servicios de alojamiento, mantenimiento, procesamiento de pagos y soporte técnico. Dichas transferencias se realizarán bajo estrictas medidas de confidencialidad y seguridad.',
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSimpleSection(
                          'Derechos ARCO',
                          [
                            'Usted tiene derecho a acceder, rectificar, cancelar u oponerse al tratamiento de sus datos personales (Derechos ARCO). Para ejercer estos derechos, puede enviar una solicitud al correo electrónico:',
                            '',
                            'agromarket559@gmail.com',
                          ],
                          email: 'agromarket559@gmail.com',
                        ),
                        const SizedBox(height: 20),
                        _buildSimpleSection(
                          'Cambios al aviso de privacidad',
                          [
                            'AgroMarket se reserva el derecho de modificar o actualizar este aviso de privacidad en cualquier momento. Las actualizaciones se publicarán dentro de la aplicación y en el sitio web.',
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer simple
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _privacyAccepted = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Aceptar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimpleSection(String title, List<String> content, {String? email}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 12),
        ...content.map((text) {
          if (text.isEmpty) {
            return const SizedBox(height: 8);
          }
          if (text == email) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () {
                  // Aquí podrías agregar funcionalidad para abrir el cliente de email
                },
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Fondo de hojas solo en la parte superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.50,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/fondo.JPG'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Curva blanca decorativa
          Positioned(
            top: MediaQuery.of(context).size.height * 0.60,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 100),
              painter: SmoothWavePainter(),
            ),
          ),

          // Botón de regreso
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDF2DD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color.fromARGB(255, 0, 0, 0),
                  size: 20,
                ),
              ),
            ),
          ),

          // Área blanca con contenido
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            top: MediaQuery.of(context).viewInsets.bottom > 0 
                ? 50  // Cuando hay teclado, subir mucho más arriba
                : MediaQuery.of(context).size.height * 0.30, // Posición normal
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1B5E20),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Crear cuenta',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B5E20),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 35,
                          height: 25,
                          child: const Icon(
                            Icons.eco,
                            color: Color(0xFF2E7D32),
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Regístrate para comenzar',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Campo de nombre
                    _buildInputField(
                      controller: _nombreController,
                      hintText: 'Nombre completo',
                      icon: Icons.person,
                      keyboardType: TextInputType.text,
                    ),

                    const SizedBox(height: 20),
                    
                    // Campo de email
                    _buildInputField(
                      controller: _emailController,
                      hintText: 'Correo electrónico',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Campo de contraseña
                    _buildPasswordField(
                      controller: _passwordController,
                      hintText: 'Contraseña',
                      icon: Icons.lock,
                      obscureText: _obscureText,
                      onToggle: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Campo de confirmar contraseña
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirmar contraseña',
                      icon: Icons.lock_outline,
                      obscureText: _obscureRepeatText,
                      onToggle: () {
                        setState(() {
                          _obscureRepeatText = !_obscureRepeatText;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Campo de selección de rol
                    _buildRoleSelector(),
                    
                    // Campos adicionales solo para vendedores
                    if (_selectedRole == 'vendedor') ...[
                      const SizedBox(height: 20),
                      _buildInputField(
                        controller: _empresaController,
                        hintText: 'Nombre de tienda',
                        icon: Icons.business,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 20),
                      _buildLocationField(),
                      const SizedBox(height: 20),
                      _buildDocumentField(),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Checkbox de aviso de privacidad
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _privacyAccepted,
                          onChanged: (bool? value) {
                            setState(() {
                              _privacyAccepted = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF666666),
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'He leído y acepto el ',
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        setState(() {
                                          _privacyAccepted = !_privacyAccepted;
                                        });
                                      },
                                  ),
                                  TextSpan(
                                    text: 'Aviso de Privacidad',
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = _showPrivacyNotice,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Botón de registro
                    Consumer<AuthController>(
                      builder: (context, authController, child) {
                        return GestureDetector(
                          onTap: authController.isLoading ? null : _register,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: authController.isLoading
                                  ? Colors.grey
                                  : const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: authController.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Registrarse',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Enlace de login
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            children: [
                              TextSpan(text: "¿Ya tienes cuenta? "),
                              TextSpan(
                                text: 'Iniciar sesión',
                                style: TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[600],
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        decoration: InputDecoration(
          hintText: 'Selecciona tu rol',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        items: _availableRoles.map((String role) {
          return DropdownMenuItem<String>(
            value: role,
            child: Text(
              _getRoleDisplayName(role),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedRole = newValue;
              // Limpiar campos específicos si cambia el rol a uno que no los requiere
              if (_selectedRole != 'vendedor') {
                _empresaController.clear();
                _ubicacionController.clear();
                _selectedPlace = null;
              }
            });
          }
        },
        dropdownColor: Colors.white,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _ubicacionController,
            decoration: InputDecoration(
              hintText: 'Ubicación (empieza a escribir...)',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.location_on, color: Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
        ),
        if (_showPredictions && _placePredictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
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
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'comprador':
        return 'Comprador';
      case 'vendedor':
        return 'Vendedor';
      default:
        return role;
    }
  }

  Widget _buildDocumentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documento de verificación',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDocument,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _selectedDocument != null 
                    ? const Color(0xFF2E7D32) 
                    : Colors.grey[300]!,
                width: _selectedDocument != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedDocument != null 
                      ? Icons.check_circle 
                      : Icons.upload_file,
                  color: _selectedDocument != null 
                      ? const Color(0xFF2E7D32) 
                      : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDocument != null 
                            ? _documentFileName ?? 'Documento seleccionado'
                            : 'Sube una identificación oficial, RFC o comprobante de domicilio',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedDocument != null 
                              ? const Color(0xFF2E7D32) 
                              : Colors.grey[600],
                          fontWeight: _selectedDocument != null 
                              ? FontWeight.w600 
                              : FontWeight.normal,
                        ),
                      ),
                      if (_selectedDocument != null)
                        const SizedBox(height: 4),
                      if (_selectedDocument != null)
                        const Text(
                          'JPG, PNG, PDF - máx. 5MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectedDocument != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.grey[600],
                    onPressed: () {
                      setState(() {
                        _selectedDocument = null;
                        _documentFileName = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class SmoothWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    
    // Crear una curva suave
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.4,
      size.width * 0.5, size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.8,
      size.width, size.height * 0.5,
    );
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}