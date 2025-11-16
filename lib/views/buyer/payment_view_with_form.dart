import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:agromarket/models/order_model.dart';
import 'package:agromarket/services/order_service.dart';
import 'package:agromarket/services/cart_service.dart';
import 'package:agromarket/services/stripe_service.dart';
import 'package:agromarket/services/email_service.dart';
import 'package:agromarket/services/firebase_service.dart';
import 'package:agromarket/views/buyer/order_confirmation_view.dart';

class PaymentView extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final double cartTotal;
  final String ciudad;
  final String telefono;

  const PaymentView({
    super.key,
    required this.cartItems,
    required this.cartTotal,
    required this.ciudad,
    required this.telefono,
  });

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  String _selectedPaymentMethod = 'tarjeta';
  bool _isProcessing = false;
  bool _sendEmailReceipt = true;
  
  // Controladores para el formulario de tarjeta
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderNameController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  final double _envio = 4.5;

  double get _subtotal => widget.cartTotal;
  double get _impuestos => _subtotal * 0.10;
  double get _total => _subtotal + _envio + _impuestos;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderNameController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _processPayment() async {
    if (_isProcessing) return;

    if (_selectedPaymentMethod == 'tarjeta') {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor inicia sesión para continuar'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final orderItems = widget.cartItems.map((cartItem) {
        return OrderItem(
          productoId: cartItem.productId,
          nombre: cartItem.productName,
          imagen: cartItem.productImage,
          precioUnitario: cartItem.unitPrice,
          precioTotal: cartItem.totalPrice,
          cantidad: cartItem.quantity,
          unidad: cartItem.unit,
          vendedorId: cartItem.sellerId,
        );
      }).toList();

      final sellerIds = widget.cartItems.map((item) => item.sellerId).toSet();
      if (sellerIds.isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró el vendedor de los productos.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          );
        }
        return;
      }

      if (sellerIds.length > 1) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por ahora solo puedes pagar productos de un vendedor a la vez.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          );
        }
        return;
      }

      final vendorId = sellerIds.first;
      final commissionPercent = 0.10; // 10% de comisión de la plataforma
      final applicationFeeAmount = (_subtotal * commissionPercent * 100).round();
      final provisionalOrderId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';

      String userName = user.displayName ?? user.email?.split('@').first ?? 'Usuario';
      String? paymentIntentId;

      if (_selectedPaymentMethod == 'tarjeta') {
        final paymentResult = await StripeService.createPaymentIntent(
          vendorId: vendorId,
          amount: _total,
          currency: 'mxn',
          applicationFeeAmount: applicationFeeAmount,
          orderId: provisionalOrderId,
          orderData: {
            'usuario_id': user.uid,
            'usuario_email': user.email ?? '',
            'usuario_nombre': userName,
            'total': _total,
            'subtotal': _subtotal,
            'envio': _envio,
            'impuestos': _impuestos,
            'metodo_pago': 'tarjeta',
            'productos': orderItems.map((item) => item.toJson()).toList(),
          },
          metadata: {
            'order_id': provisionalOrderId,
            'user_id': user.uid,
            'user_email': user.email ?? '',
            'vendor_id': vendorId,
          },
        );

        if (!paymentResult['success']) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(paymentResult['message'] ?? 'Error creando Payment Intent'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          return;
        }

        try {
          final expiryParts = _expiryDateController.text.split('/');
          final expiryMonth = int.parse(expiryParts[0]);
          final expiryYear = 2000 + int.parse(expiryParts[1]);
          final cardNumber = _cardNumberController.text.replaceAll(' ', '');
          
          final paymentMethodResult = await StripeService.createPaymentMethod(
            cardNumber: cardNumber,
            expiryMonth: expiryMonth,
            expiryYear: expiryYear,
            cvc: _cvvController.text,
            cardHolderName: _cardHolderNameController.text,
            email: _sendEmailReceipt ? user.email : null,
          );

          if (!paymentMethodResult['success']) {
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(paymentMethodResult['message'] ?? 'Error creando Payment Method'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
            return;
          }

          final paymentMethodId = paymentMethodResult['paymentMethodId'] as String;

          final confirmResult = await StripeService.confirmPaymentWithMethod(
            paymentIntentId: paymentResult['paymentIntentId'] as String,
            paymentMethodId: paymentMethodId,
          );

          if (!confirmResult['success']) {
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(confirmResult['message'] ?? 'Error confirmando el pago'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
            return;
          }

          paymentIntentId = paymentResult['paymentIntentId'];

          final serverConfirmResult = await StripeService.confirmPayment(
            paymentIntentId: paymentIntentId!,
            orderId: '',
          );

          if (!serverConfirmResult['success']) {
            print('⚠️ Advertencia: Error confirmando pago en servidor');
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error inesperado: ${e.toString()}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          return;
        }
      }

      final order = OrderModel.fromCart(
        usuarioId: user.uid,
        usuarioNombre: userName,
        usuarioEmail: user.email ?? '',
        ciudad: widget.ciudad,
        telefono: widget.telefono,
        metodoPago: _selectedPaymentMethod,
        productos: orderItems,
        envio: _envio,
        paymentIntentId: paymentIntentId,
      );

      final result = await OrderService.saveOrder(order);

      if (!mounted) return;

      if (result['success']) {
        final savedOrder = result['order'] as OrderModel? ?? order.copyWith(id: result['orderId']);
        final orderId = result['orderId'] as String;

        if (_selectedPaymentMethod == 'tarjeta' && paymentIntentId != null) {
          await StripeService.confirmPayment(
            paymentIntentId: paymentIntentId,
            orderId: orderId,
          );
        }

        // Enviar correo de confirmación/factura para todos los métodos de pago
        try {
          final productosParaEmail = orderItems.map((item) {
            return {
              'nombre': item.nombre,
              'cantidad': item.cantidad,
              'precio_unitario': item.precioUnitario,
              'precio_total': item.precioTotal,
              'unidad': item.unidad,
            };
          }).toList();

          // Obtener nombre del usuario
          String? userName;
          try {
            final userData = await FirebaseService.getCurrentUserData();
            userName = userData?['nombre'] as String?;
          } catch (e) {
            print('⚠️ No se pudo obtener el nombre del usuario: $e');
          }

          final emailResult = await EmailService.sendReceiptEmail(
            email: user.email ?? '',
            orderId: orderId,
            total: order.total,
            productos: productosParaEmail,
            userName: userName,
            subtotal: order.subtotal,
            envio: order.envio,
            impuestos: order.impuestos,
            ciudad: order.ciudad,
            telefono: order.telefono,
            direccionEntrega: order.direccionEntrega,
            metodoPago: order.metodoPago,
            fechaCompra: order.fechaCompra,
          );

          if (emailResult['success']) {
            print('✅ Correo de confirmación enviado exitosamente');
          } else {
            print('⚠️ Advertencia: No se pudo enviar el correo de confirmación: ${emailResult['message']}');
          }
        } catch (e) {
          print('⚠️ Error enviando correo de confirmación: $e');
          // No fallar el proceso si el correo no se puede enviar
        }

        await CartService.clearCart();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => OrderConfirmationView(
              order: savedOrder,
            ),
          ),
          (route) => route.isFirst,
        );
      } else {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al procesar el pago'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error procesando pago: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
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
          'Método de pago',
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF115213).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF115213).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                        Text(
                          '\$${_subtotal.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Envío',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                        Text(
                          '\$${_envio.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Impuestos (10%)',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                        Text(
                          '\$${_impuestos.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF115213),
                          ),
                        ),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF115213),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Selecciona método de pago',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              _buildPaymentOption(
                'tarjeta',
                'Tarjeta de crédito/débito',
                Icons.credit_card,
                _selectedPaymentMethod == 'tarjeta',
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                'efectivo',
                'Pago en efectivo',
                Icons.money,
                _selectedPaymentMethod == 'efectivo',
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, -0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _selectedPaymentMethod == 'tarjeta'
                    ? _buildCardForm()
                    : const SizedBox(key: Key('empty'), height: 0),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF115213),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirmar y pagar',
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
    );
  }

  Widget _buildPaymentOption(
    String value,
    String label,
    IconData icon,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF115213).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF115213)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF115213) : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF115213) : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF115213),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Form(
      key: _formKey,
      child: Container(
        key: const Key('card_form'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de la tarjeta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _cardHolderNameController,
              decoration: InputDecoration(
                labelText: 'Nombre del titular',
                hintText: 'Juan Pérez',
                prefixIcon: const Icon(Icons.person, color: Color(0xFF115213)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor ingresa el nombre del titular';
                }
                if (value.trim().length < 3) {
                  return 'El nombre debe tener al menos 3 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cardNumberController,
              decoration: InputDecoration(
                labelText: 'Número de tarjeta',
                hintText: '1234 5678 9012 3456',
                prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF115213)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              maxLength: 19,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CardNumberFormatter(),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor ingresa el número de tarjeta';
                }
                final cardNumber = value.replaceAll(' ', '');
                if (cardNumber.length < 13 || cardNumber.length > 19) {
                  return 'El número de tarjeta debe tener entre 13 y 19 dígitos';
                }
                if (!_isValidCardNumber(cardNumber)) {
                  return 'Número de tarjeta inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryDateController,
                    decoration: InputDecoration(
                      labelText: 'MM/YY',
                      hintText: '12/25',
                      prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF115213)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CardExpiryFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      if (!_isValidExpiryDate(value)) {
                        return 'Fecha inválida';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFF115213)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF115213), width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      if (value.length < 3) {
                        return 'CVV inválido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _sendEmailReceipt,
                  onChanged: (value) {
                    setState(() {
                      _sendEmailReceipt = value ?? true;
                    });
                  },
                  activeColor: const Color(0xFF115213),
                ),
                const Expanded(
                  child: Text(
                    'Enviar correo electrónico de confirmación de compra',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidCardNumber(String cardNumber) {
    if (cardNumber.length < 13 || cardNumber.length > 19) {
      return false;
    }
    int sum = 0;
    bool alternate = false;
    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int n = int.parse(cardNumber[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) {
          n = (n % 10) + 1;
        }
      }
      sum += n;
      alternate = !alternate;
    }
    return (sum % 10) == 0;
  }

  bool _isValidExpiryDate(String expiryDate) {
    if (expiryDate.length != 5) return false;
    final parts = expiryDate.split('/');
    if (parts.length != 2) return false;
    try {
      final month = int.parse(parts[0]);
      final year = int.parse(parts[1]);
      if (month < 1 || month > 12) return false;
      final now = DateTime.now();
      final currentYear = now.year % 100;
      final currentMonth = now.month;
      if (year < currentYear) return false;
      if (year == currentYear && month < currentMonth) return false;
      return true;
    } catch (e) {
      return false;
    }
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      if (i < 4) {
        buffer.write(text[i]);
      }
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

