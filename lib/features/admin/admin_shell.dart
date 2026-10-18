import 'package:flutter/material.dart';

import '../../shared/shell_panel.dart';

export '../../shared/shell_panel.dart' show MenuLateral, SeccionPanel;

const seccionesAdmin = [
  SeccionPanel('/admin', 'Resumen', Icons.dashboard_outlined),
  SeccionPanel('/admin/repartos', 'Repartos', Icons.local_shipping_outlined),
  SeccionPanel('/admin/usuarios', 'Usuarios', Icons.people_outline),
  SeccionPanel('/admin/clientes', 'Clientes', Icons.business_outlined),
  SeccionPanel('/admin/rutas', 'Rutas', Icons.alt_route),
  SeccionPanel('/admin/tiendas', 'Tiendas', Icons.storefront_outlined),
  SeccionPanel('/admin/areas', 'Áreas', Icons.map_outlined),
  SeccionPanel('/admin/ajustes', 'Configuración', Icons.tune),
];

/// Sección activa del panel de administración.
int indiceSeccion(String ubicacion) => indiceDeSeccion(seccionesAdmin, ubicacion);

/// Panel de administración (estructura común de [ShellPanel]).
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.ubicacion, required this.child});

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context) => ShellPanel(
    area: 'Administración',
    secciones: seccionesAdmin,
    ubicacion: ubicacion,
    child: child,
  );
}
