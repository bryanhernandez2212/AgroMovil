import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:agromarket/models/product_model.dart';
import 'package:agromarket/services/product_service.dart';
import 'package:agromarket/widgets/role_guard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agromarket/estructure/product_estructure.dart';

class RegisterProductViewContent extends StatefulWidget {
  final ProductModel? productToEdit;
  
  const RegisterProductViewContent({super.key, this.productToEdit});

  @override
  State<RegisterProductViewContent> createState() => _RegisterProductViewContentState();
}

class _RegisterProductViewContentState extends State<RegisterProductViewContent> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Variables para manejo de imagen y estado
  File? _selectedImage;
  String? _selectedCategory;
  String? _selectedUnit;
  bool _isLoadingAllow = false;
  List<String> _categories = [];
  List<String> _units = [];
  String? _existingImageUrl; // URL de imagen existente si se está editando

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _loadInitialData();
    
    // Si hay un producto para editar, precargar los datos
    if (widget.productToEdit != null) {
      _loadProductData(widget.productToEdit!);
    }
  }

  // Cargar datos del producto para editar
  void _loadProductData(ProductModel product) {
    _nameController.text = product.nombre;
    _priceController.text = product.precio.toString();
    _stockController.text = product.stock.toString();
    _descriptionController.text = product.descripcion;
    _selectedCategory = product.categoria;
    _selectedUnit = product.unidad;
    _existingImageUrl = product.imagenUrl;
    
    setState(() {});
  }

  // Cargar datos iniciales
  Future<void> _loadInitialData() async {
    try {
      _categories = await ProductService.getCategories();
      _units = ProductService.getUnits();
      
      // Establecer valores por defecto solo si no hay producto para editar
      if (widget.productToEdit == null) {
        if (_categories.isNotEmpty) _selectedCategory = _categories.first;
        if (_units.isNotEmpty) _selectedUnit = _units.first;
      }
      
      setState(() {}); // Actualizar la UI con los datos cargados
    } catch (e) {
      print('Error cargando datos iniciales: $e');
    }
  }


  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  // Método para seleccionar imagen
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen seleccionada exitosamente'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error seleccionando imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error seleccionando imagen: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  // Método para guardar producto
  Future<void> _saveProduct() async {
    print('=== INICIANDO PROCESO DE GUARDADO ===');
    
    // Validar campos requeridos
    if (_nameController.text.trim().isEmpty) {
      _showErrorDialog('Por favor ingresa el nombre del producto');
      return;
    }
    
    if (_priceController.text.trim().isEmpty) {
      _showErrorDialog('Por favor ingresa el precio del producto');
      return;
    }
    
    if (_stockController.text.trim().isEmpty) {
      _showErrorDialog('Por favor ingresa el stock del producto');
      return;
    }
    
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorDialog('Por favor ingresa la descripción del producto');
      return;
    }
    
    if (_selectedCategory == null) {
      _showErrorDialog('Por favor selecciona una categoría');
      return;
    }
    
    if (_selectedUnit == null) {
      _showErrorDialog('Por favor selecciona una unidad');
      return;
    }

    setState(() {
      _isLoadingAllow = true;
    });
    print('Estado de carga activado');

    try {
      // Obtener usuario actual
      final User? user = FirebaseAuth.instance.currentUser;
      print('Usuario obtenido: ${user?.uid}');
      print('Email del usuario: ${user?.email}');
      
      if (user == null) {
        _showErrorDialog('Usuario no autenticado. Por favor, inicia sesión nuevamente.');
        return;
      }

      String imageUrl = '';
      
      // Si se está editando y no se seleccionó nueva imagen, usar la existente
      if (widget.productToEdit != null && _selectedImage == null) {
        imageUrl = _existingImageUrl ?? '';
        print('Usando imagen existente: $imageUrl');
      } else if (_selectedImage != null) {
        // Subir nueva imagen si se seleccionó una
        print('Subiendo imagen...');
        final imageResult = await ProductService.uploadProductImage(
          _selectedImage!, 
          _nameController.text.trim()
        );
        
        if (imageResult['success']) {
          imageUrl = imageResult['imageUrl'];
          print('Imagen subida exitosamente: $imageUrl');
        } else {
          _showErrorDialog('Error subiendo imagen: ${imageResult['message']}');
          return;
        }
      } else {
        print('No se seleccionó imagen, usando URL placeholder');
      }

      // Crear el modelo del producto
      print('Creando modelo del producto...');
      final product = ProductModel.fromForm(
        nombre: _nameController.text.trim(),
        categoria: _selectedCategory!,
        descripcion: _descriptionController.text.trim(),
        precio: double.parse(_priceController.text.trim()),
        stock: int.parse(_stockController.text.trim()),
        unidad: _selectedUnit!,
        imagenUrl: imageUrl,
        vendedorEmail: user.email ?? '',
        vendedorId: user.uid,
        vendedorNombre: user.displayName ?? 'Usuario',
        id: widget.productToEdit?.id ?? '', // Preservar ID si se está editando
      );

      print('Producto creado: ${product.nombre}');
      print('Datos del producto: ${product.toJson()}');

      // Guardar o actualizar producto
      Map<String, dynamic> result;
      if (widget.productToEdit != null) {
        // Actualizar producto existente
        print('Actualizando producto con ID: ${widget.productToEdit!.id}');
        result = await ProductService.updateProduct(widget.productToEdit!.id, product);
      } else {
        // Guardar nuevo producto
        print('Llamando a ProductService.saveProduct...');
        result = await ProductService.saveProduct(product);
      }
      
      print('Resultado: $result');
      
      if (result['success']) {
        print(widget.productToEdit != null ? 'Producto actualizado exitosamente' : 'Producto guardado exitosamente');
        _showSuccessDialog();
      } else {
        print('Error: ${result['message']}');
        _showErrorDialog('Error ${widget.productToEdit != null ? 'actualizando' : 'guardando'} producto: ${result['message']}');
      }
    } catch (e) {
      print('Error en el proceso de guardado: $e');
      _showErrorDialog('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingAllow = false;
      });
      print('Estado de carga desactivado');
    }
  }

  // Mostrar diálogo de error
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true, // Permite cerrar tocando fuera
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Mostrar diálogo de éxito
  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Evita que se cierre tocando fuera
      builder: (context) => AlertDialog(
        title: const Text('Éxito'),
        content: Text(widget.productToEdit != null 
            ? 'Producto actualizado exitosamente' 
            : 'Producto guardado exitosamente'),
        actions: [
          TextButton(
            onPressed: () {
              // Cerrar el diálogo
              Navigator.of(context).pop();
              
              // Si se está editando, regresar con resultado true para recargar la lista
              if (widget.productToEdit != null) {
                Navigator.of(context).pop(true);
              } else {
                // Si es nuevo producto, navegar a la vista de productos del vendedor
                // El índice 2 corresponde a "Mis productos" en la estructura
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const ProductEstructureView(currentIndex: 2),
                  ),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return VendorGuard(
      child: Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: Container(
                        width: constraints.maxWidth * 0.95,
                        height: constraints.maxHeight * 10,
                        margin: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * 0.025,
                          vertical: constraints.maxHeight * 0.05,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 25,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth * 0.05,
                                vertical: constraints.maxHeight * 0.02,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(25),
                                  topRight: Radius.circular(25),
                                ),
                              ),
                              child: Column(
                                children: [
                                  SizedBox(height: constraints.maxHeight * 0.01),
                                  const Text(
                                    "Completa la información de tu producto",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2F4157),
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Contenido con scroll
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.symmetric(
                                  horizontal: constraints.maxWidth * 0.05,
                                  vertical: constraints.maxHeight * 0.01,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: GestureDetector(
                                        onTap: _pickImage,
                                        child: Container(
                                          height: constraints.maxHeight * 0.12,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(0xFF577C8E).withOpacity(0.3),
                                              width: 2,
                                              style: BorderStyle.solid,
                                            ),
                                          ),
                                          child: _selectedImage != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(18),
                                                  child: Image.file(
                                                    _selectedImage!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                                                  ? ClipRRect(
                                                      borderRadius: BorderRadius.circular(18),
                                                      child: Image.network(
                                                        _existingImageUrl!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Container(
                                                                width: 50,
                                                                height: 50,
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                                                                  shape: BoxShape.circle,
                                                                ),
                                                                child: const Icon(
                                                                  Icons.add_a_photo,
                                                                  color: Color(0xFF226602),
                                                                  size: 25,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 8),
                                                              const Text(
                                                                "Toca para cambiar imagen",
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Color(0xFF2F4157),
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  : Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Container(
                                                          width: 50,
                                                          height: 50,
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(
                                                            Icons.add_a_photo,
                                                            color: Color(0xFF226602),
                                                            size: 25,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        const Text(
                                                          "Toca para subir imagen",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Color(0xFF2F4157),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                        ),
                                      ),
                                    ),
                                    
                                    SizedBox(height: constraints.maxHeight * 0.02),
                                    
                                    // Campos del formulario
                                    _buildFormField(
                                      label: "Nombre del producto",
                                      controller: _nameController,
                                      icon: Icons.inventory_2,
                                      constraints: constraints,
                                    ),
                                    
                                    SizedBox(height: constraints.maxHeight * 0.015),
                                    
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildFormField(
                                            label: "Precio",
                                            controller: _priceController,
                                            icon: Icons.attach_money,
                                            keyboardType: TextInputType.number,
                                            constraints: constraints,
                                          ),
                                        ),
                                        SizedBox(width: constraints.maxWidth * 0.03),
                                        Expanded(
                                          child: _buildFormField(
                                            label: "Stock",
                                            controller: _stockController,
                                            icon: Icons.inventory,
                                            keyboardType: TextInputType.number,
                                            constraints: constraints,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    SizedBox(height: constraints.maxHeight * 0.015),
                                    
                                    _buildDropdownField(
                                      label: "Categoría",
                                      value: _selectedCategory,
                                      items: _categories,
                                      icon: Icons.category,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedCategory = value;
                                        });
                                      },
                                      constraints: constraints,
                                    ),
                                    
                                    SizedBox(height: constraints.maxHeight * 0.015),
                                    
                                    _buildFormField(
                                      label: "Descripción",
                                      controller: _descriptionController,
                                      icon: Icons.description,
                                      maxLines: 3,
                                      constraints: constraints,
                                    ),
                                    
                                    SizedBox(height: constraints.maxHeight * 0.015),
                                    
                                    _buildDropdownField(
                                      label: "Unidad",
                                      value: _selectedUnit,
                                      items: _units,
                                      icon: Icons.straighten,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedUnit = value;
                                        });
                                      },
                                      constraints: constraints,
                                    ),
                                    
                                    SizedBox(height: constraints.maxHeight * 0.03),
                                    
                                    // Botón de guardar
                                    SizedBox(
                                      width: double.infinity,
                                      height: 45,
                                      child: ElevatedButton(
                                        onPressed: _isLoadingAllow ? null : _saveProduct,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromARGB(255, 41, 78, 44),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                          elevation: 5,
                                        ),
                                        child: _isLoadingAllow
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Text(
                                                widget.productToEdit != null ? "Actualizar Producto" : "Guardar Producto",
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                    
                                    SizedBox(height: constraints.maxHeight * 0.02),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }

  // Método para crear campos de formulario con estilo consistente
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    required BoxConstraints constraints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: constraints.maxWidth * 0.04,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2F4157),
          ),
        ),
        SizedBox(height: constraints.maxHeight * 0.01),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFF577C8E).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF226602),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * 0.04,
                vertical: constraints.maxHeight * 0.015,
              ),
              hintText: "$label",
              hintStyle: TextStyle(
                color: const Color(0xFF2F4157).withOpacity(0.6),
                fontSize: constraints.maxWidth * 0.035,
              ),
            ),
            style: TextStyle(
              fontSize: constraints.maxWidth * 0.035,
              color: const Color(0xFF2F4157),
            ),
          ),
        ),
      ],
    );
  }

  // Método para crear dropdown fields con diseño simple
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    required BoxConstraints constraints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: constraints.maxWidth * 0.04,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2F4157),
          ),
        ),
        SizedBox(height: constraints.maxHeight * 0.01),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFF577C8E).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            dropdownColor: const Color.fromARGB(255, 255, 255, 255),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF226602),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * 0.04,
                vertical: constraints.maxHeight * 0.015,
              ),
              hintText: "Selecciona $label",
              hintStyle: TextStyle(
                color: const Color(0xFF2F4157).withOpacity(0.6),
                fontSize: constraints.maxWidth * 0.035,
              ),
            ),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: constraints.maxWidth * 0.035,
                    color: Colors.black.withOpacity(0.40),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            style: TextStyle(
              fontSize: constraints.maxWidth * 0.035,
              color: const Color(0xFF2F4157),
            ),
          ),
        ),
      ],
    );
  }
}

// Mantener la clase original para compatibilidad
class RegisterProductView extends StatelessWidget {
  final ProductModel? productToEdit;
  
  const RegisterProductView({super.key, this.productToEdit});

  @override
  Widget build(BuildContext context) {
    return RegisterProductViewContent(productToEdit: productToEdit);
  }
}