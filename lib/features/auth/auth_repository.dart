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

  Future<void> iniciarSesion({required String usuario, required String contrasena}) async {
    await _client.auth.signInWithPassword(email: emailDeUsuario(usuario), password: contrasena);
  }

  Future<void> cerrarSesion() => _client.auth.signOut();

  /// Perfil, permisos y versión del esquema en una sola llamada (migración 12).
  /// `perfil` es null si no tiene perfil o está desactivado.
  Future<({Perfil? perfil, int? versionEsquema})> cargarInicio(String userId) async {
    try {
      final datos = Map<String, dynamic>.from(await _client.rpc('mi_inicio') as Map);
      final fila = datos['perfil'] as Map<String, dynamic>?;
      return (
        perfil: fila == null || fila['activo'] != true ? null : Perfil.fromJson(fila),
        versionEsquema: (datos['version_esquema'] as num?)?.toInt(),
      );
    } on PostgrestException catch (e) {
      // Base de datos sin la migración 12: consulta anterior
      if (e.code != 'PGRST202') rethrow;
      return (perfil: await cargarPerfil(userId), versionEsquema: null);
    }
  }

  /// Perfil y permisos del usuario en una sola consulta (los permisos llegan
  /// embebidos a través de su rol). Null si no tiene perfil o está desactivado.
  Future<Perfil?> cargarPerfil(String userId) async {
    final fila = await _client
        .from('usuarios')
        .select(
          'id, usuario, nombre_completo, rol, cliente_id, activo, roles(rol_permisos(permiso))',
        )
        .eq('id', userId)
        .maybeSingle();
    if (fila == null || fila['activo'] != true) return null;

    final permisos = (fila['roles'] as Map?)?['rol_permisos'] as List? ?? const [];

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
