import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agromarket/models/cart_item_model.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF115213)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Dirección de envío',
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del pedido
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF115213).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF115213).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        color: Color(0xFF115213),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.cartItems.length} producto${widget.cartItems.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Total: \$${widget.cartTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF115213),
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
                const Text(
                  'Información de envío',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa los datos para la entrega de tu pedido',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Campo de ciudad (Dropdown)
                DropdownButtonFormField<String>(
                  value: _selectedCiudad,
                  decoration: InputDecoration(
                    labelText: 'Ciudad *',
                    prefixIcon: const Icon(Icons.location_city, color: Color(0xFF115213)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
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
                  validator: _validateCiudad,
                  items: _ciudades.map((ciudad) {
                    return DropdownMenuItem<String>(
                      value: ciudad,
                      child: Text(ciudad),
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
                  decoration: InputDecoration(
                    labelText: 'Teléfono *',
                    hintText: 'Ej: 9671636739',
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFF115213)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
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
                      backgroundColor: const Color(0xFF115213),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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

