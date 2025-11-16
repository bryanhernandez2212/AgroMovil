import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:agromarket/models/product_model.dart';
import 'package:agromarket/services/product_service.dart';
import 'package:agromarket/widgets/role_guard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  // Variables para manejo de imágenes y estado
  List<File> _selectedImages = []; // Lista de imágenes seleccionadas (hasta 5)
  List<String> _existingImageUrls = []; // URLs de imágenes existentes si se está editando
  String? _selectedCategory;
  String? _selectedUnit;
  bool _isLoadingAllow = false;
  List<String> _categories = [];
  List<String> _units = [];
  final ScrollController _scrollController = ScrollController();

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
    // Cargar imágenes existentes (array o imagen única)
    _existingImageUrls = product.imagenes.isNotEmpty 
        ? List<String>.from(product.imagenes)
        : (product.imagenUrl.isNotEmpty ? [product.imagenUrl] : []);
    
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
    _scrollController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Método para seleccionar imágenes (hasta 5)
  Future<void> _pickImages() async {
    try {
      // Verificar límite de 5 imágenes
      if (_selectedImages.length + _existingImageUrls.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Máximo 5 imágenes permitidas'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        int remainingSlots = 5 - _selectedImages.length - _existingImageUrls.length;
        int imagesToAdd = images.length > remainingSlots ? remainingSlots : images.length;
        
        setState(() {
          for (int i = 0; i < imagesToAdd; i++) {
            _selectedImages.add(File(images[i].path));
          }
        });
        
        if (images.length > remainingSlots) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Solo se agregaron $remainingSlots imágenes (máximo 5 permitidas)'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${images.length} imagen(es) seleccionada(s) exitosamente'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error seleccionando imágenes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error seleccionando imágenes: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Método para eliminar imagen seleccionada
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Imagen eliminada'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Método para eliminar imagen existente (al editar)
  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Imagen eliminada'),
        duration: Duration(seconds: 1),
      ),
    );
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

    // Validar que haya al menos una imagen (nueva o existente)
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      _showErrorDialog('Por favor selecciona al menos una imagen del producto');
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

      String productId = widget.productToEdit?.id ?? '';
      List<String> allImageUrls = List<String>.from(_existingImageUrls); // URLs existentes
      
      // Si hay nuevas imágenes para subir
      if (_selectedImages.isNotEmpty) {
        // Si es producto nuevo, primero crear el documento para obtener el ID
        if (productId.isEmpty) {
          print('Creando documento temporal para obtener ID...');
          final tempProduct = ProductModel.fromForm(
            nombre: _nameController.text.trim(),
            categoria: _selectedCategory!,
            descripcion: _descriptionController.text.trim(),
            precio: double.parse(_priceController.text.trim()),
            stock: int.parse(_stockController.text.trim()),
            unidad: _selectedUnit!,
            imagenUrl: allImageUrls.isNotEmpty ? allImageUrls.first : '', // Usar existente si hay
            imagenes: allImageUrls, // Mantener existentes
            vendedorEmail: user.email ?? '',
            vendedorId: user.uid,
            vendedorNombre: user.displayName ?? 'Usuario',
          );
          
          // Crear documento temporal
          final docRef = await FirebaseFirestore.instance.collection('productos').add(tempProduct.toJson());
          productId = docRef.id;
          await docRef.update({'id': productId});
          print('Documento creado con ID: $productId');
        }
        
        // Subir nuevas imágenes
        print('Subiendo ${_selectedImages.length} imagen(es)...');
        final imagesResult = await ProductService.uploadProductImages(
          _selectedImages,
          _nameController.text.trim(),
          productId,
        );
        
        if (imagesResult['success']) {
          List<String> newImageUrls = List<String>.from(imagesResult['imageUrls']);
          allImageUrls.addAll(newImageUrls);
          print('Imágenes subidas exitosamente. Total URLs: ${allImageUrls.length}');
        } else {
          // Si falló la subida de imágenes nuevas y es producto nuevo, eliminar documento temporal
          if (widget.productToEdit == null && productId.isNotEmpty) {
            await FirebaseFirestore.instance.collection('productos').doc(productId).delete();
          }
          _showErrorDialog('Error subiendo imágenes: ${imagesResult['message']}');
          return;
        }
      }

      // Crear el modelo del producto con todas las URLs
      print('Creando modelo del producto...');
      final product = ProductModel.fromForm(
        nombre: _nameController.text.trim(),
        categoria: _selectedCategory!,
        descripcion: _descriptionController.text.trim(),
        precio: double.parse(_priceController.text.trim()),
        stock: int.parse(_stockController.text.trim()),
        unidad: _selectedUnit!,
        imagenUrl: allImageUrls.isNotEmpty ? allImageUrls.first : '', // Primera como principal
        imagenes: allImageUrls, // Array completo
        vendedorEmail: user.email ?? '',
        vendedorId: user.uid,
        vendedorNombre: user.displayName ?? 'Usuario',
        id: productId,
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
        // Actualizar el documento con las imágenes
        print('Actualizando documento con URLs de imágenes...');
        await FirebaseFirestore.instance.collection('productos').doc(productId).update(product.toJson());
        result = {'success': true, 'message': 'Producto guardado exitosamente', 'productId': productId};
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
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Título "Editar producto" cuando se está editando
                      if (widget.productToEdit != null)
                        Container(
                          color: Colors.white,
                          width: double.infinity,
                          padding: const EdgeInsets.only(
                            top: 12,
                            bottom: 4,
                            left: 20,
                            right: 20,
                          ),
                          child: const Text(
                            'Editar producto',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF115213),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: constraints.maxWidth * 0.025,
                            vertical: constraints.maxHeight * 0.02,
                          ),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth * 0.05,
                              vertical: constraints.maxHeight * 0.015,
                            ),
                            child: AnimatedPadding(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Texto "Completa la información" ahora dentro del scroll
                                  Padding(
                                    padding: EdgeInsets.only(
                                        bottom: constraints
                                                .maxHeight *
                                            0.01),
                                  ),

                                  // Título de la sección de imágenes
                                  Text(
                                    "Imágenes del producto (máximo 5)",
                                    style: TextStyle(
                                      fontSize:
                                          constraints.maxWidth *
                                              0.04,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          const Color(0xFF2F4157),
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          constraints.maxHeight *
                                              0.01),

                                  // Galería de imágenes
                                  Container(
                                    height:
                                        constraints.maxHeight *
                                            0.19,
                                    child: ListView(
                                      scrollDirection:
                                          Axis.horizontal,
                                      children: [
                                        // Mostrar imágenes existentes (al editar)
                                        ..._existingImageUrls
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          int index = entry.key;
                                          String url =
                                              entry.value;
                                          return _buildImageContainer(
                                            imageUrl: url,
                                            isNetwork: true,
                                            onRemove: () =>
                                                _removeExistingImage(
                                                    index),
                                            constraints:
                                                constraints,
                                          );
                                        }),

                                        // Mostrar imágenes nuevas seleccionadas
                                        ..._selectedImages
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          int index = entry.key;
                                          File imageFile =
                                              entry.value;
                                          return _buildImageContainer(
                                            imageFile: imageFile,
                                            isNetwork: false,
                                            onRemove: () =>
                                                _removeImage(
                                                    index),
                                            constraints:
                                                constraints,
                                          );
                                        }),

                                        // Botón para agregar más imágenes
                                        if (_selectedImages
                                                    .length +
                                                _existingImageUrls
                                                    .length <
                                            5)
                                          _buildAddImageButton(
                                            onTap: _pickImages,
                                            constraints:
                                                constraints,
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Indicador de cantidad de imágenes
                                  if (_selectedImages.length +
                                          _existingImageUrls
                                              .length >
                                          0)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: constraints
                                                  .maxHeight *
                                              0.005),
                                      child: Text(
                                        "${_selectedImages.length + _existingImageUrls.length}/5 imágenes seleccionadas",
                                        style: TextStyle(
                                          fontSize: constraints
                                                  .maxWidth *
                                              0.03,
                                          color: const Color(
                                                  0xFF2F4157)
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ),

                                  SizedBox(
                                      height:
                                          constraints.maxHeight *
                                              0.03),

                                  // Campos del formulario
                                  _buildFormField(
                                    label: "Nombre del producto",
                                    controller: _nameController,
                                    icon: Icons.inventory_2,
                                    constraints: constraints,
                                  ),

                                  SizedBox(
                                      height:
                                          constraints.maxHeight *
                                              0.015),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildFormField(
                                          label: "Precio",
                                          controller:
                                              _priceController,
                                          icon:
                                              Icons.attach_money,
                                          keyboardType:
                                              TextInputType
                                                  .number,
                                          constraints:
                                              constraints,
                                        ),
                                      ),
                                      SizedBox(
                                          width: constraints
                                                  .maxWidth *
                                              0.03),
                                      Expanded(
                                        child: _buildFormField(
                                          label: "Stock",
                                          controller:
                                              _stockController,
                                          icon: Icons.inventory,
                                          keyboardType:
                                              TextInputType
                                                  .number,
                                          constraints:
                                              constraints,
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(
                                      height:
                                          constraints.maxHeight *
                                              0.015),

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

                                  SizedBox(
                                      height:
                                          constraints.maxHeight *
                                              0.015),

                                  _buildFormField(
                                    label: "Descripción",
                                    controller:
                                        _descriptionController,
                                    icon: Icons.description,
                                    maxLines: 3,
                                    constraints: constraints,
                                  ),

                                  SizedBox(
                                      height:
                                          constraints.maxHeight *
                                              0.015),

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

                                  SizedBox(
                                      height:
                                          constraints.maxHeight *
                                              0.03),

                                  // Botones de acción
                                  if (widget.productToEdit !=
                                      null)
                                    // Botones al editar: Cancelar y Actualizar
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 45,
                                            child: OutlinedButton(
                                              onPressed: _isLoadingAllow
                                                  ? null
                                                  : () => Navigator.of(
                                                          context)
                                                      .pop(),
                                              style:
                                                  OutlinedButton
                                                      .styleFrom(
                                                foregroundColor:
                                                    const Color(
                                                        0xFF2F4157),
                                                side:
                                                    const BorderSide(
                                                  color: Color(
                                                      0xFF577C8E),
                                                  width: 2,
                                                ),
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              25),
                                                ),
                                              ),
                                              child: const Text(
                                                "Cancelar",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                            width: constraints
                                                    .maxWidth *
                                                0.03),
                                        Expanded(
                                          child: SizedBox(
                                            height: 45,
                                            child: ElevatedButton(
                                              onPressed:
                                                  _isLoadingAllow
                                                      ? null
                                                      : _saveProduct,
                                              style:
                                                  ElevatedButton
                                                      .styleFrom(
                                                backgroundColor:
                                                    const Color
                                                        .fromARGB(
                                                        255,
                                                        41,
                                                        78,
                                                        44),
                                                foregroundColor:
                                                    Colors.white,
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              25),
                                                ),
                                                elevation: 5,
                                              ),
                                              child: _isLoadingAllow
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth:
                                                            2,
                                                        valueColor: AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors
                                                                .white),
                                                      ),
                                                    )
                                                  : const Text(
                                                      "Actualizar",
                                                      style:
                                                          TextStyle(
                                                        fontSize:
                                                            16,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    // Botón al agregar nuevo producto
                                    SizedBox(
                                      width: double.infinity,
                                      height: 45,
                                      child: ElevatedButton(
                                        onPressed: _isLoadingAllow
                                            ? null
                                            : _saveProduct,
                                        style: ElevatedButton
                                            .styleFrom(
                                          backgroundColor:
                                              const Color
                                                  .fromARGB(255,
                                                  41, 78, 44),
                                          foregroundColor:
                                              Colors.white,
                                          shape:
                                              RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(25),
                                              ),
                                          elevation: 5,
                                        ),
                                        child: _isLoadingAllow
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Colors
                                                              .white),
                                                ),
                                              )
                                            : const Text(
                                                "Guardar Producto",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                ),
                                              ),
                                      ),
                                    ),

                                  SizedBox(
                                      height:
                                          constraints.maxHeight *
                                              0.02),
                                ],
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
          ),
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

  // Método para construir contenedor de imagen en la galería
  Widget _buildImageContainer({
    File? imageFile,
    String? imageUrl,
    required bool isNetwork,
    required VoidCallback onRemove,
    required BoxConstraints constraints,
  }) {
    return Container(
      width: constraints.maxWidth * 0.25,
      height: constraints.maxHeight * 0.15,
      margin: EdgeInsets.only(right: constraints.maxWidth * 0.02),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: isNetwork && imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(
                          Icons.broken_image,
                          color: Color(0xFF577C8E),
                          size: 30,
                        ),
                      );
                    },
                  )
                : imageFile != null
                    ? Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(
                          Icons.image,
                          color: Color(0xFF577C8E),
                          size: 30,
                        ),
                      ),
          ),
          // Botón para eliminar
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir botón de agregar imagen
  Widget _buildAddImageButton({
    required VoidCallback onTap,
    required BoxConstraints constraints,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: constraints.maxWidth * 0.25,
        height: constraints.maxHeight * 0.15,
        margin: EdgeInsets.only(right: constraints.maxWidth * 0.02),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFF577C8E).withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo,
                color: Color(0xFF226602),
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Agregar",
              style: TextStyle(
                fontSize: constraints.maxWidth * 0.03,
                color: const Color(0xFF2F4157),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
