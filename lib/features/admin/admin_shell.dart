import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/panel_scaffold.dart';

class SeccionAdmin {
  const SeccionAdmin(this.ruta, this.etiqueta, this.icono);

  final String ruta;
  final String etiqueta;
  final IconData icono;
}

const seccionesAdmin = [
  SeccionAdmin('/admin', 'Resumen', Icons.dashboard_outlined),
  SeccionAdmin('/admin/repartos', 'Repartos', Icons.local_shipping_outlined),
  SeccionAdmin('/admin/usuarios', 'Usuarios', Icons.people_outline),
  SeccionAdmin('/admin/clientes', 'Clientes', Icons.business_outlined),
  SeccionAdmin('/admin/rutas', 'Rutas', Icons.alt_route),
  SeccionAdmin('/admin/tiendas', 'Tiendas', Icons.storefront_outlined),
  SeccionAdmin('/admin/areas', 'Áreas', Icons.map_outlined),
  SeccionAdmin('/admin/ajustes', 'Ajustes', Icons.settings_outlined),
];

/// Sección activa: la de ruta más larga que encaja con la ubicación.
int indiceSeccion(String ubicacion) {
  var mejor = 0;
  for (final (i, s) in seccionesAdmin.indexed) {
    final encaja = ubicacion == s.ruta || ubicacion.startsWith('${s.ruta}/');
    if (encaja && s.ruta.length > seccionesAdmin[mejor].ruta.length) mejor = i;
  }
  return mejor;
}

/// Estructura del panel de administración: menú lateral en pantallas anchas y
/// menú desplegable en móvil.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.ubicacion, required this.child});

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final indice = indiceSeccion(ubicacion);
    final ancho = MediaQuery.sizeOf(context).width;
    final conRail = ancho >= 900;

    void ir(int i) => context.go(seccionesAdmin[i].ruta);

    return Scaffold(
      appBar: AppBar(
        title: Text('Administración · ${seccionesAdmin[indice].etiqueta}'),
        actions: const [AccionesUsuario()],
      ),
      drawer: conRail
          ? null
          : NavigationDrawer(
              selectedIndex: indice,
              onDestinationSelected: (i) {
                Navigator.pop(context);
                ir(i);
              },
              children: [
                const SizedBox(height: 16),
                for (final s in seccionesAdmin)
                  NavigationDrawerDestination(icon: Icon(s.icono), label: Text(s.etiqueta)),
              ],
            ),
      body: SafeArea(
        child: conRail
            ? Row(
                children: [
                  // Desplazable por si la ventana es baja
                  LayoutBuilder(
                    builder: (context, restricciones) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: restricciones.maxHeight),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            selectedIndex: indice,
                            onDestinationSelected: ir,
                            extended: ancho >= 1200,
                            labelType: ancho >= 1200 ? null : NavigationRailLabelType.all,
                            destinations: [
                              for (final s in seccionesAdmin)
                                NavigationRailDestination(
                                  icon: Icon(s.icono),
                                  label: Text(s.etiqueta),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              )
            : child,
      ),
    );
  }
}
