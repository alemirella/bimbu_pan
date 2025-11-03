import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class TiendaScreen extends StatefulWidget {
  final List<Map<String, dynamic>> carrito; // 👈 necesario para coincidir con main.dart

  const TiendaScreen({super.key, required this.carrito});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  LatLng? ubicacionUsuario;
  LatLng? ubicacionTienda;
  GoogleMapController? mapController;
  Set<Polyline> polylines = {};
  String mensajeError = '';

  final String apiKey = "AIzaSyBIZrptkE0IGakPhzMzMpq4PaW_gw_D1vk";

  @override
  void initState() {
    super.initState();
    obtenerUbicacionUsuario();
    obtenerUbicacionTienda();
  }

  // 🔹 Obtiene la ubicación actual del usuario
  Future<void> obtenerUbicacionUsuario() async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        setState(() => mensajeError = 'Por favor, activa el GPS de tu dispositivo');
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          setState(() => mensajeError = 'Permiso de ubicación denegado');
          return;
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        setState(() => mensajeError =
            'Permisos de ubicación denegados permanentemente. Actívalos en Configuración');
        return;
      }

      // 📍 Obtener ubicación precisa
      Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        forceAndroidLocationManager: false,
        timeLimit: const Duration(seconds: 25),
      );

      // Si la precisión es baja, reintenta una vez más
      if (posicion.accuracy > 20) {
        await Future.delayed(const Duration(seconds: 2));
        posicion = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );
      }

      setState(() {
        ubicacionUsuario = LatLng(posicion.latitude, posicion.longitude);
      });

      print('✅ Ubicación exacta del usuario:');
      print('   Latitud: ${posicion.latitude}');
      print('   Longitud: ${posicion.longitude}');
      print('   Precisión: ${posicion.accuracy}m');

      if (ubicacionTienda != null) obtenerRuta();
    } catch (e) {
      setState(() => mensajeError = 'Error al obtener tu ubicación: $e');
    }
  }

  // 🔹 Obtiene la ubicación de la tienda desde Firebase
  Future<void> obtenerUbicacionTienda() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('tienda').doc('principal').get();

      final data = snapshot.data();
      if (data != null && data['tienda'] != null) {
        final geo = data['tienda'] as GeoPoint;
        setState(() {
          ubicacionTienda = LatLng(geo.latitude, geo.longitude);
        });
        if (ubicacionUsuario != null) obtenerRuta();
      } else {
        setState(() => mensajeError = 'No se encontró la ubicación de la tienda');
      }
    } catch (e) {
      setState(() => mensajeError = 'Error al obtener ubicación de la tienda: $e');
    }
  }

  // 🔹 Obtiene la ruta entre usuario y tienda
  Future<void> obtenerRuta() async {
    if (ubicacionUsuario == null || ubicacionTienda == null) return;

    final origen = "${ubicacionUsuario!.latitude},${ubicacionUsuario!.longitude}";
    final destino = "${ubicacionTienda!.latitude},${ubicacionTienda!.longitude}";
    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/directions/json?origin=$origen&destination=$destino&key=$apiKey&mode=driving");

    try {
      final respuesta = await http.get(url);
      if (respuesta.statusCode == 200) {
        final data = json.decode(respuesta.body);

        if (data["status"] == "OK") {
          final puntos = data["routes"][0]["overview_polyline"]["points"];
          final ruta = decodePolyline(puntos);
          setState(() {
            polylines = {
              Polyline(
                polylineId: const PolylineId("ruta"),
                color: Colors.blue,
                width: 5,
                points: ruta,
              )
            };
          });
        } else {
          setState(() => mensajeError = 'Error en la API: ${data["status"]}');
        }
      } else {
        setState(() => mensajeError = 'Error HTTP: ${respuesta.statusCode}');
      }
    } catch (e) {
      setState(() => mensajeError = 'Error al obtener la ruta: $e');
    }
  }

  // 🔹 Decodifica los puntos codificados de la ruta
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return polyline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cómo llegar a la tienda")),
      body: mensajeError.isNotEmpty
          ? Center(child: Text(mensajeError, textAlign: TextAlign.center))
          : (ubicacionUsuario == null || ubicacionTienda == null)
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: ubicacionUsuario!,
                    zoom: 14,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('usuario'),
                      position: ubicacionUsuario!,
                      infoWindow: const InfoWindow(title: 'Tu ubicación'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure),
                    ),
                    Marker(
                      markerId: const MarkerId('tienda'),
                      position: ubicacionTienda!,
                      infoWindow: const InfoWindow(title: 'Panadería BIMBU'),
                    ),
                  },
                  polylines: polylines,
                  onMapCreated: (controller) => mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
    );
  }
}
