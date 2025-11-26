import 'package:cloud_firestore/cloud_firestore.dart';

class HorarioService {
  /// Verifica si la panadería está abierta en este momento
  static Future<Map<String, dynamic>> verificarHorarioAtencion() async {
    try {
      // Obtener configuración de horarios desde Firebase
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('horarios')
          .get();

      if (!doc.exists) {
        // Si no hay configuración, usar horarios por defecto
        return _verificarConHorariosPorDefecto();
      }

      final data = doc.data()!;
      return _verificarHorarioActual(data);
    } catch (e) {
      print('Error al verificar horario: $e');
      // En caso de error, usar horarios por defecto
      return _verificarConHorariosPorDefecto();
    }
  }

  /// Verifica con horarios por defecto (Lun-Sáb 7:00-20:00)
  static Map<String, dynamic> _verificarConHorariosPorDefecto() {
    final ahora = DateTime.now();
    final diaSemana = ahora.weekday; // 1=Lunes, 7=Domingo
    final horaActual = ahora.hour;
    final minutoActual = ahora.minute;

    // Domingo (7) está cerrado
    if (diaSemana == 7) {
      return {
        'abierto': false,
        'mensaje': 'Los pedidos solo están disponibles de lunes a sábado de 7:00 am a 8:00 pm.',
        'horario': 'Lunes a Sábado: 7:00 am - 8:00 pm\nDomingo: Cerrado',
      };
    }

    // Lunes a Sábado (1-6): 7:00 - 20:00
    final horaEnMinutos = horaActual * 60 + minutoActual;
    final apertura = 7 * 60; // 7:00 am
    final cierre = 20 * 60; // 8:00 pm

    if (horaEnMinutos < apertura) {
      return {
        'abierto': false,
        'mensaje': 'Aún no hemos abierto. Los pedidos están disponibles a partir de las 7:00 am.',
        'horario': 'Lunes a Sábado: 7:00 am - 8:00 pm',
      };
    }

    if (horaEnMinutos >= cierre) {
      return {
        'abierto': false,
        'mensaje': 'Ya cerramos por hoy. Los pedidos están disponibles de 7:00 am a 8:00 pm.',
        'horario': 'Lunes a Sábado: 7:00 am - 8:00 pm',
      };
    }

    // Está dentro del horario
    return {
      'abierto': true,
      'mensaje': 'Estamos abiertos',
      'horario': 'Lunes a Sábado: 7:00 am - 8:00 pm',
    };
  }

  /// Verifica horario actual con datos de Firebase
  static Map<String, dynamic> _verificarHorarioActual(Map<String, dynamic> config) {
    final ahora = DateTime.now();
    final diaSemana = ahora.weekday;
    final horaActual = ahora.hour;
    final minutoActual = ahora.minute;
    final horaEnMinutos = horaActual * 60 + minutoActual;

    // Nombres de días en español
    final nombresDias = {
      1: 'lunes',
      2: 'martes',
      3: 'miercoles',
      4: 'jueves',
      5: 'viernes',
      6: 'sabado',
      7: 'domingo',
    };

    final diaActual = nombresDias[diaSemana]!;
    final horarioDia = config[diaActual] as Map<String, dynamic>?;

    // Si no hay configuración para este día o está marcado como cerrado
    if (horarioDia == null || horarioDia['cerrado'] == true) {
      return {
        'abierto': false,
        'mensaje': 'Hoy no hay atención. Los pedidos solo están disponibles de lunes a sábado de 7:00 am a 8:00 pm.',
        'horario': _obtenerHorarioFormateado(config),
      };
    }

    // Obtener horas de apertura y cierre
    final apertura = _convertirHoraAMinutos(horarioDia['apertura'] ?? '07:00');
    final cierre = _convertirHoraAMinutos(horarioDia['cierre'] ?? '20:00');

    if (horaEnMinutos < apertura) {
      return {
        'abierto': false,
        'mensaje': 'Aún no hemos abierto. Los pedidos están disponibles a partir de las ${horarioDia['apertura']}.',
        'horario': _obtenerHorarioFormateado(config),
      };
    }

    if (horaEnMinutos >= cierre) {
      return {
        'abierto': false,
        'mensaje': 'Ya cerramos por hoy. Los pedidos están disponibles de ${horarioDia['apertura']} a ${horarioDia['cierre']}.',
        'horario': _obtenerHorarioFormateado(config),
      };
    }

    return {
      'abierto': true,
      'mensaje': 'Estamos abiertos',
      'horario': _obtenerHorarioFormateado(config),
    };
  }

  /// Convierte hora en formato "HH:mm" a minutos desde medianoche
  static int _convertirHoraAMinutos(String hora) {
    try {
      final partes = hora.split(':');
      final horas = int.parse(partes[0]);
      final minutos = int.parse(partes[1]);
      return horas * 60 + minutos;
    } catch (e) {
      return 0;
    }
  }

  /// Obtiene el horario formateado para mostrar al usuario
  static String _obtenerHorarioFormateado(Map<String, dynamic> config) {
    final dias = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
    final diasCapitalizados = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    
    String horarioTexto = '';
    
    for (int i = 0; i < dias.length; i++) {
      final dia = dias[i];
      final diaCapitalizado = diasCapitalizados[i];
      final horarioDia = config[dia] as Map<String, dynamic>?;
      
      if (horarioDia == null || horarioDia['cerrado'] == true) {
        horarioTexto += '$diaCapitalizado: Cerrado\n';
      } else {
        final apertura = horarioDia['apertura'] ?? '07:00';
        final cierre = horarioDia['cierre'] ?? '20:00';
        horarioTexto += '$diaCapitalizado: $apertura - $cierre\n';
      }
    }
    
    return horarioTexto.trim();
  }

  /// Obtiene el próximo horario de apertura
  static Future<String> obtenerProximaApertura() async {
    final ahora = DateTime.now();
    final diaSemana = ahora.weekday;
    
    // Si es domingo, el próximo día de apertura es lunes
    if (diaSemana == 7) {
      return 'Abrimos el lunes a las 7:00 am';
    }
    
    // Si ya cerró hoy, abre mañana (o lunes si es sábado)
    if (ahora.hour >= 20) {
      if (diaSemana == 6) {
        return 'Abrimos el lunes a las 7:00 am';
      } else {
        return 'Abrimos mañana a las 7:00 am';
      }
    }
    
    return 'Abrimos hoy a las 7:00 am';
  }
}