import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errores.dart';
import '../../../core/preferencias.dart';
import 'repartidor_repository.dart';

/// Qué hace cada lectura guardada en el móvil.
enum TipoLectura { carga, entrega, devolucion, quitarCarga, quitarDevolucion }

/// Lectura hecha en el móvil y pendiente de guardar en la base de datos.
class LecturaPendiente {
  const LecturaPendiente({
    required this.id,
    required this.tipo,
    required this.repartoId,
    required this.codigo,
    required this.escaneadoEn,
    this.tiendaId,
    this.formato,
  });

  factory LecturaPendiente.fromJson(Map<String, dynamic> j) => LecturaPendiente(
    id: j['id'] as String,
    tipo: TipoLectura.values.byName(j['tipo'] as String),
    repartoId: j['reparto'] as String,
    codigo: j['codigo'] as String,
    escaneadoEn: DateTime.parse(j['hora'] as String),
    tiendaId: j['tienda'] as String?,
    formato: j['formato'] as String?,
  );

  final String id;
  final TipoLectura tipo;
  final String repartoId;
  final String codigo;
  final DateTime escaneadoEn;
  final String? tiendaId;
  final String? formato;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'reparto': repartoId,
    'codigo': codigo,
    'hora': escaneadoEn.toUtc().toIso8601String(),
    'tienda': tiendaId,
    'formato': formato,
  };
}

/// Respuesta de la base de datos a una lectura ya enviada. `rechazo` explica
/// por qué no se guardó (null si se guardó).
class ResultadoLectura {
  const ResultadoLectura(this.lectura, [this.rechazo]);

  final LecturaPendiente lectura;
  final String? rechazo;
}

class EstadoCola {
  const EstadoCola({this.pendientes = const [], this.sinConexion = false});

  final List<LecturaPendiente> pendientes;

  /// El último envío falló por la conexión: se reintentará solo.
  final bool sinConexion;

  int pendientesDe(String repartoId) => pendientes.where((l) => l.repartoId == repartoId).length;
}

final colaLecturasProvider = NotifierProvider<ColaLecturas, EstadoCola>(ColaLecturas.new);

/// Las lecturas se guardan primero en el móvil y se envían en orden, en segundo
/// plano. Si no hay conexión se reintentan solas (también al volver a abrir la
/// app, porque quedan guardadas aunque se cierre o se apague el teléfono).
///
/// Reenviar una lectura que sí llegó (se perdió la respuesta) no la duplica:
/// la base de datos responde «duplicado» o «ya entregado» y se da por buena.
class ColaLecturas extends Notifier<EstadoCola> {
  static const _clave = 'lecturas_pendientes';

  /// Espera entre reintentos sin conexión, en segundos (el último se repite:
  /// mientras no haya conexión se prueba cada 10 s).
  static const esperas = [3, 5, 10];

  /// Tiempo máximo de cada envío: con mala señal la petición puede quedarse
  /// colgada mucho más.
  static const tiempoMaximo = Duration(seconds: 20);

  final _resultados = StreamController<ResultadoLectura>.broadcast(sync: true);
  SharedPreferences? _prefs;
  Future<void>? _envio;
  Timer? _reintento;
  int _fallos = 0;

  /// Lectura que se está enviando ahora (no se puede anular sin enviarla).
  String? _enCurso;

  /// Cada lectura enviada, en cuanto responde la base de datos.
  Stream<ResultadoLectura> get resultados => _resultados.stream;

  RepartidorRepository get _repo => ref.read(repartidorRepositoryProvider);

  @override
  EstadoCola build() {
    _prefs = ref.watch(preferenciasProvider);
    final vida = AppLifecycleListener(onResume: enviarAhora);
    ref.onDispose(() {
      vida.dispose();
      _reintento?.cancel();
    });
    final guardadas = _leer();
    if (guardadas.isNotEmpty) Future.microtask(enviarAhora);
    return EstadoCola(pendientes: guardadas);
  }

