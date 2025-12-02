import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:agromarket/services/shipping_service.dart';
import 'package:agromarket/services/product_service.dart';
import 'package:agromarket/views/buyer/payment_view.dart';

class ShippingAddressView extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final double cartTotal;

  const ShippingAddressView({
    super.key,
    required this.cartItems,
    required this.cartTotal,
  });

  @override
  State<ShippingAddressView> createState() => _ShippingAddressViewState();
}

class _ShippingAddressViewState extends State<ShippingAddressView> {
  final _formKey = GlobalKey<FormState>();
  final _telefonoController = TextEditingController();
  String? _selectedCiudad;
  double? _calculatedShippingCost;
  bool _isCalculatingShipping = false;
  Map<String, String> _vendorLocations = {}; // vendorId -> ciudad

  // Ciudades disponibles desde el servicio
  List<String> get _ciudades => ShippingService.getAvailableCities();

  @override
  void initState() {
    super.initState();
    _loadVendorLocations();
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    super.dispose();
  }

  /// Cargar ubicaciones de todos los vendedores en el carrito
  Future<void> _loadVendorLocations() async {
    final Set<String> vendorIds = widget.cartItems
        .map((item) => item.sellerId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final Map<String, String> locations = {};
    
    for (final vendorId in vendorIds) {
      try {
        final vendorInfo = await ProductService.getVendorInfo(vendorId);
        final ubicacion = vendorInfo['ubicacion'] ?? '';
        
        // Intentar extraer la ciudad de la ubicación
        final ciudad = ShippingService.extractCityFromAddress(ubicacion);
        if (ciudad != null) {
          locations[vendorId] = ciudad;
        } else {
          // Si no se puede extraer, usar la primera ciudad disponible como fallback
          locations[vendorId] = _ciudades.first;
        }
      } catch (e) {
        print('Error cargando ubicación del vendedor $vendorId: $e');
        locations[vendorId] = _ciudades.first;
      }
    }

    setState(() {
      _vendorLocations = locations;
    });
  }

  /// Calcular costo de envío cuando se selecciona una ciudad
  Future<void> _calculateShippingCost() async {
    if (_selectedCiudad == null || _vendorLocations.isEmpty) {
      setState(() {
        _calculatedShippingCost = null;
      });
      return;
    }

    setState(() {
      _isCalculatingShipping = true;
    });

    try {
      double totalShippingCost = 0.0;
      
      // Calcular costo de envío para cada vendedor único
      final Set<String> processedVendors = {};
      
      for (final item in widget.cartItems) {
        if (processedVendors.contains(item.sellerId)) continue;
        
        final vendorCity = _vendorLocations[item.sellerId];
        if (vendorCity == null) continue;
        
        // Calcular peso de productos de este vendedor
        double vendorWeight = 0.0;
        for (final vendorItem in widget.cartItems) {
          if (vendorItem.sellerId == item.sellerId) {
            final unidad = vendorItem.unit.toLowerCase();
            double weightKg = 0.0;
            
            if (unidad == 'kg' || unidad == 'kilogramo' || unidad == 'kilogramos') {
              weightKg = vendorItem.quantity.toDouble();
            } else if (unidad == 'g' || unidad == 'gramo' || unidad == 'gramos') {
              weightKg = vendorItem.quantity / 1000.0;
            } else if (unidad == 'ton' || unidad == 'tonelada' || unidad == 'toneladas') {
              weightKg = vendorItem.quantity * 1000.0;
            } else {
              weightKg = vendorItem.quantity * 0.5;
            }
            
            vendorWeight += weightKg;
          }
        }
        
        vendorWeight = vendorWeight < 1.0 ? 1.0 : vendorWeight;
        
        // Calcular costo de envío para este vendedor
        final shippingCost = ShippingService.calculateShippingCost(
          fromCity: vendorCity,
          toCity: _selectedCiudad!,
          weightKg: vendorWeight,
        );
        
        totalShippingCost += shippingCost;
        processedVendors.add(item.sellerId);
      }

      setState(() {
        _calculatedShippingCost = totalShippingCost;
        _isCalculatingShipping = false;
      });
    } catch (e) {
      print('Error calculando costo de envío: $e');
      setState(() {
        _calculatedShippingCost = null;
        _isCalculatingShipping = false;
      });
    }
  }

  String? _validateCiudad(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor selecciona una ciudad';
    }
    return null;
  }

  String? _validateTelefono(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa un número de teléfono';
    }
    // Eliminar espacios y caracteres no numéricos para validar
    final cleanPhone = value.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length != 10) {
      return 'El teléfono debe tener exactamente 10 dígitos';
    }
    return null;
  }

  void _continueToPayment() {
    if (_formKey.currentState!.validate()) {
      if (_calculatedShippingCost == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor espera a que se calcule el costo de envío'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            margin: EdgeInsets.all(16),
          ),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor inicia sesión para continuar'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            margin: EdgeInsets.all(16),
          ),
        );
        return;
      }

      // Limpiar el teléfono de caracteres no numéricos
      final cleanPhone = _telefonoController.text.trim().replaceAll(RegExp(r'[^\d]'), '');

      // Navegar a la vista de pago con el costo de envío calculado
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentView(
            cartItems: widget.cartItems,
            cartTotal: widget.cartTotal,
            ciudad: _selectedCiudad!,
            telefono: cleanPhone,
            direccionEntrega: null,
            shippingCost: _calculatedShippingCost!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF2E7D32),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Dirección de envío',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF2E7D32),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del pedido
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xFF1E1E1E) 
                        : const Color(0xFF115213).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark 
                          ? Colors.grey[700]! 
                          : const Color(0xFF115213).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        color: const Color(0xFF2E7D32),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.cartItems.length} producto${widget.cartItems.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey,
                              ),
                            ),
                            Text(
                              'Total: \$${widget.cartTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Título
                Text(
                  'Información de envío',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa los datos para la entrega de tu pedido',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                // Mensaje informativo sobre tiempo de entrega
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xFF2E7D32).withOpacity(0.2)
                        : const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark 
                          ? const Color(0xFF2E7D32).withOpacity(0.3)
                          : const Color(0xFF2E7D32).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: const Color(0xFF2E7D32),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tu pedido llegará en 1 a 2 días hábiles',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Campo de ciudad (Dropdown)
                DropdownButtonFormField<String>(
                  value: _selectedCiudad,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Ciudad *',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    prefixIcon: const Icon(Icons.location_city, color: Color(0xFF2E7D32)),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                  validator: _validateCiudad,
                  items: _ciudades.map((ciudad) {
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
                      _selectedCiudad = value;
                      _calculatedShippingCost = null;
                    });
                    if (value != null) {
                      _calculateShippingCost();
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Campo de teléfono
                TextFormField(
                  controller: _telefonoController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Teléfono *',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    hintText: 'Ej: 9671636739',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFF2E7D32)),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _validateTelefono,
                  maxLength: 10,
                  textInputAction: TextInputAction.next,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                ),
                const SizedBox(height: 20),

                // Mostrar costo de envío calculado
                if (_selectedCiudad != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? const Color(0xFF1E1E1E) 
                          : const Color(0xFF115213).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark 
                            ? Colors.grey[700]! 
                            : const Color(0xFF115213).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: const Color(0xFF2E7D32),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Costo de envío',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isCalculatingShipping)
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Calculando...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          )
                        else if (_calculatedShippingCost != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                '\$${_calculatedShippingCost!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Selecciona una ciudad para calcular el costo',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const SizedBox(height: 32),

                // Botón continuar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _continueToPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isDark ? 4 : 0,
                    ),
                    child: const Text(
                      'Continuar al pago',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

