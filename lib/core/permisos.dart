/// Códigos de la tabla `permisos` (ver supabase/migrations).
abstract final class Permisos {
  static const usuariosGestionar = 'usuarios.gestionar';
  static const rolesGestionar = 'roles.gestionar';
  static const clientesGestionar = 'clientes.gestionar';
  static const rutasGestionar = 'rutas.gestionar';
  static const ajustesGestionar = 'ajustes.gestionar';
  static const repartosVerTodos = 'repartos.ver_todos';
  static const repartosOperar = 'repartos.operar';
  static const incidenciasCrear = 'incidencias.crear';
  static const incidenciasGestionar = 'incidencias.gestionar';
}

/// Zona de la app a la que entra cada usuario. Se decide por permisos, no por
/// el nombre del rol, para que un rol nuevo (p. ej. "supervisor") funcione
/// solo con asignarle permisos en la base de datos.
enum AreaApp {
  admin('/admin', 'Administración'),
  repartidor('/repartidor', 'Reparto'),
  cliente('/cliente', 'Mis entregas');

  const AreaApp(this.ruta, this.titulo);

  final String ruta;
  final String titulo;

  /// Primera zona que encaja con los permisos, por orden de prioridad.
  static AreaApp? para(Set<String> permisos) {
    if (permisos.contains(Permisos.usuariosGestionar) ||
        permisos.contains(Permisos.repartosVerTodos)) {
      return admin;
    }
    if (permisos.contains(Permisos.repartosOperar)) return repartidor;
    if (permisos.contains(Permisos.incidenciasCrear)) return cliente;
    return null;
  }
}