  List<LecturaPendiente> _leer() {
    try {
      final texto = _prefs?.getString(_clave);
      if (texto == null) return const [];
      return [
        for (final j in jsonDecode(texto) as List)
          LecturaPendiente.fromJson(Map<String, dynamic>.from(j as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  void _guardar(List<LecturaPendiente> pendientes, {bool? sinConexion}) {
    state = EstadoCola(pendientes: pendientes, sinConexion: sinConexion ?? state.sinConexion);
    try {
      if (pendientes.isEmpty) {
        _prefs?.remove(_clave);
      } else {
        _prefs?.setString(_clave, jsonEncode([for (final l in pendientes) l.toJson()]));
      }
    } catch (_) {
      // Sin almacén local: la cola sigue en memoria mientras la app esté abierta
    }
  }

  /// Guarda la lectura en el móvil y la envía en cuanto se pueda.
  void agregar({
    required TipoLectura tipo,
    required String repartoId,
    required String codigo,
    String? tiendaId,
    String? formato,
  }) {
    final lectura = LecturaPendiente(
      id: '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}',
      tipo: tipo,
      repartoId: repartoId,
      codigo: codigo,
      escaneadoEn: DateTime.now(),
      tiendaId: tiendaId,
      formato: formato,
    );
    _guardar([...state.pendientes, lectura]);
    unawaited(enviarAhora());
  }

  /// Quita un bulto leído por error. Si aún no se había enviado, basta con
  /// borrarlo del móvil; si ya se envió, se envía también la anulación.
  void quitar({required TipoLectura tipo, required String repartoId, required String codigo}) {
    final original = tipo == TipoLectura.quitarCarga ? TipoLectura.carga : TipoLectura.devolucion;
    final sinEnviar = state.pendientes.lastWhereOrNull(
      (l) =>
          l.tipo == original && l.repartoId == repartoId && l.codigo == codigo && l.id != _enCurso,
    );
    if (sinEnviar != null) {
      _guardar([
        for (final l in state.pendientes)
          if (l.id != sinEnviar.id) l,
      ]);
      return;
    }
    agregar(tipo: tipo, repartoId: repartoId, codigo: codigo);
  }

  /// Envía ya lo pendiente (p. ej. al terminar la carga). Termina cuando se ha
  /// enviado todo o cuando falla la conexión.
  Future<void> enviarAhora() => _envio ??= _enviarTodo().whenComplete(() => _envio = null);

  /// Borra lo pendiente (al cerrar sesión).
  void vaciar() {
    _reintento?.cancel();
    _guardar(const [], sinConexion: false);
  }

  Future<void> _enviarTodo() async {
    _reintento?.cancel();
    while (state.pendientes.isNotEmpty) {
      final lectura = state.pendientes.first;
      _enCurso = lectura.id;
      final String? rechazo;
      try {
        rechazo = _rechazo(lectura, await _enviar(lectura).timeout(tiempoMaximo));
      } on PostgrestException catch (e) {
        if (!_definitivo(e)) return _sinConexion();
        _terminada(lectura, mensajeError(e));
        continue;
      } catch (_) {
        // Sin conexión, tiempo agotado o sesión por renovar: se reintenta
        return _sinConexion();
      } finally {
        _enCurso = null;
      }
      _terminada(lectura, rechazo);
    }
  }

  void _terminada(LecturaPendiente lectura, String? rechazo) {
    _fallos = 0;
    // Primero se avisa (la pantalla la da por guardada) y luego se quita de la
    // cola, para que no desaparezca un instante de la lista
    _resultados.add(ResultadoLectura(lectura, rechazo));
    _guardar([
      for (final l in state.pendientes)
        if (l.id != lectura.id) l,
    ], sinConexion: false);
  }

  void _sinConexion() {
    final espera = esperas[min(_fallos, esperas.length - 1)];
    _fallos++;
    if (!state.sinConexion) _guardar(state.pendientes, sinConexion: true);
    _reintento?.cancel();
    _reintento = Timer(Duration(seconds: espera), () => unawaited(enviarAhora()));
  }

  /// Errores de nuestras funciones (reparto ya cerrado, sin permiso…): reenviar
  /// no sirve. El resto (servidor caído, sesión caducada) se reintenta.
  static bool _definitivo(PostgrestException e) =>
      const {'P0001', 'P0002', '42501', '22P02', '23503', '23514'}.contains(e.code);

  Future<String?> _enviar(LecturaPendiente l) async {
    switch (l.tipo) {
      case TipoLectura.carga:
        return _repo.escanearCarga(l.repartoId, l.codigo, l.formato, escaneadoEn: l.escaneadoEn);
      case TipoLectura.entrega:
        return _repo.escanearEntrega(
          l.repartoId,
          l.tiendaId!,
          l.codigo,
          escaneadoEn: l.escaneadoEn,
        );
      case TipoLectura.devolucion:
        return _repo.escanearDevolucion(
          l.repartoId,
          l.tiendaId!,
          l.codigo,
          l.formato,
          escaneadoEn: l.escaneadoEn,
        );
      case TipoLectura.quitarCarga:
        await _repo.quitarDeCarga(l.repartoId, l.codigo);
        return null;
      case TipoLectura.quitarDevolucion:
        await _repo.quitarDevolucion(l.repartoId, l.codigo);
        return null;
    }
  }

  /// En el móvil ya se comprobaron los duplicados del propio reparto, así que
  /// «duplicado» o «ya entregado» significan que la lectura ya había llegado.
  static String? _rechazo(LecturaPendiente l, String? respuesta) => switch ((l.tipo, respuesta)) {
    (TipoLectura.carga, 'duplicado_otro_reparto') =>
      '${l.codigo} ya lo cargó hoy otro reparto: se ha quitado de tu carga',
    (TipoLectura.entrega, 'no_cargado') =>
      '${l.codigo} no está en tu carga: no se ha marcado como entregado',
    (TipoLectura.devolucion, 'duplicado_otro_reparto') =>
      '${l.codigo} ya se registró hoy en otro reparto: se ha quitado de devoluciones',
    _ => null,
  };
}

/// Aplica a los bultos de la base de datos las lecturas aún no enviadas (o
/// recién enviadas, con `enviadas`), para mostrarlas en la pantalla.
List<BultoReparto> aplicarLecturas(
  List<BultoReparto> bultos,
  Iterable<LecturaPendiente> lecturas, {
  bool enviadas = false,
}) {
  final lista = [...bultos];
  for (final l in lecturas) {
    final i = lista.indexWhere((b) => b.codigo == l.codigo);
    switch (l.tipo) {
      case TipoLectura.carga || TipoLectura.devolucion:
        final nuevo = BultoReparto(
          id: i >= 0 ? lista[i].id : l.codigo,
          codigo: l.codigo,
          estado: l.tipo == TipoLectura.carga ? 'cargado' : 'devolucion',
          tiendaId: l.tiendaId,
          cargadoEn: l.escaneadoEn,
          sinEnviar: !enviadas,
        );
        if (i < 0) lista.insert(0, nuevo);
      case TipoLectura.entrega:
        if (i < 0 || lista[i].estado != 'cargado') continue;
        final b = lista.removeAt(i);
        lista.insert(
          0,
          BultoReparto(
            id: b.id,
            codigo: b.codigo,
            estado: 'entregado',
            tiendaId: l.tiendaId,
            cargadoEn: b.cargadoEn,
            entregadoEn: l.escaneadoEn,
            sinEnviar: !enviadas,
          ),
        );
      case TipoLectura.quitarCarga:
        lista.removeWhere((b) => b.codigo == l.codigo);
      case TipoLectura.quitarDevolucion:
        lista.removeWhere((b) => b.codigo == l.codigo && b.estado == 'devolucion');
    }
  }
  return lista;
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}
