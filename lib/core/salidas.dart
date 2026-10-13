/// Salida de una ruta: franja horaria fija y tiendas que se reparten en ella.
class Salida {
  const Salida({
    required this.id,
    required this.rutaId,
    required this.nombre,
    required this.inicio,
    required this.fin,
    required this.dias,
    required this.activa,
    required this.tiendaIds,
  });

  factory Salida.fromJson(Map<String, dynamic> j) => Salida(
    id: j['id'] as String,
    rutaId: j['ruta_id'] as String,
    nombre: j['nombre'] as String,
    inicio: minutosDeHora(j['hora_inicio'] as String),
    fin: minutosDeHora(j['hora_fin'] as String),
    dias: {for (final d in j['dias_semana'] as List) (d as num).toInt()},
    activa: j['activa'] as bool,
    tiendaIds: {
      for (final t in (j['salida_tiendas'] as List?) ?? const []) t['tienda_id'] as String,
    },
  );

  final String id;
  final String rutaId;
  final String nombre;

  /// Minutos desde medianoche (06:30 → 390).
  final int inicio;
  final int fin;

  /// 1 = lunes … 7 = domingo.
  final Set<int> dias;
  final bool activa;
  final Set<String> tiendaIds;

  bool get cruzaMedianoche => fin < inicio;

  String get franja => '${horaDeMinutos(inicio)}–${horaDeMinutos(fin)}';

  /// ¿Está abierta esta salida en ese momento (hora local)?
  bool abiertaEn(DateTime momento) {
    if (!activa) return false;
    final minuto = momento.hour * 60 + momento.minute;
    if (!cruzaMedianoche) {
      return dias.contains(momento.weekday) && minuto >= inicio && minuto < fin;
    }
    // Cruza la medianoche: la parte de antes cuenta para ese día y la de
    // después para el día anterior (la salida del sábado 22:00–02:00 sigue
    // abierta el domingo a la 01:00).
    if (minuto >= inicio) return dias.contains(momento.weekday);
    if (minuto < fin) return dias.contains(momento.subtract(const Duration(days: 1)).weekday);
    return false;
  }
}

/// Salida de la ruta abierta en ese momento (la que empezó más tarde si se
/// solapan varias). Null si ninguna está en su franja.
Salida? salidaActual(Iterable<Salida> salidas, DateTime momento) {
  final abiertas = salidas.where((s) => s.abiertaEn(momento)).toList();
  if (abiertas.isEmpty) return null;
  final minuto = momento.hour * 60 + momento.minute;
  int transcurrido(Salida s) => (minuto - s.inicio) % (24 * 60);
  abiertas.sort((a, b) => transcurrido(a).compareTo(transcurrido(b)));
  return abiertas.first;
}

/// Próxima salida que va a abrir (la que empieza antes a partir de ese
/// momento, mirando hasta una semana). Null si no hay salidas activas.
Salida? proximaSalida(Iterable<Salida> salidas, DateTime momento) {
  Salida? mejor;
  int? mejorEspera;
  final hoy = DateTime(momento.year, momento.month, momento.day);
  final minutoActual = momento.hour * 60 + momento.minute;
  for (final s in salidas.where((s) => s.activa)) {
    for (var dias = 0; dias < 8; dias++) {
      final dia = hoy.add(Duration(days: dias));
      if (!s.dias.contains(dia.weekday)) continue;
      final espera = dias * 24 * 60 + s.inicio - minutoActual;
      if (espera <= 0) continue;
      if (mejorEspera == null || espera < mejorEspera) {
        mejor = s;
        mejorEspera = espera;
      }
      break;
    }
  }
  return mejor;
}

/// "06:30:00" o "06:30" → 390
int minutosDeHora(String hora) {
  final partes = hora.split(':');
  return int.parse(partes[0]) * 60 + int.parse(partes[1]);
}

final _soloNumeros = RegExp(r'^\d{1,4}$');
final _conSeparador = RegExp(r'^(\d{1,2})\s*[:.,hH ]\s*(\d{1,2})$');

/// Interpreta lo que se escribe en un campo de hora (24 h). Devuelve los
/// minutos desde medianoche o null si no es una hora válida.
/// "7" → 07:00 · "730" → 07:30 · "0730" → 07:30 · "7:30", "7.30", "7h30" → 07:30
int? parsearHora(String texto) {
  final t = texto.trim();
  int? horas;
  int? minutos;
  if (_conSeparador.firstMatch(t) case final m?) {
    horas = int.parse(m[1]!);
    minutos = int.parse(m[2]!);
  } else if (_soloNumeros.hasMatch(t)) {
    if (t.length <= 2) {
      horas = int.parse(t);
      minutos = 0;
    } else {
      horas = int.parse(t.substring(0, t.length - 2));
      minutos = int.parse(t.substring(t.length - 2));
    }
  }
  if (horas == null || minutos == null || horas > 23 || minutos > 59) return null;
  return horas * 60 + minutos;
}

/// 390 → "06:30"
String horaDeMinutos(int minutos) =>
    '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}';

const nombresDias = {1: 'L', 2: 'M', 3: 'X', 4: 'J', 5: 'V', 6: 'S', 7: 'D'};

/// {1,2,3,4,5} → "L a V"; todos → "Todos los días"; otros → "L X V".
String textoDias(Set<int> dias) {
  if (dias.length == 7) return 'Todos los días';
  final ordenados = dias.toList()..sort();
  final seguidos = ordenados.length > 2 && ordenados.last - ordenados.first == ordenados.length - 1;
  if (seguidos) return '${nombresDias[ordenados.first]} a ${nombresDias[ordenados.last]}';
  return ordenados.map((d) => nombresDias[d]).join(' ');
}
