import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistorialPedidosScreen extends StatelessWidget {
  const HistorialPedidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Debes iniciar sesión para ver tus pedidos.',
            style: TextStyle(fontSize: 16)),
        ),
      );
    }

    final pedidosRef = FirebaseFirestore.instance
        .collection('Usuarios')
        .doc(user.uid)
        .collection('Pedidos')
        .orderBy('fecha', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de pedidos'),
        backgroundColor: const Color(0xFFFF8C42),
        centerTitle: true,
      ),
      body: Container(
        color: const Color(0xFFFFF3E0),
        child: StreamBuilder<QuerySnapshot>(
          stream: pedidosRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No hay pedidos registrados',
                        style: TextStyle(fontSize: 16, color: Colors.brown)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final pedido = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                final fecha = (pedido['fecha'] as Timestamp).toDate();
                final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
                final estado = pedido['estado'] ?? 'En proceso';
                final total = (pedido['total'] ?? 0.0).toDouble();
                final productos = (pedido['productos'] as List?) ?? [];
                final direccion = (pedido['direccion'] as String?) ?? '';

                Color estadoColor;
                IconData estadoIcon;
                if (estado.toLowerCase() == 'entregado') {
                  estadoColor = Colors.green.shade600;
                  estadoIcon = Icons.check_circle;
                } else if (estado.toLowerCase().contains('cancelado')) {
                  estadoColor = Colors.red.shade700;
                  estadoIcon = Icons.cancel;
                } else {
                  estadoColor = Colors.orange.shade700;
                  estadoIcon = Icons.access_time;
                }

                return Card(
                  elevation: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: Colors.white,
                    collapsedBackgroundColor: const Color(0xFFFFF6E3),
                    leading: CircleAvatar(
                      backgroundColor: estadoColor.withOpacity(0.15),
                      child: Icon(estadoIcon, color: estadoColor, size: 25),
                    ),
                    title: Row(
                      children: [
                        Text(
                          'Pedido #${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF34333F),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: estadoColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            estado,
                            style: TextStyle(
                              color: estadoColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Fecha: ${formatoFecha.format(fecha)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10, right: 12, bottom: 2, top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final producto in productos)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            producto['nombre'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'x${producto['cantidad']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.brown,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'S/ ${(producto['precio'] ?? 0.0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF8C42),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (direccion.isNotEmpty) ...[
                              const Divider(),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                    color: Color(0xFFFF8C42), size: 18),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      direccion,
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.brown,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'S/ ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Color(0xFFFF8C42),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
