import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pantallas existentes
import 'screens/login_screen.dart';
import 'screens/catalogo_screen.dart';
import 'screens/carrito_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/tienda_screen.dart';
import 'screens/ofertas_screen.dart';
import 'screens/historial_screen.dart';

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

  final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
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

  void updateCartCount(int count) {
    cartCountNotifier.value = count;
  }

  void _abrirCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF3E0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: CarritoScreen(onCartChanged: updateCartCount),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [
      CatalogoScreen(onCartChanged: updateCartCount),
      OfertasScreen(onCartChanged: updateCartCount),
      TiendaScreen(carrito: carrito),
      const HistorialPedidosScreen(), // Agregar esta línea
      PerfilScreen(),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.storefront),
        label: 'Catálogo',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.local_fire_department),
        label: 'Ofertas',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.location_on),
        label: 'Tienda',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'Historial',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];

    // 🛒 Solo mostrar el carrito en Catálogo (índice 0) y Ofertas (índice 1)
    final bool mostrarCarrito = _selectedIndex == 0 || _selectedIndex == 1;

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
      // 🛒 BOTÓN FLOTANTE DEL CARRITO - Solo visible en Catálogo y Ofertas
      floatingActionButton: mostrarCarrito
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: ValueListenableBuilder<int>(
                valueListenable: cartCountNotifier,
                builder: (context, count, child) {
                  return FloatingActionButton(
                    onPressed: _abrirCarrito,
                    backgroundColor: const Color(0xFFFF8C42),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(Icons.shopping_cart, size: 28, color: Colors.white),
                        ),
                        if (count > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}