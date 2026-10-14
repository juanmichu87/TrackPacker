import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../features/auth/sesion.dart';

/// Temas de los avisos de cambio (tabla `cambios`, migración 11).
abstract final class TemaCambio {
  static const repartos = 'repartos';
  static const bultos = 'bultos';
  static const incidencias = 'incidencias';

  /// Bultos e incidencias del cliente con la sesión abierta.
  static const cliente = 'cliente';

  /// Recarga de seguridad (cada minuto o al volver a la app): para todos.
  static const todos = '*';
}

/// Avisa a las pantallas cuando cambian sus datos:
/// · En tiempo real (Supabase Realtime) al cambiar algo en la base de datos.
/// · Cada [respaldo] como red de seguridad, por si se pierde la conexión.
/// · Al volver a la app tras tenerla en segundo plano.
/// Mientras la app no está a la vista no se avisa (ni se recarga nada).
class AvisosCambios {
  AvisosCambios(SupabaseClient db, {this.respaldo = const Duration(seconds: 60)}) {
    _canal = db
        .channel('cambios')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cambios',
          callback: (cambio) {
            final tema = cambio.newRecord['tema'];
            if (tema is String) {
              _recibido(tema.startsWith('cliente:') ? TemaCambio.cliente : tema);
            }
          },
        )
        .subscribe();
    _iniciarRespaldo();
  }

  /// Sin conexión a la base de datos (pruebas o sin sesión): solo el respaldo.
  AvisosCambios.sinTiempoReal({this.respaldo = const Duration(seconds: 60)}) {
    _iniciarRespaldo();
  }

  /// Ráfagas de avisos del mismo tema (p. ej. escaneos seguidos) se agrupan en
  /// una sola recarga como mucho cada este tiempo.
  static const agrupar = Duration(milliseconds: 1500);

  final Duration respaldo;
  final _salida = StreamController<String>.broadcast();
  final _pendientes = <String, Timer>{};
  RealtimeChannel? _canal;
  Timer? _temporizador;
  AppLifecycleListener? _ciclo;
  bool _visible = true;

  Stream<String> get avisos => _salida.stream;

  void _iniciarRespaldo() {
    _temporizador = Timer.periodic(respaldo, (_) {
      if (_visible) _emitir(TemaCambio.todos);
    });
    _ciclo = AppLifecycleListener(onStateChange: _alCambiarEstado);
  }

  void _alCambiarEstado(AppLifecycleState estado) {
    final antes = _visible;
    _visible = estado == AppLifecycleState.resumed || estado == AppLifecycleState.inactive;
    // Al volver: recarga para ponerse al día con lo que cambió mientras tanto
    if (_visible && !antes) _emitir(TemaCambio.todos);
  }

  void _recibido(String tema) {
    if (!_visible) return;
    if (_pendientes.containsKey(tema)) return;
    _pendientes[tema] = Timer(agrupar, () {
      _pendientes.remove(tema);
      _emitir(tema);
    });
  }

  void _emitir(String tema) {
    if (!_salida.isClosed) _salida.add(tema);
  }

  Future<void> cerrar() async {
    _temporizador?.cancel();
    _ciclo?.dispose();
    for (final t in _pendientes.values) {
      t.cancel();
    }
    if (_canal case final canal?) await canal.unsubscribe();
    await _salida.close();
  }
}

/// Un servicio por sesión: al cambiar de usuario se cierra el canal y se abre
/// otro con sus permisos.
final avisosCambiosProvider = Provider<AvisosCambios>((ref) {
  final sesion = ref.watch(sesionProvider);
  final avisos = sesion is SesionIniciada
      ? AvisosCambios(ref.watch(supabaseProvider))
      : AvisosCambios.sinTiempoReal();
  ref.onDispose(avisos.cerrar);
  return avisos;
});

/// Vuelve a pedir los datos de una pantalla cuando cambian (ver [AvisosCambios]).
/// `alCambiar` debe invalidar los providers de la pantalla; Riverpod mantiene
/// los datos actuales a la vista mientras llegan los nuevos (sin parpadeo).
class RecargaAutomatica extends ConsumerStatefulWidget {
  const RecargaAutomatica({
    super.key,
    required this.temas,
    required this.alCambiar,
    required this.child,
  });

  final Set<String> temas;
  final VoidCallback alCambiar;
  final Widget child;

  @override
  ConsumerState<RecargaAutomatica> createState() => _RecargaAutomaticaState();
}

class _RecargaAutomaticaState extends ConsumerState<RecargaAutomatica> {
  StreamSubscription<String>? _suscripcion;
  AvisosCambios? _avisos;

  void _suscribir(AvisosCambios avisos) {
    if (identical(avisos, _avisos)) return;
    _suscripcion?.cancel();
    _avisos = avisos;
    _suscripcion = avisos.avisos.listen((tema) {
      if (mounted && (tema == TemaCambio.todos || widget.temas.contains(tema))) {
        widget.alCambiar();
      }
    });
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _suscribir(ref.watch(avisosCambiosProvider));
    return widget.child;
  }
}
