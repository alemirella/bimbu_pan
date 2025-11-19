import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'carrito_screen.dart';

class CatalogoScreen extends StatefulWidget {
  final void Function(int) onCartChanged;
  const CatalogoScreen({super.key, required this.onCartChanged});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final Query productosRef =
      FirebaseFirestore.instance.collection('productos').orderBy('nombre');
  String _busqueda = '';
  Set<String> favoritos = {};
  bool _cargandoFavoritos = true;

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _cargandoFavoritos = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()?['favoritos'] != null) {
        setState(() {
          favoritos = Set<String>.from(doc.data()!['favoritos'] as List);
          _cargandoFavoritos = false;
        });
      } else {
        setState(() => _cargandoFavoritos = false);
      }
    } catch (e) {
      print('Error al cargar favoritos: $e');
      setState(() => _cargandoFavoritos = false);
    }
  }

  Future<void> _toggleFavorito(String productoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (favoritos.contains(productoId)) {
        favoritos.remove(productoId);
      } else {
        favoritos.add(productoId);
      }
    });

    // Guardar en Firestore
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .set({
        'favoritos': favoritos.toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error al guardar favorito: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar favorito')),
      );
    }
  }

  void _agregarAlCarrito(Map<String, dynamic> producto) {
    final stock = producto['stock'] ?? 0;
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay stock disponible para este producto')),
      );
      return;
    }

    SimpleCart.instance.addItem(producto);

    widget.onCartChanged(
      SimpleCart.instance.items.fold(0, (prev, item) => prev + (item['cantidad'] as int)),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${producto['nombre']} añadido al carrito'),
        duration: const Duration(milliseconds: 900),
      ),
    );

    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    if (_cargandoFavoritos) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            onChanged: (valor) {
              setState(() {
                _busqueda = valor.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: productosRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error al cargar los productos.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // 🔥 FILTRAR: Excluir productos en oferta
              var productos = snapshot.data!.docs.where((doc) {
                final data = doc.data()! as Map<String, dynamic>;
                
                // ⚠️ Si está en oferta, NO mostrarlo en catálogo
                final enOferta = data['en_oferta'] ?? false;
                if (enOferta == true) return false;
                
                // Filtro de búsqueda normal
                final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                return nombre.startsWith(_busqueda);
              }).toList();

              productos.sort((a, b) {
                final aFav = favoritos.contains(a.id);
                final bFav = favoritos.contains(b.id);
                if (aFav != bFav) {
                  return aFav ? -1 : 1;
                }
                final nombreA = (a.data()! as Map<String, dynamic>)['nombre']?.toString().toLowerCase() ?? '';
                final nombreB = (b.data()! as Map<String, dynamic>)['nombre']?.toString().toLowerCase() ?? '';
                return nombreA.compareTo(nombreB);
              });

              if (productos.isEmpty) {
                return const Center(child: Text('No se encontraron productos.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.60,
                ),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final doc = productos[index];
                  final data = doc.data()! as Map<String, dynamic>;

                  final imagen = convertirEnlaceDriveADirecto(data['imagen'] ?? '');
                  final descripcion = (data['descripcion'] ?? '').toString();
                  final stock = data['stock'] is int
                      ? data['stock'] as int
                      : int.tryParse((data['stock'] ?? '0').toString()) ?? 0;
                  int cantidadValida = 0;
                  final cantidadField = data['cantidad'];
                  if (cantidadField != null) {
                    if (cantidadField is int) {
                      cantidadValida = cantidadField;
                    } else if (cantidadField is double) {
                      cantidadValida = cantidadField.toInt();
                    } else if (cantidadField is String) {
                      cantidadValida = int.tryParse(cantidadField) ?? 0;
                    }
                  }

                  Color stockColor;
                  if (stock <= 0) {
                    stockColor = Colors.red;
                  } else if (stock < 10) {
                    stockColor = Colors.orange;
                  } else {
                    stockColor = Colors.green;
                  }

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  favoritos.contains(doc.id) ? Icons.favorite : Icons.favorite_border,
                                  color: favoritos.contains(doc.id) ? Colors.red : Colors.grey,
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _toggleFavorito(doc.id),
                              ),
                            ],
                          ),
                          Expanded(
                            flex: 10,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                color: Colors.white,
                                child: Image.network(
                                  imagen,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 70),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['nombre'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Cant: $cantidadValida',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            descripcion,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'S/ ${(data['precio'] ?? 0.0).toDouble().toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF8C42),
                                ),
                              ),
                              Text(
                                'Stock: $stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: stockColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: stock > 0
                                  ? () => _agregarAlCarrito({
                                        'id': doc.id,
                                        'nombre': data['nombre'],
                                        'precio': data['precio'],
                                        'cantidad': cantidadValida,
                                        'stock': stock,
                                        'imagen': data['imagen'],
                                      })
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: stock > 0 ? const Color.fromARGB(255, 202, 164, 74) : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                stock > 0 ? 'Agregar' : 'Sin stock',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}