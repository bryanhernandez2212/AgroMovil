import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:agromarket/services/sanitization_service.dart';
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

  // Ciudades pre-cargadas
  final List<String> _ciudades = [
    'San Cristóbal de las Casas',
    'Yajalón',
    'Chilón',
    'Ocosingo',
    'Comitán de Domínguez',
  ];

  @override
  void dispose() {
    _telefonoController.dispose();
    super.dispose();
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

      // Navegar a la vista de pago
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentView(
            cartItems: widget.cartItems,
            cartTotal: widget.cartTotal,
            ciudad: _selectedCiudad!,
            telefono: cleanPhone,
            direccionEntrega: null,
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
                    });
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

