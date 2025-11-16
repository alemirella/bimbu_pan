import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  User? user;
  Map<String, dynamic>? perfil;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).get();
    if (doc.exists) {
      setState(() {
        perfil = doc.data();
      });
    }
  }

  String _formatearFecha(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha no disponible';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text('No hay usuario autenticado.'));
    }
    final nombre = perfil?['nombre'] ?? user!.email ?? 'U';
    final telefono = perfil?['telefono'] ?? 'No registrado';
    final fechaRegistro = perfil?['fechaRegistro'] != null ? _formatearFecha(perfil!['fechaRegistro']) : 'Fecha no disponible';
    final esAdmin = perfil?['admin'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFFF8C42),
                child: Text(
                  nombre.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                nombre,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
              ),
              const SizedBox(height: 6),
              Text(
                user!.email ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.brown),
              ),
              const SizedBox(height: 40),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 5,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildPerfilItem(icon: Icons.phone, label: 'Teléfono', value: telefono),
                      const Divider(height: 30, thickness: 1, color: Color(0xFFF2D7A0)),
                      _buildPerfilItem(icon: Icons.calendar_today, label: 'Fecha de registro', value: fechaRegistro),
                      const Divider(height: 30, thickness: 1, color: Color(0xFFF2D7A0)),
                      _buildPerfilItem(icon: Icons.admin_panel_settings, label: 'Rol', value: esAdmin ? 'Administrador' : 'Usuario'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerfilItem({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF8C42), size: 30),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.brown, fontSize: 14)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF5D4037))),
            ],
          ),
        ),
      ],
    );
  }
}
