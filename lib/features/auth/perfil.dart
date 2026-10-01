import '../../core/permisos.dart';

/// Usuario con sesión iniciada: su fila de `usuarios` y los permisos de su rol.
class Perfil {
  const Perfil({
    required this.id,
    required this.usuario,
    required this.rol,
    required this.permisos,
    this.nombreCompleto,
    this.clienteId,
  });

  final String id;
  final String usuario;
  final String? nombreCompleto;
  final String rol;
  final String? clienteId;
  final Set<String> permisos;

  String get nombreVisible {
    final nombre = nombreCompleto?.trim() ?? '';
    return nombre.isEmpty ? usuario : nombre;
  }

  AreaApp? get area => AreaApp.para(permisos);

  bool puede(String permiso) => permisos.contains(permiso);
}
