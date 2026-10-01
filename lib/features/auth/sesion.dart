import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  const SesionIniciada(this.perfil);

  final Perfil perfil;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

final sesionProvider = NotifierProvider<SesionNotifier, EstadoSesion>(
  SesionNotifier.new,
);

class SesionNotifier extends Notifier<EstadoSesion> {
  /// Usuario cuyo perfil está cargado o cargándose.
  String? _userId;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  EstadoSesion build() {
    final repo = ref.watch(authRepositoryProvider);
    final suscripcion = repo.cambios.listen((cambio) => _alCambiar(cambio.session));
    ref.onDispose(suscripcion.cancel);

    final sesion = repo.sesionActual;
    if (sesion == null) return const SinSesion();
    _userId = sesion.user.id;
    unawaited(_cargarPerfil(sesion.user.id));
    return const SesionCargando();
  }

  Future<void> reintentar() async {
    final userId = _userId;
    if (userId == null) return;
    state = const SesionCargando();
    await _cargarPerfil(userId);
  }

  Future<void> cerrarSesion() => _repo.cerrarSesion();

  void _alCambiar(Session? sesion) {
    if (sesion == null) {
      _userId = null;
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

  Future<void> _cargarPerfil(String userId) async {
    try {
      final perfil = await _repo.cargarPerfil(userId);
      if (_userId != userId) return; // la sesión cambió mientras cargaba

      if (perfil == null || perfil.area == null) {
        state = const SinSesion(
          aviso: 'Tu cuenta no tiene acceso. Contacta con el administrador.',
        );
        await _repo.cerrarSesion();
        return;
      }
      state = SesionIniciada(perfil);
    } catch (_) {
      if (_userId != userId) return;
      state = const ErrorSesion(
        'No se pudo cargar tu perfil. Revisa la conexión e inténtalo de nuevo.',
      );
    }
  }
}
