import 'package:cloud_firestore/cloud_firestore.dart';

class PedidoService {
  static Future<void> agregarPedidoAlHistorial({
    required String userId,
    required List<Map<String, dynamic>> productos,
    required double total,
    required String direccion,
    required String metodoPago,
    required String tipoEmpaquetado,
    String estado = 'En proceso',
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('Usuarios')
          .doc(userId)
          .collection('Pedidos')
          .add({
        'fecha': Timestamp.now(),
        'productos': productos,
        'total': total,
        'direccion': direccion,
        'estado': estado,
        'metodoPago': metodoPago,
        'tipoEmpaquetado': tipoEmpaquetado,
      });
    } catch (e) {
      print('Error al agregar pedido al historial: $e');
      throw Exception('No se pudo agregar el pedido al historial');
    }
  }

  // Validar stock antes de procesar pedido
  static Future<Map<String, dynamic>> validarStockCarrito(
      List<Map<String, dynamic>> items) async {
    List<Map<String, dynamic>> productosConProblemas = [];
    bool stockSuficiente = true;

    for (var item in items) {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('productos')
          .doc(item['id'])
          .get();

      if (docSnapshot.exists) {
        final stockActual = docSnapshot.data()?['stock'] ?? 0;
        final cantidadSolicitada = item['cantidad'] as int;

        if (stockActual < cantidadSolicitada) {
          stockSuficiente = false;
          productosConProblemas.add({
            'nombre': item['nombre'],
            'solicitado': cantidadSolicitada,
            'disponible': stockActual,
          });
        }
      }
    }

    return {
      'stockSuficiente': stockSuficiente,
      'productos': productosConProblemas,
    };
  }

  // Reducir stock inmediatamente al realizar compra
  static Future<void> reducirStockInmediato(
      List<Map<String, dynamic>> productos) async {
    final batch = FirebaseFirestore.instance.batch();

    for (var producto in productos) {
      final productoRef = FirebaseFirestore.instance
          .collection('productos')
          .doc(producto['id']);

      final snapshot = await productoRef.get();
      if (snapshot.exists) {
        final stockActual = snapshot.data()?['stock'] ?? 0;
        final cantidadVendida = producto['cantidad'] as int;
        final nuevoStock = stockActual - cantidadVendida;

        batch.update(productoRef, {'stock': nuevoStock >= 0 ? nuevoStock : 0});
      }
    }

    await batch.commit();
  }
}