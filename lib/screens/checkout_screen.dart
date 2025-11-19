import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pedido_service.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _metodoPagoSeleccionado;
  String? _tipoEmpaquetadoSeleccionado;
  final TextEditingController _direccionController = TextEditingController();
  bool _procesando = false;

  final List<Map<String, dynamic>> _metodosPago = [
    {'id': 'yape', 'nombre': 'Yape', 'icono': Icons.phone_android, 'color': Colors.purple},
    {'id': 'plin', 'nombre': 'Plin', 'icono': Icons.account_balance_wallet, 'color': Colors.blue},
    {'id': 'efectivo', 'nombre': 'Efectivo', 'icono': Icons.money, 'color': Colors.green},
    {'id': 'tarjeta', 'nombre': 'Tarjeta', 'icono': Icons.credit_card, 'color': Colors.orange},
  ];

  final List<Map<String, dynamic>> _tiposEmpaquetado = [
    {
      'id': 'basico',
      'nombre': 'Empaquetado Básico',
      'descripcion': 'Bolsa de papel estándar',
      'precio': 0.0,
      'icono': Icons.shopping_bag,
    },
    {
      'id': 'estandar',
      'nombre': 'Empaquetado Estándar',
      'descripcion': 'Caja de cartón con servilletas',
      'precio': 2.0,
      'icono': Icons.inventory_2,
    },
    {
      'id': 'premium',
      'nombre': 'Empaquetado Premium',
      'descripcion': 'Caja decorada con cubiertos y servilletas',
      'precio': 5.0,
      'icono': Icons.card_giftcard,
    },
    {
      'id': 'familiar',
      'nombre': 'Empaquetado Familiar',
      'descripcion': 'Caja grande con compartimentos y extras',
      'precio': 8.0,
      'icono': Icons.family_restroom,
    },
  ];

  double get _totalConEmpaquetado {
    if (_tipoEmpaquetadoSeleccionado == null) return widget.total;
    
    final empaquetado = _tiposEmpaquetado.firstWhere(
      (e) => e['id'] == _tipoEmpaquetadoSeleccionado,
      orElse: () => _tiposEmpaquetado[0],
    );
    
    return widget.total + (empaquetado['precio'] as double);
  }

  Future<void> _finalizarCompra() async {
    if (_metodoPagoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un método de pago')),
      );
      return;
    }

    if (_tipoEmpaquetadoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un tipo de empaquetado')),
      );
      return;
    }

    if (_direccionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una dirección de entrega')),
      );
      return;
    }

    setState(() => _procesando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Convertir items para guardar en BD
      final productos = widget.items.map((item) => {
        'id': item['id'],
        'nombre': item['nombre'],
        'cantidad': item['cantidad'],
        'precio': item['precio'],
      }).toList();

      // PRIMERO: Reducir el stock inmediatamente
      await PedidoService.reducirStockInmediato(productos);

      // SEGUNDO: Guardar el pedido en el historial
      await PedidoService.agregarPedidoAlHistorial(
        userId: user.uid,
        productos: productos,
        total: _totalConEmpaquetado,
        direccion: _direccionController.text.trim(),
        metodoPago: _metodoPagoSeleccionado!,
        tipoEmpaquetado: _tipoEmpaquetadoSeleccionado!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido realizado con éxito!'),
          ),
        );
        Navigator.pop(context, true); // Retornar true para indicar éxito
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar el pedido: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  @override
  void dispose() {
    _direccionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: const Text('Finalizar Compra'),
        backgroundColor: const Color(0xFFFF8C42),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dirección de entrega
            const Text(
              'Dirección de entrega',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _direccionController,
              decoration: InputDecoration(
                hintText: 'Ej: Av. Principal 123, Junín',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Método de pago
            const Text(
              'Método de pago',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...(_metodosPago.map((metodo) => Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _metodoPagoSeleccionado == metodo['id']
                      ? const Color(0xFFFF8C42)
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: RadioListTile<String>(
                value: metodo['id'],
                groupValue: _metodoPagoSeleccionado,
                onChanged: (value) {
                  setState(() => _metodoPagoSeleccionado = value);
                },
                title: Row(
                  children: [
                    Icon(metodo['icono'], color: metodo['color']),
                    const SizedBox(width: 10),
                    Text(metodo['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                activeColor: const Color(0xFFFF8C42),
              ),
            ))),
            const SizedBox(height: 24),

            // Tipo de empaquetado
            const Text(
              'Tipo de empaquetado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...(_tiposEmpaquetado.map((empaquetado) => Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _tipoEmpaquetadoSeleccionado == empaquetado['id']
                      ? const Color(0xFFFF8C42)
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: RadioListTile<String>(
                value: empaquetado['id'],
                groupValue: _tipoEmpaquetadoSeleccionado,
                onChanged: (value) {
                  setState(() => _tipoEmpaquetadoSeleccionado = value);
                },
                title: Row(
                  children: [
                    Icon(empaquetado['icono'], color: const Color(0xFFFF8C42)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            empaquetado['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            empaquetado['descripcion'],
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 40, top: 4),
                  child: Text(
                    empaquetado['precio'] == 0.0
                        ? 'Gratis'
                        : '+S/ ${(empaquetado['precio'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: empaquetado['precio'] == 0.0
                          ? Colors.green
                          : const Color(0xFFFF8C42),
                    ),
                  ),
                ),
                activeColor: const Color(0xFFFF8C42),
              ),
            ))),
            const SizedBox(height: 24),

            // Resumen
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal productos:'),
                      Text('S/ ${widget.total.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Empaquetado:'),
                      Text(
                        _tipoEmpaquetadoSeleccionado == null
                            ? 'S/ 0.00'
                            : 'S/ ${(_tiposEmpaquetado.firstWhere((e) => e['id'] == _tipoEmpaquetadoSeleccionado)['precio'] as double).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'S/ ${_totalConEmpaquetado.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF8C42),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botón de finalizar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _procesando ? null : _finalizarCompra,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _procesando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirmar Pedido',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}