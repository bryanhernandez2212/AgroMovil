import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:agromarket/models/order_model.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/services/chat_service.dart';
import 'package:agromarket/views/profile/chat_conversation_view.dart';

class OrderConfirmationView extends StatefulWidget {
  final OrderModel order;

  const OrderConfirmationView({
    super.key,
    required this.order,
  });

  @override
  State<OrderConfirmationView> createState() => _OrderConfirmationViewState();
}

class _OrderConfirmationViewState extends State<OrderConfirmationView> {
  static const List<String> _statusSequence = [
    'preparando',
    'enviado',
    'recibido',
    'devolucion',
  ];

  late String _orderStatus;
  bool _isUpdatingStatus = false;
  bool _shouldRefreshOnPop = false;

  @override
  void initState() {
    super.initState();
    _orderStatus = widget.order.estadoPedido;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pagado':
        return '0xFF4CAF50';
      case 'preparando':
        return '0xFFFF9800';
      case 'enviado':
        return '0xFF2196F3';
      case 'recibido':
        return '0xFF4CAF50';
      case 'devolucion':
        return '0xFFF44336';
      default:
        return '0xFF757575';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final currentUser = authController.currentUser;
    final firstProduct = widget.order.productos.isNotEmpty ? widget.order.productos.first : null;

    String? sellerUserId;
    if (currentUser != null &&
        firstProduct != null &&
        (currentUser.rolActivo.toLowerCase() == 'vendedor' ||
            currentUser.id == firstProduct.vendedorId)) {
      sellerUserId = currentUser.id;
    }
    final bool isSellerContext = sellerUserId != null;
    final contactButtonLabel = isSellerContext ? 'Contactar comprador' : 'Contactar vendedor';

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_shouldRefreshOnPop);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF115213)),
            onPressed: () => Navigator.of(context).pop(_shouldRefreshOnPop),
          ),
          title: const Text(
            'Detalles del pedido',
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
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID del pedido',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: Text(
                              widget.order.id,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: sellerUserId != null
                            ? _buildStatusDropdown(sellerUserId)
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(int.parse(_getStatusColor(_orderStatus))).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _orderStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(int.parse(_getStatusColor(_orderStatus))),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('Información del pedido'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildInfoRow('Fecha de compra', _formatDate(widget.order.fechaCompra)),
                  _buildInfoRow('Estado del pago', widget.order.estado),
                  _buildInfoRow('Estado del pedido', _orderStatus),
                  _buildInfoRow('Método de pago', widget.order.metodoPago == 'tarjeta' ? 'Tarjeta' : widget.order.metodoPago),
                  if (widget.order.paymentIntentId != null)
                    _buildInfoRow('ID de pago', widget.order.paymentIntentId!),
                ]),
                const SizedBox(height: 24),

                _buildSectionTitle('Dirección de envío'),
                const SizedBox(height: 12),
                _buildInfoCard([
                _buildInfoRow('Destino', widget.order.ciudad.isNotEmpty ? widget.order.ciudad : 'No especificado'),
                  if (widget.order.telefono.isNotEmpty)
                    _buildInfoRow('Teléfono', widget.order.telefono),
                ]),
                const SizedBox(height: 24),

                _buildSectionTitle('Productos (${widget.order.productos.length})'),
                const SizedBox(height: 12),
                ...widget.order.productos.map((producto) => _buildProductCard(producto)),
                const SizedBox(height: 24),

                _buildSectionTitle('Resumen'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildInfoRow('Subtotal', '\$${widget.order.subtotal.toStringAsFixed(2)}'),
                  _buildInfoRow('Envío', '\$${widget.order.envio.toStringAsFixed(2)}'),
                  _buildInfoRow('Impuestos (10%)', '\$${widget.order.impuestos.toStringAsFixed(2)}'),
                  const Divider(height: 24),
                  _buildInfoRow(
                    'Total',
                    '\$${widget.order.total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ]),
                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Funcionalidad de devolución próximamente'),
                              backgroundColor: const Color(0xFF115213),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_return, size: 20),
                        label: const Text('Devolución'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF115213),
                          side: const BorderSide(color: Color(0xFF115213)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _contactCounterpart(context),
                        icon: const Icon(Icons.message, size: 20),
                        label: Text(contactButtonLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF115213),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF115213) : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(OrderItem producto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: producto.imagen.isNotEmpty
                ? Image.network(
                    producto.imagen,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${producto.cantidad} ${producto.unidad} x \$${producto.precioUnitario.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${producto.precioTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF115213),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(String currentUserId) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(int.parse(_getStatusColor(_orderStatus))).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(int.parse(_getStatusColor(_orderStatus))),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _orderStatus,
          icon: _isUpdatingStatus
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_drop_down),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(int.parse(_getStatusColor(_orderStatus))),
          ),
          onChanged: _isUpdatingStatus
              ? null
              : (value) {
                  if (value == null || value == _orderStatus) return;
                  _updateOrderStatus(value, currentUserId);
                },
          items: _statusSequence
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.toUpperCase()),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(String newStatus, String currentUserId) async {
    final currentIndex = _statusSequence.indexOf(_orderStatus);
    final newIndex = _statusSequence.indexOf(newStatus);

    if (newIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado no válido: $newStatus'),
          backgroundColor: Colors.redAccent,
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

    if (newIndex < currentIndex) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No puedes regresar a un estado anterior.'),
          backgroundColor: Colors.redAccent,
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

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('compras').doc(widget.order.id);
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        throw Exception('El pedido no existe');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final productos = List<Map<String, dynamic>>.from(
        (data['productos'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((producto) {
          final map = Map<String, dynamic>.from(producto);
          final vendedorId = map['vendedor_id']?.toString() ?? '';
          if (vendedorId == currentUserId) {
            map['estado_pedido'] = newStatus;
            map['fecha_actualizacion_estado'] = DateTime.now().toIso8601String();
          }
          return map;
        }),
      );

      await docRef.update({
        'estado_pedido': newStatus,
        'fecha_actualizacion_estado': FieldValue.serverTimestamp(),
        'productos': productos,
      });

      setState(() {
        _orderStatus = newStatus;
        _shouldRefreshOnPop = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a ${newStatus.toUpperCase()}'),
          backgroundColor: const Color(0xFF115213),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar el estado: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  Future<void> _contactCounterpart(BuildContext context) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUser = authController.currentUser;

    if (currentUser == null) {
      _showSnackBar(
        context,
        'Debes iniciar sesión para contactar al vendedor.',
        isError: true,
      );
      return;
    }

    if (widget.order.productos.isEmpty) {
      _showSnackBar(
        context,
        'No encontramos información vinculada al pedido.',
        isError: true,
      );
      return;
    }

    final firstProduct = widget.order.productos.first;
    final bool isSellerContext =
        currentUser.rolActivo.toLowerCase() == 'vendedor' ||
            currentUser.id == firstProduct.vendedorId;

    final String targetUserId;
    final String fallbackName;

    if (isSellerContext) {
      targetUserId = widget.order.usuarioId;
      fallbackName = widget.order.usuarioNombre.isNotEmpty ? widget.order.usuarioNombre : 'Comprador';
    } else {
      targetUserId = firstProduct.vendedorId;
      fallbackName = 'Vendedor';
    }

    if (targetUserId.isEmpty) {
      _showSnackBar(
        context,
        'No encontramos información del usuario para este pedido.',
        isError: true,
      );
      return;
    }

    if (widget.order.id.isEmpty) {
      _showSnackBar(
        context,
        'Este pedido no tiene un identificador válido.',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
        ),
      ),
    );

    try {
      final targetDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(targetUserId)
          .get();

      final targetData = targetDoc.data() ?? <String, dynamic>{};
      final targetName = targetData['nombre']?.toString() ??
          targetData['nombre_tienda']?.toString() ??
          fallbackName;
      final targetPhoto = targetData['photoUrl']?.toString();

      final chatId = await ChatService.ensureChat(
        orderId: widget.order.id,
        currentUserId: currentUser.id,
        otherUserId: targetUserId,
        currentUserName: currentUser.nombre,
        otherUserName: targetName,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationView(
              chatId: chatId,
              userName: targetName,
              otherUserId: targetUserId,
              orderId: widget.order.id,
              userImage: targetPhoto,
              isOnline: targetData['isOnline'] == true,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar(
          context,
          'No se pudo iniciar la conversación: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF115213),
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

