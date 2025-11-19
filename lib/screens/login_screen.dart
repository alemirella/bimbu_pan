import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  // Para registro
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _telefono = TextEditingController();

  bool _registrando = false;
  bool _cargando = false;

  // Función para traducir errores de Firebase al español
  String _traducirErrorFirebase(String codigo) {
    switch (codigo) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Este correo ya está registrado';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'operation-not-allowed':
        return 'Operación no permitida';
      case 'invalid-credential':
        return 'Credenciales inválidas';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet';
      default:
        return 'Error: $codigo';
    }
  }

  Future<void> _login() async {
    setState(() => _cargando = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_traducirErrorFirebase(e.code))),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _register() async {
    if (_nombre.text.trim().isEmpty ||
        _telefono.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa todos los campos de registro')),
        );
      }
      return;
    }

    // Validar que el teléfono tenga exactamente 9 dígitos
    if (_telefono.text.trim().length != 9) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El teléfono debe tener 9 dígitos')),
        );
      }
      return;
    }

    setState(() => _cargando = true);
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final user = result.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
          'admin': false,
          'email': user.email,
          'fechaRegistro': FieldValue.serverTimestamp(),
          'nombre': _nombre.text.trim(),
          'telefono': _telefono.text.trim(),
          'uid': user.uid,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro exitoso')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_traducirErrorFirebase(e.code))),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BIMBU - Login / Registro'),
        backgroundColor: const Color.fromARGB(255, 234, 155, 51),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ToggleButtons(
              isSelected: [_registrando == false, _registrando == true],
              onPressed: (i) {
                setState(() {
                  _registrando = i == 1;
                });
              },
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('Login')),
                Padding(padding: EdgeInsets.all(8), child: Text('Registro')),
              ],
            ),
            const SizedBox(height: 16),
            if (_registrando) ...[
              TextField(
                controller: _nombre,
                decoration:
                    const InputDecoration(labelText: 'Nombre', icon: Icon(Icons.person)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: const InputDecoration(
                  labelText: 'Teléfono (9 dígitos)',
                  icon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Email', icon: Icon(Icons.email)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Contraseña', icon: Icon(Icons.lock)),
            ),
            const SizedBox(height: 16),
            _cargando
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _registrando ? _register : _login,
                    icon: Icon(_registrando ? Icons.app_registration : Icons.login),
                    label:
                        Text(_registrando ? 'Registrarme' : 'Iniciar sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _registrando
                          ? const Color.fromARGB(255, 240, 129, 19)
                          : const Color.fromARGB(255, 255, 189, 66),
                    ),
                  ),
            const SizedBox(height: 16),
            const Text('BIMBU - Panadería',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}