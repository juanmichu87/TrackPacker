import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import 'perfil.dart';

/// Convierte lo que escribe el usuario en el email de Supabase Auth.
/// `Repartidor1` → `repartidor1@<dominio>`. Si ya es un email, se usa tal cual.
String emailDeUsuario(String entrada, {String dominio = Config.dominioUsuarios}) {
  final limpio = entrada.trim().toLowerCase();
  return limpio.contains('@') ? limpio : '$limpio@$dominio';
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get cambios => _client.auth.onAuthStateChange;

  Session? get sesionActual => _client.auth.currentSession;

  Future<void> iniciarSesion({
    required String usuario,
    required String contrasena,
  }) async {
    await _client.auth.signInWithPassword(
      email: emailDeUsuario(usuario),
      password: contrasena,
    );
  }

  Future<void> cerrarSesion() => _client.auth.signOut();

  /// Perfil y permisos del usuario. Null si no tiene perfil o está desactivado.
  Future<Perfil?> cargarPerfil(String userId) async {
    final fila = await _client
        .from('usuarios')
        .select('id, usuario, nombre_completo, rol, cliente_id, activo')
        .eq('id', userId)
        .maybeSingle();
    if (fila == null || fila['activo'] != true) return null;

    final permisos = await _client
        .from('rol_permisos')
        .select('permiso')
        .eq('rol', fila['rol'] as String);

    return Perfil(
      id: fila['id'] as String,
      usuario: fila['usuario'] as String,
      nombreCompleto: fila['nombre_completo'] as String?,
      rol: fila['rol'] as String,
      clienteId: fila['cliente_id'] as String?,
      permisos: {for (final p in permisos) p['permiso'] as String},
    );
  }
}
