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

      // Agrupar productos por vendedor
      final Map<String, List<CartItemModel>> itemsByVendor = {};
      for (var item in widget.cartItems) {
        if (!itemsByVendor.containsKey(item.sellerId)) {
          itemsByVendor[item.sellerId] = [];
        }
        itemsByVendor[item.sellerId]!.add(item);
      }

      String userName = user.displayName ?? user.email?.split('@').first ?? 'Usuario';
      final commissionPercent = 0.10; // 10% de comisión para la plataforma
      final List<Map<String, dynamic>> processedOrders = [];
      bool allPaymentsSuccessful = true;
      String? lastError;
      String? mainPaymentIntentId;

      // Si hay múltiples vendedores, procesar el pago una sola vez con el total combinado
      if (sellerIds.length > 1 && _selectedPaymentMethod == 'tarjeta') {
        // Crear un PaymentIntent simple (sin Connect) para el total combinado
        final paymentResult = await StripeService.createPaymentIntent(
          vendorId: '', // Vacío para PaymentIntent simple
          amount: _total,
          currency: 'mxn',
          applicationFeeAmount: 0, // Sin comisión en el PaymentIntent principal
          orderId: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
          orderData: {
            'usuario_id': user.uid,
            'usuario_email': user.email ?? '',
            'usuario_nombre': userName,
            'total': _total,
            'subtotal': _subtotal,
            'envio': _envio,
            'impuestos': _impuestos,
            'metodo_pago': 'tarjeta',
            'multiple_vendors': true,
          },
          metadata: {
            'user_id': user.uid,
            'user_email': user.email ?? '',
            'multiple_vendors': 'true',
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
          // Presentar Payment Sheet UNA SOLA VEZ
          print('💳 Iniciando Payment Sheet para múltiples vendedores...');
          
          final clientSecret = paymentResult['clientSecret'] as String;
          
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
          
          await Stripe.instance.presentPaymentSheet();
          
          print('✅ Payment Sheet completado exitosamente');
          
          mainPaymentIntentId = paymentResult['paymentIntentId'] as String;
        } on StripeException catch (e) {
          print('❌ Error de Stripe: ${e.error.code} - ${e.error.message}');
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

      // Procesar cada grupo de vendedor por separado
      for (var vendorId in sellerIds) {
        final vendorItems = itemsByVendor[vendorId]!;
        final vendorSubtotal = vendorItems.fold(0.0, (sum, item) => sum + item.totalPrice);
        final vendorEnvio = _envio / sellerIds.length; // Dividir envío entre vendedores
        final vendorImpuestos = vendorSubtotal * 0.10;
        final vendorTotal = vendorSubtotal + vendorEnvio + vendorImpuestos;
        final applicationFeeAmount = (vendorSubtotal * commissionPercent * 100).round();
        final provisionalOrderId = sellerIds.length > 1 
            ? 'tmp_${DateTime.now().millisecondsSinceEpoch}_${vendorId}'
            : 'tmp_${DateTime.now().millisecondsSinceEpoch}';

        final orderItems = vendorItems.map((cartItem) {
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

        String? paymentIntentId;

        // Si hay un solo vendedor, procesar el pago normalmente con Connect
        if (_selectedPaymentMethod == 'tarjeta' && sellerIds.length == 1) {
          // Paso 1: Crear Payment Intent en el servidor
          final paymentResult = await StripeService.createPaymentIntent(
            vendorId: vendorId,
            amount: vendorTotal,
            currency: 'mxn',
            applicationFeeAmount: applicationFeeAmount,
            orderId: provisionalOrderId,
            orderData: {
              'usuario_id': user.uid,
              'usuario_email': user.email ?? '',
              'usuario_nombre': userName,
              'total': vendorTotal,
              'subtotal': vendorSubtotal,
              'envio': vendorEnvio,
              'impuestos': vendorImpuestos,
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
            allPaymentsSuccessful = false;
            lastError = paymentResult['message'] ?? 'Error creando Payment Intent';
            break;
          }

          try {
            // Paso 2: Usar Payment Sheet de Stripe
            print('💳 Iniciando Payment Sheet para vendedor $vendorId...');
            
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
            
            print('✅ Payment Sheet completado exitosamente para vendedor $vendorId');
            
            // Guardar el Payment Intent ID para asociarlo con la orden
            paymentIntentId = paymentResult['paymentIntentId'] as String;
          } on StripeException catch (e) {
            print('❌ Error de Stripe: ${e.error.code} - ${e.error.message}');
            allPaymentsSuccessful = false;
            if (e.error.code == FailureCode.Canceled) {
              lastError = 'Pago cancelado';
            } else {
              lastError = e.error.message ?? 'Error procesando el pago';
            }
            break;
          } catch (e, stackTrace) {
            print('❌ Error inesperado en pago: $e');
            print('❌ Stack trace: $stackTrace');
            allPaymentsSuccessful = false;
            lastError = 'Error inesperado: ${e.toString()}';
            break;
          }
        } else if (_selectedPaymentMethod == 'tarjeta' && sellerIds.length > 1) {
          // Si hay múltiples vendedores, usar el PaymentIntent principal ya procesado
          paymentIntentId = mainPaymentIntentId;
        }

        // Crear orden para este vendedor
        final order = OrderModel.fromCart(
          usuarioId: user.uid,
          usuarioNombre: userName,
          usuarioEmail: user.email ?? '',
          ciudad: widget.ciudad,
          telefono: widget.telefono,
          direccionEntrega: widget.direccionEntrega,
          metodoPago: _selectedPaymentMethod,
          productos: orderItems,
          envio: vendorEnvio,
          paymentIntentId: paymentIntentId,
        );

        final result = await OrderService.saveOrder(order);

        if (!result['success']) {
          allPaymentsSuccessful = false;
          lastError = result['message'] ?? 'Error al guardar la orden';
          break;
        }

        final savedOrder = result['order'] as OrderModel? ?? order.copyWith(id: result['orderId']);
        final orderId = result['orderId'] as String;

        // Si el pago es con tarjeta, registrar la confirmación en el servidor
        if (_selectedPaymentMethod == 'tarjeta' && paymentIntentId != null) {
          final confirmPaymentResult = await StripeService.confirmPayment(
            paymentIntentId: paymentIntentId,
            orderId: orderId,
          );

          if (!confirmPaymentResult['success']) {
            print('⚠️ Advertencia: Error registrando confirmación de pago en servidor para orden $orderId');
          }
        }

        processedOrders.add({
          'order': savedOrder,
          'orderId': orderId,
          'orderItems': orderItems,
        });
      }

      if (!mounted) return;

      if (!allPaymentsSuccessful) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lastError ?? 'Error al procesar el pago'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      // Enviar correo de confirmación con todas las órdenes
      try {
        final allProductosParaEmail = <Map<String, dynamic>>[];
        double totalGeneral = 0;
        double subtotalGeneral = 0;
        double envioGeneral = 0;
        double impuestosGeneral = 0;

        for (var orderData in processedOrders) {
          final orderItems = orderData['orderItems'] as List<OrderItem>;
          for (var item in orderItems) {
            allProductosParaEmail.add({
              'nombre': item.nombre,
              'cantidad': item.cantidad,
              'precio_unitario': item.precioUnitario,
              'precio_total': item.precioTotal,
              'unidad': item.unidad,
            });
          }
          final order = orderData['order'] as OrderModel;
          totalGeneral += order.total;
          subtotalGeneral += order.subtotal;
          envioGeneral += order.envio;
          impuestosGeneral += order.impuestos;
        }

        final emailResult = await EmailService.sendReceiptEmail(
          email: user.email ?? '',
          orderId: processedOrders.map((o) => o['orderId'] as String).join(', '),
          total: totalGeneral,
          productos: allProductosParaEmail,
          userName: userName,
          subtotal: subtotalGeneral,
          envio: envioGeneral,
          impuestos: impuestosGeneral,
          ciudad: widget.ciudad,
          telefono: widget.telefono,
          direccionEntrega: widget.direccionEntrega,
          metodoPago: _selectedPaymentMethod,
          fechaCompra: DateTime.now(),
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

      // Navegar a la confirmación con la primera orden (o crear una vista que muestre todas)
      final firstOrder = processedOrders.first['order'] as OrderModel;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderConfirmationView(
            order: firstOrder,
          ),
        ),
        (route) => route.isFirst,
      );
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

