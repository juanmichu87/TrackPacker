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

  factory Perfil.fromJson(Map<String, dynamic> j) => Perfil(
    id: j['id'] as String,
    usuario: j['usuario'] as String,
    nombreCompleto: j['nombre_completo'] as String?,
    rol: j['rol'] as String,
    clienteId: j['cliente_id'] as String?,
    permisos: {for (final p in (j['permisos'] as List? ?? const [])) p as String},
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuario': usuario,
    'nombre_completo': nombreCompleto,
    'rol': rol,
    'cliente_id': clienteId,
    'permisos': permisos.toList()..sort(),
  };

  String get nombreVisible {
    final nombre = nombreCompleto?.trim() ?? '';
    return nombre.isEmpty ? usuario : nombre;
  }

  AreaApp? get area => AreaApp.para(permisos);

  bool puede(String permiso) => permisos.contains(permiso);
}
