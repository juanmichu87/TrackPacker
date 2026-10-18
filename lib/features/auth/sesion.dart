import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/preferencias.dart';
import '../../core/supabase.dart';
import 'auth_repository.dart';
import 'perfil.dart';

sealed class EstadoSesion {
  const EstadoSesion();
}

/// Hay sesión y se está cargando el perfil.
final class SesionCargando extends EstadoSesion {
  const SesionCargando();
}

/// Sin sesión. `aviso` explica por qué se cerró (p. ej. cuenta desactivada).
final class SinSesion extends EstadoSesion {
  const SinSesion({this.aviso});

  final String? aviso;
}

/// No se pudo cargar el perfil (p. ej. sin conexión).
final class ErrorSesion extends EstadoSesion {
  const ErrorSesion(this.mensaje);

  final String mensaje;
}

final class SesionIniciada extends EstadoSesion {
  const SesionIniciada(this.perfil, {this.versionEsquema});

  final Perfil perfil;

  /// Versión del esquema de la base de datos, si llegó con el perfil.
  final int? versionEsquema;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

final sesionProvider = NotifierProvider<SesionNotifier, EstadoSesion>(SesionNotifier.new);

/// Perfil guardado en el dispositivo: al abrir la app con la sesión ya iniciada
/// se entra al momento con él y se comprueba en segundo plano.
class _CachePerfil {
  const _CachePerfil(this._prefs);

  final SharedPreferences? _prefs;
  static const _clave = 'perfil_sesion';

  SesionIniciada? leer(String userId) {
    try {
      final texto = _prefs?.getString(_clave);
      if (texto == null) return null;
      final j = jsonDecode(texto) as Map<String, dynamic>;
      final perfil = Perfil.fromJson(j['perfil'] as Map<String, dynamic>);
      if (perfil.id != userId || perfil.area == null) return null;
      return SesionIniciada(perfil, versionEsquema: (j['version'] as num?)?.toInt());
    } catch (_) {
      return null;
    }
  }

  void guardar(SesionIniciada s) => _prefs?.setString(
    _clave,
    jsonEncode({'perfil': s.perfil.toJson(), 'version': s.versionEsquema}),
  );

  void borrar() => _prefs?.remove(_clave);
}

class SesionNotifier extends Notifier<EstadoSesion> {
  /// Usuario cuyo perfil está cargado o cargándose.
  String? _userId;

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  late _CachePerfil _cache;

  @override
  EstadoSesion build() {
    final repo = ref.watch(authRepositoryProvider);
    _cache = _CachePerfil(ref.watch(preferenciasProvider));
    final suscripcion = repo.cambios.listen((cambio) => _alCambiar(cambio.session));
    ref.onDispose(suscripcion.cancel);

    final sesion = repo.sesionActual;
    if (sesion == null) return const SinSesion();
    _userId = sesion.user.id;

    // Con perfil guardado se entra ya; se comprueba en segundo plano
    final guardado = _cache.leer(sesion.user.id);
    unawaited(_cargarPerfil(sesion.user.id, silencioso: guardado != null));
    return guardado ?? const SesionCargando();
  }

  Future<void> reintentar() async {
    final userId = _userId;
    if (userId == null) return;
    state = const SesionCargando();
    await _cargarPerfil(userId);
  }

  Future<void> cerrarSesion() {
    _cache.borrar();
    return _repo.cerrarSesion();
  }

  void _alCambiar(Session? sesion) {
    if (sesion == null) {
      _userId = null;
      _cache.borrar();
      // Si ya estamos sin sesión, se conserva el aviso que explica el cierre
      if (state is! SinSesion) state = const SinSesion();
      return;
    }
    // Refrescos de token y similares del mismo usuario no recargan el perfil
    if (sesion.user.id == _userId) return;
    _userId = sesion.user.id;
    state = const SesionCargando();
    unawaited(_cargarPerfil(sesion.user.id));
  }

  /// `silencioso`: ya se muestra el perfil guardado; si falla la conexión se
  /// sigue con él en vez de mostrar un error.
  Future<void> _cargarPerfil(String userId, {bool silencioso = false}) async {
    try {
      final (:perfil, :versionEsquema) = await _repo.cargarInicio(userId);
      if (_userId != userId) return; // la sesión cambió mientras cargaba

      if (perfil == null || perfil.area == null) {
        _cache.borrar();
        state = const SinSesion(aviso: 'Tu cuenta no tiene acceso. Contacta con el administrador.');
        await _repo.cerrarSesion();
        return;
      }
      final nuevo = SesionIniciada(perfil, versionEsquema: versionEsquema);
      _cache.guardar(nuevo);
      // Solo se cambia el estado si algo es distinto (evita redibujar todo)
      final actual = state;
      if (actual is SesionIniciada &&
          jsonEncode(actual.perfil.toJson()) == jsonEncode(perfil.toJson()) &&
          actual.versionEsquema == versionEsquema) {
        return;
      }
      state = nuevo;
    } catch (_) {
      if (_userId != userId || silencioso) return;
      state = const ErrorSesion(
        'No se pudo cargar tu perfil. Revisa la conexión e inténtalo de nuevo.',
      );
    }
  }
}
