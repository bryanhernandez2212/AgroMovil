import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:agromarket/models/cart_item_model.dart';
import 'package:agromarket/models/order_model.dart';
import 'package:agromarket/services/order_service.dart';
import 'package:agromarket/services/cart_service.dart';
import 'package:agromarket/services/stripe_service.dart';
import 'package:agromarket/services/stock_service.dart';
import 'package:agromarket/services/email_service.dart';
import 'package:agromarket/views/buyer/order_confirmation_view.dart';

class PaymentView extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final double cartTotal;
  final String ciudad;
  final String telefono;
  final String? direccionEntrega;

  const PaymentView({
    super.key,
    required this.cartItems,
    required this.cartTotal,
    required this.ciudad,
    required this.telefono,
    this.direccionEntrega,
  });

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  String _selectedPaymentMethod = 'tarjeta';
  bool _isProcessing = false;
  
  // Controlador para el nombre del titular (opcional, para Payment Sheet)
  final TextEditingController _cardHolderNameController = TextEditingController();
  
  final double _envio = 4.5;

  double get _subtotal => widget.cartTotal;
  double get _impuestos => _subtotal * 0.10;
  double get _total => _subtotal + _envio + _impuestos;

  @override
  void dispose() {
    _cardHolderNameController.dispose();
    super.dispose();
  }

  void _processPayment() async {
    if (_isProcessing) return;

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
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              margin: EdgeInsets.all(16),
            ),
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Validar stock antes de procesar el pago (solo validar, no actualizar)
      print('📦 Validando stock antes de procesar pago...');
      
      for (var item in widget.cartItems) {
        final stockValidation = await StockService.validateStock(item.productId, item.quantity);
        
        if (!stockValidation['success']) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(stockValidation['message'] ?? 'Stock insuficiente para ${item.productName}'),
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
          return;
        }
      }

      print('✅ Stock validado correctamente');
 
      final sellerIds = widget.cartItems.map((item) => item.sellerId).toSet();
      if (sellerIds.isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo identificar al vendedor de los productos.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              margin: EdgeInsets.all(16),
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
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              margin: EdgeInsets.all(16),
            ),
          );
        }
        return;
      }

      final vendorId = sellerIds.first;
      final commissionPercent = 0.10; // 10% de comisión para la plataforma
      final applicationFeeAmount = (_subtotal * commissionPercent * 100).round();
      final provisionalOrderId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';

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

      String userName = user.displayName ?? user.email?.split('@').first ?? 'Usuario';
      String? paymentIntentId;

      if (_selectedPaymentMethod == 'tarjeta') {
        // Paso 1: Crear Payment Intent en el servidor
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
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
          return;
        }

        try {
          // Paso 2: Usar Payment Sheet de Stripe (método seguro y recomendado)
          print('💳 Iniciando Payment Sheet...');
          
          final clientSecret = paymentResult['clientSecret'] as String;
          
          // Inicializar Payment Sheet
          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: 'AgroMarket',
              billingDetails: BillingDetails(
                name: _cardHolderNameController.text.isNotEmpty 
                    ? _cardHolderNameController.text 
                    : user.displayName ?? user.email?.split('@').first ?? 'Cliente',
                email: user.email,
              ),
            ),
          );
          
          // Presentar Payment Sheet
          await Stripe.instance.presentPaymentSheet();
          
          print('✅ Payment Sheet completado exitosamente');
          
          // Guardar el Payment Intent ID para asociarlo con la orden
          paymentIntentId = paymentResult['paymentIntentId'] as String;
        } on StripeException catch (e) {
          print('❌ Error de Stripe: ${e.error.code} - ${e.error.message}');
          print('❌ Tipo de error: ${e.error.type}');
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            
            String errorMessage = 'Error procesando el pago';
            if (e.error.code == FailureCode.Canceled) {
              errorMessage = 'Pago cancelado';
            } else if (e.error.message != null) {
              errorMessage = e.error.message!;
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
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
          return;
        } catch (e, stackTrace) {
          print('❌ Error inesperado en pago: $e');
          print('❌ Stack trace: $stackTrace');
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error inesperado: ${e.toString()}'),
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
          return;
        }
      }

      final order = OrderModel.fromCart(
        usuarioId: user.uid,
        usuarioNombre: userName,
        usuarioEmail: user.email ?? '',
        ciudad: widget.ciudad,
        telefono: widget.telefono,
        direccionEntrega: widget.direccionEntrega,
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

        // Si el pago es con tarjeta, registrar la confirmación en el servidor
        if (_selectedPaymentMethod == 'tarjeta' && paymentIntentId != null) {
          // Confirmar que el pago se asoció correctamente con la orden
          final confirmPaymentResult = await StripeService.confirmPayment(
            paymentIntentId: paymentIntentId,
            orderId: orderId,
          );

          if (!confirmPaymentResult['success']) {
            print('⚠️ Advertencia: Error registrando confirmación de pago en servidor');
            print('   - El pago fue procesado, pero puede haber un problema al registrar la asociación');
          }
        }

        // Enviar correo de confirmación/factura
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
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
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
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
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
              const SizedBox(height: 32),
              // Botón de pago para tarjeta (usará Payment Sheet)
              if (_selectedPaymentMethod == 'tarjeta')
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
                            'Pagar con tarjeta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              if (_selectedPaymentMethod != 'tarjeta')
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

}

