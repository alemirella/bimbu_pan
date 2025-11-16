import 'package:cloud_firestore/cloud_firestore.dart';

class PedidoService {
  static Future<void> agregarPedidoAlHistorial({
    required String userId,
    required List<Map<String, dynamic>> productos,
    required double total,
    required String direccion,
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
      });
    } catch (e) {
      print('Error al agregar pedido al historial: $e');
      throw Exception('No se pudo agregar el pedido al historial');
    }
  }
}