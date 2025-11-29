import 'package:flutter/material.dart';
import 'package:agromarket/models/order_model.dart';
import 'package:agromarket/services/order_service.dart';
import 'package:agromarket/views/buyer/order_confirmation_view.dart';

class MyOrdersView extends StatefulWidget {
  const MyOrdersView({super.key});

  @override
  State<MyOrdersView> createState() => _MyOrdersViewState();
}

class _MyOrdersViewState extends State<MyOrdersView> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _selectedStatus; // null = todos los estados

  // Estados disponibles para filtrar
  final List<String> _availableStatuses = [
    'preparando',
    'enviado',
    'entregado',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await OrderService.getUserOrders();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error cargando órdenes: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar las órdenes: ${e.toString()}'),
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

  String _formatDateHeader(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  // Agrupar pedidos por fecha
  Map<String, List<OrderModel>> _groupOrdersByDate(List<OrderModel> orders) {
    final Map<String, List<OrderModel>> grouped = {};
    
    for (var order in orders) {
      final dateKey = '${order.fechaCompra.year}-${order.fechaCompra.month.toString().padLeft(2, '0')}-${order.fechaCompra.day.toString().padLeft(2, '0')}';
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(order);
    }
    
    // Ordenar las fechas de más reciente a más antigua
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedMap = <String, List<OrderModel>>{};
    for (var key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }
    
    return sortedMap;
  }

  String _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pagado':
        return '0xFF4CAF50';
      case 'preparando':
        return '0xFFFF9800';
      case 'enviado':
        return '0xFF2196F3';
      case 'entregado':
        return '0xFF4CAF50';
      default:
        return '0xFF757575';
    }
  }

  // Obtener pedidos filtrados por estado
  List<OrderModel> get _filteredOrders {
    if (_selectedStatus == null) {
      return _orders;
    }
    return _orders.where((order) => 
      order.estadoPedido.toLowerCase() == _selectedStatus!.toLowerCase()
    ).toList();
  }

  // Obtener el nombre del estado en español
  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'preparando':
        return 'Preparando';
      case 'enviado':
        return 'Enviado';
      case 'entregado':
        return 'Entregado';
      case 'pagado':
        return 'Pagado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis compras',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 80,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes compras aún',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cuando hagas una compra, aparecerá aquí',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filtros por estado
                    _buildStatusFilters(),
                    // Lista de pedidos
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadOrders,
                        color: Theme.of(context).colorScheme.primary,
                        child: _buildGroupedOrdersList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatusFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Botón "Todos"
            _buildFilterChip(
              label: 'Todos',
              isSelected: _selectedStatus == null,
              onTap: () {
                setState(() {
                  _selectedStatus = null;
                });
              },
            ),
            const SizedBox(width: 8),
            // Filtros por estado
            ..._availableStatuses.map((status) {
              final isSelected = _selectedStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: _getStatusLabel(status),
                  isSelected: isSelected,
                  statusColor: Color(int.parse(_getStatusColor(status))),
                  onTap: () {
                    setState(() {
                      _selectedStatus = isSelected ? null : status;
                    });
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? statusColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = statusColor ?? Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withOpacity(0.15)
                : (isDark ? Colors.grey[800] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statusColor != null && isSelected) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedOrdersList() {
    final filteredOrders = _filteredOrders;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_outlined,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == null
                  ? 'No tienes compras aún'
                  : 'No hay pedidos con estado "${_getStatusLabel(_selectedStatus!)}"',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedStatus != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedStatus = null;
                  });
                },
                child: Text(
                  'Ver todos los pedidos',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    final groupedOrders = _groupOrdersByDate(filteredOrders);
    
    if (groupedOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> widgets = [];
    
    groupedOrders.forEach((dateKey, orders) {
      // Parsear la fecha del key
      final dateParts = dateKey.split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
      
      // Agregar encabezado de fecha con diseño mejorado
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDateHeader(date),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      );
      
      // Agregar los pedidos de esta fecha
      for (var order in orders) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildOrderCard(order),
          ),
        );
      }
    });
    
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: widgets,
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Obtener el primer producto para mostrar
    final firstProduct = order.productos.isNotEmpty ? order.productos[0] : null;
    final productImage = firstProduct != null && firstProduct.imagen.isNotEmpty
        ? firstProduct.imagen
        : null;
    final productName = firstProduct?.nombre ?? 'Producto';
    final productQuantity = firstProduct != null
        ? '${firstProduct.cantidad} ${firstProduct.unidad}'
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderConfirmationView(order: order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Imagen del producto con efecto de elevación
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: productImage != null
                      ? Image.network(
                          productImage,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [Colors.grey[800]!, Colors.grey[900]!]
                                      : [Colors.grey[200]!, Colors.grey[300]!],
                                ),
                              ),
                              child: Icon(
                                Icons.image_not_supported,
                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                                size: 28,
                              ),
                            );
                          },
                        )
                      : Builder(
                          builder: (context) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [Colors.grey[800]!, Colors.grey[900]!]
                                      : [Colors.grey[100]!, Colors.grey[200]!],
                                ),
                              ),
                              child: Icon(
                                Icons.shopping_bag_rounded,
                                color: isDark ? Colors.grey[500] : Colors.grey[400],
                                size: 36,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Información del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Estado con diseño mejorado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Color(int.parse(_getStatusColor(order.estadoPedido))).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(int.parse(_getStatusColor(order.estadoPedido))).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Color(int.parse(_getStatusColor(order.estadoPedido))),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.estadoPedido[0].toUpperCase() + order.estadoPedido.substring(1),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(int.parse(_getStatusColor(order.estadoPedido))),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Nombre del producto
                    Builder(
                      builder: (context) {
                        return Text(
                          productName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    if (productQuantity.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                productQuantity,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Precio con diseño mejorado
              Builder(
                builder: (context) {
                  final primaryColor = Theme.of(context).colorScheme.primary;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '\$${order.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

