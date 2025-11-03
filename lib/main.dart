import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/login_screen.dart';
import 'screens/catalogo_screen.dart';
import 'screens/carrito_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/tienda_screen.dart'; // 👈 NUEVO: Importar la pantalla de ubicación
//import 'screens/CRUD_screen.dart';
//import 'screens/produccion_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BimbuApp());
}

class BimbuApp extends StatelessWidget {
  const BimbuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BIMBU - PANADERÍA',
      theme: ThemeData(
        primaryColor: const Color(0xFFFF8C42),
        scaffoldBackgroundColor: const Color(0xFFFFF3E0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF8C42),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8C42),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  bool _loading = true;

  // ValueNotifier para el contador de productos en el carrito
  final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
  
  // 👇 NUEVO: Lista para compartir el carrito entre pantallas
  final List<Map<String, dynamic>> carrito = [];

  @override
  void initState() {
    super.initState();
    _verificarRolUsuario();
  }

  Future<void> _verificarRolUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    setState(() {
      _isAdmin = doc.exists && doc.data()?['admin'] == true;
      _loading = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // Método público para actualizar el contador (desde CatalogoScreen)
  void updateCartCount(int count) {
    cartCountNotifier.value = count;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 👇 ACTUALIZADO: Agregamos TiendaScreen a las páginas
    final List<Widget> pages = _isAdmin
        ? [
            CatalogoScreen(onCartChanged: updateCartCount),
            CarritoScreen(onCartChanged: updateCartCount),
            TiendaScreen(carrito: carrito), // 👈 NUEVO
            //CRUDScreen(),
            //ProduccionScreen(),
            PerfilScreen(),
          ]
        : [
            CatalogoScreen(onCartChanged: updateCartCount),
            CarritoScreen(onCartChanged: updateCartCount),
            TiendaScreen(carrito: carrito), // 👈 NUEVO
            PerfilScreen(),
          ];

    // 👇 ACTUALIZADO: Agregamos el botón de ubicación
    final List<BottomNavigationBarItem> navItems = _isAdmin
        ? [
            const BottomNavigationBarItem(
                icon: Icon(Icons.storefront), label: 'Catálogo'),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder<int>(
                valueListenable: cartCountNotifier,
                builder: (context, count, child) {
                  return Stack(
                    children: [
                      const Icon(Icons.shopping_cart),
                      if (count > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                    ],
                  );
                },
              ),
              label: 'Carrito',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.location_on), label: 'Tienda'), // 👈 NUEVO
            //const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'CRUD'),
            //const BottomNavigationBarItem(icon: Icon(Icons.production_quantity_limits), label: 'Producción'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.person), label: 'Perfil'),
          ]
        : [
            const BottomNavigationBarItem(
                icon: Icon(Icons.storefront), label: 'Catálogo'),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder<int>(
                valueListenable: cartCountNotifier,
                builder: (context, count, child) {
                  return Stack(
                    children: [
                      const Icon(Icons.shopping_cart),
                      if (count > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                    ],
                  );
                },
              ),
              label: 'Carrito',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.location_on), label: 'Tienda'), // 👈 NUEVO
            const BottomNavigationBarItem(
                icon: Icon(Icons.person), label: 'Perfil'),
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BIMBU - PANADERÍA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFFF8C42),
        unselectedItemColor: Colors.brown.shade400,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }
}