import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pedido_service.dart';
import 'horario_service.dart';

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
  bool _horarioValidado = false;
  Map<String, dynamic>? _infoHorario;

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

  @override
  void initState() {
    super.initState();
    _verificarHorario();
  }

  // 🕐 NUEVA FUNCIÓN: Verificar horario al cargar la pantalla
  Future<void> _verificarHorario() async {
    final resultado = await HorarioService.verificarHorarioAtencion();
    setState(() {
      _infoHorario = resultado;
      _horarioValidado = true;
    });

    // Si está cerrado, mostrar diálogo inmediatamente
    if (!resultado['abierto']) {
      _mostrarDialogoHorarioCerrado();
    }
  }

  // 🚫 Mostrar diálogo cuando está fuera de horario
  void _mostrarDialogoHorarioCerrado() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.access_time, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Fuera de horario')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _infoHorario?['mensaje'] ?? 'No estamos atendiendo en este momento',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Horario de atención:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _infoHorario?['horario'] ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver al carrito
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  double get _totalConEmpaquetado {
    if (_tipoEmpaquetadoSeleccionado == null) return widget.total;
    
    final empaquetado = _tiposEmpaquetado.firstWhere(
      (e) => e['id'] == _tipoEmpaquetadoSeleccionado,
      orElse: () => _tiposEmpaquetado[0],
    );
    
    return widget.total + (empaquetado['precio'] as double);
  }

  Future<void> _finalizarCompra() async {
    // ⚠️ VALIDAR HORARIO NUEVAMENTE antes de procesar
    final horarioActual = await HorarioService.verificarHorarioAtencion();
    
    if (!horarioActual['abierto']) {
      _mostrarDialogoHorarioCerrado();
      return;
    }

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

      final productos = widget.items.map((item) => {
        'id': item['id'],
        'nombre': item['nombre'],
        'cantidad': item['cantidad'],
        'precio': item['precio'],
      }).toList();

      await PedidoService.reducirStockInmediato(productos);

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
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
    // Mostrar loading mientras se valida el horario
    if (!_horarioValidado) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF3E0),
        appBar: AppBar(
          title: const Text('Finalizar Compra'),
          backgroundColor: const Color(0xFFFF8C42),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Si está cerrado, deshabilitar el botón de confirmar
    final bool estaCerrado = !(_infoHorario?['abierto'] ?? false);

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
            // 🚨 ADVERTENCIA si está fuera de horario
            if (estaCerrado) ...[
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _infoHorario?['mensaje'] ?? 'Fuera de horario',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Dirección de entrega
            const Text(
              'Dirección de entrega',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _direccionController,
              enabled: !estaCerrado,
              decoration: InputDecoration(
                hintText: 'Ej: Av. Principal 123, Junín',
                filled: true,
                fillColor: estaCerrado ? Colors.grey.shade200 : Colors.white,
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
                onChanged: estaCerrado ? null : (value) {
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
                onChanged: estaCerrado ? null : (value) {
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
                onPressed: (_procesando || estaCerrado) ? null : _finalizarCompra,
                style: ElevatedButton.styleFrom(
                  backgroundColor: estaCerrado ? Colors.grey : const Color(0xFFFF8C42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _procesando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        estaCerrado ? 'Fuera de horario' : 'Confirmar Pedido',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}