import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pedido_service.dart';
import 'checkout_screen.dart';
import 'horario_service.dart';


class SimpleCart {
  SimpleCart._privateConstructor();
  static final SimpleCart instance = SimpleCart._privateConstructor();

  final Map<String, Map<String, dynamic>> _items = {};

  final ValueNotifier<int> itemsCountNotifier = ValueNotifier<int>(0);

  List<Map<String, dynamic>> get items => _items.values.toList();

  Map<String, dynamic>? getItemById(String id) {
    return _items[id];
  }

  void _updateItemsCount() {
    int total = 0;
    for (var item in _items.values) {
      total += item['cantidad'] as int;
    }
    itemsCountNotifier.value = total;
  }

  void addItem(Map<String, dynamic> producto) {
    final id = producto['id'] ?? producto['nombre'];
    final imagen = convertirEnlaceDriveADirecto(producto['imagen'] ?? '');
    if (_items.containsKey(id)) {
      _items[id]!['cantidad'] = _items[id]!['cantidad'] + 1;
    } else {
      _items[id] = {
        'id': id,
        'nombre': producto['nombre'],
        'precio': producto['precio'],
        'cantidad': 1,
        'stock': producto['stock'],
        'imagen': imagen,
      };
    }
    _updateItemsCount();
  }

  void increment(String id) {
    if (_items.containsKey(id)) {
      final item = _items[id]!;
      final stock = item['stock'] ?? 99999;
      if (item['cantidad'] < stock) {
        item['cantidad']++;
        _updateItemsCount();
      }
    }
  }

  void decrement(String id) {
    if (_items.containsKey(id)) {
      if (_items[id]!['cantidad'] > 1) {
        _items[id]!['cantidad']--;
      } else {
        _items.remove(id);
      }
      _updateItemsCount();
    }
  }

  void removeItem(String id) {
    _items.remove(id);
    _updateItemsCount();
  }

  void clear() {
    _items.clear();
    _updateItemsCount();
  }

  double get total {
    double t = 0;
    for (var it in _items.values) {
      t += (it['precio'] as num) * (it['cantidad'] as int);
    }
    return t;
  }
}

String convertirEnlaceDriveADirecto(String url) {
  if (url.contains('drive.google.com')) {
    final regex = RegExp(r'/d/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      final id = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$id';
    }
  }
  return url;
}

class CarritoScreen extends StatefulWidget {
  final void Function(int) onCartChanged;
  const CarritoScreen({super.key, required this.onCartChanged});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  bool _procesando = false;
  List<Map<String, dynamic>> _productosConProblemas = [];

  @override
  void initState() {
    super.initState();
    _validarStockInicial();
  }

  Future<void> _validarStockInicial() async {
    final resultado = await PedidoService.validarStockCarrito(
        SimpleCart.instance.items);
    if (!resultado['stockSuficiente']) {
      setState(() {
        _productosConProblemas = resultado['productos'];
      });
    }
  }

  void _updateCartCounter() {
    final count = SimpleCart.instance.items.fold<int>(
        0, (prev, item) => prev + (item['cantidad'] as int));
    widget.onCartChanged(count);
  }

  void _incrementItem(String id) {
    setState(() {
      SimpleCart.instance.increment(id);
    });
    _updateCartCounter();
    _validarStockInicial();
  }

  void _decrementItem(String id) {
    setState(() {
      SimpleCart.instance.decrement(id);
    });
    _updateCartCounter();
    _validarStockInicial();
  }

  void _removeItem(String id) {
    setState(() {
      SimpleCart.instance.removeItem(id);
    });
    _updateCartCounter();
    _validarStockInicial();
  }

  void _clearCart() {
    setState(() {
      SimpleCart.instance.clear();
      _productosConProblemas.clear();
    });
    widget.onCartChanged(0);
  }

  // En carrito_screen.dart, actualiza la función _irACheckout:

  Future<void> _irACheckout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🕐 VALIDAR HORARIO antes de permitir checkout
    final horario = await HorarioService.verificarHorarioAtencion();
    
    if (!horario['abierto']) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.access_time, color: Colors.red.shade700),
                const SizedBox(width: 10),
                const Text('Fuera de horario'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(horario['mensaje']),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Horario de atención:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(horario['horario']),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Validar stock
    final resultado = await PedidoService.validarStockCarrito(
        SimpleCart.instance.items);

    if (!resultado['stockSuficiente']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Algunos productos no tienen stock suficiente'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Navegar a checkout
    if (mounted) {
      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            items: SimpleCart.instance.items,
            total: SimpleCart.instance.total,
          ),
        ),
      );

      if (resultado == true) {
        SimpleCart.instance.clear();
        widget.onCartChanged(0);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = SimpleCart.instance.items;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Tu Carrito',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          // Mostrar advertencias de stock
          if (_productosConProblemas.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Problemas de stock:',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(_productosConProblemas.map((p) => Text(
                        '• ${p['nombre']}: Solicitaste ${p['solicitado']}, disponible: ${p['disponible']}',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                      ))),
                ],
              ),
            ),
          ],

          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No hay productos en el carrito.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final it = items[index];
                      final item = SimpleCart.instance.getItemById(it['id']);
                      if (item == null) return Container();

                      // Verificar si este producto tiene problema de stock
                      final tieneProblema = _productosConProblemas
                          .any((p) => p['nombre'] == item['nombre']);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: tieneProblema
                            ? Colors.red.shade50
                            : Colors.white,
                        child: ListTile(
                          leading: item['imagen'] != null &&
                                  item['imagen'].isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item['imagen'],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image,
                                                size: 40),
                                  ),
                                )
                              : const Icon(Icons.shopping_bag),
                          title: Text(item['nombre']),
                          subtitle: Row(
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.remove_circle_outline),
                                onPressed: () => _decrementItem(it['id']),
                              ),
                              Text('${item['cantidad']}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  if (item['cantidad'] >= item['stock']) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Stock máximo alcanzado para ${item['nombre']}'),
                                        duration:
                                            const Duration(milliseconds: 500),
                                      ),
                                    );
                                    return;
                                  }
                                  _incrementItem(it['id']);
                                },
                              ),
                              const SizedBox(width: 10),
                              Text(
                                  'S/ ${(item['precio'] * item['cantidad']).toStringAsFixed(2)}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItem(it['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Text('Total: S/ ${SimpleCart.instance.total.toStringAsFixed(2)}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _procesando
              ? const CircularProgressIndicator()
              : Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: SimpleCart.instance.items.isEmpty ||
                                _productosConProblemas.isNotEmpty
                            ? null
                            : _irACheckout,
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 204, 170, 79)),
                        child: const Text('Continuar compra'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: SimpleCart.instance.items.isEmpty
                          ? null
                          : _clearCart,
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 220, 66, 66)),
                      child: const Text('Vaciar'),
                    ),
                  ],
                )
        ],
      ),
    );
  }
}