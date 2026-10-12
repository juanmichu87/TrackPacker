import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/tema.dart';
import 'datos/admin_repository.dart';

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

/// Secciones fijas en la barra inferior del móvil; el resto va en «Más».
const _principalesMovil = 3;

/// Diseño de la navegación según el ancho de la pantalla.
enum DisenoNavegacion {
  /// Móvil (< 600 px): barra inferior con «Más».
  barraInferior,

  /// Tablet (600–1000 px): barra lateral de iconos con nombre.
  barraIconos,

  /// Escritorio (≥ 1000 px): columna fija con todas las secciones.
  menuLateral;

  static DisenoNavegacion para(double ancho) => ancho >= 1000
      ? menuLateral
      : ancho >= 600
      ? barraIconos
      : barraInferior;
}

/// Estructura del panel de administración: menú lateral fijo en el ordenador,
/// barra de iconos en tablet y barra inferior en el móvil.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.ubicacion, required this.child});

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final indice = indiceSeccion(ubicacion);
    final diseno = DisenoNavegacion.para(MediaQuery.sizeOf(context).width);
    final seccion = seccionesAdmin[indice];

    void ir(int i) => context.go(seccionesAdmin[i].ruta);

    final barraSuperior = AppBar(title: Text(seccion.etiqueta), actions: const [AccionesUsuario()]);

    switch (diseno) {
      case DisenoNavegacion.menuLateral:
        return Scaffold(
          body: Row(
            children: [
              MenuLateral(indice: indice, alElegir: ir),
              Expanded(
                child: Scaffold(
                  appBar: barraSuperior,
                  body: SafeArea(child: AvisoEsquema(child: child)),
                ),
              ),
            ],
          ),
        );

      case DisenoNavegacion.barraIconos:
        return Scaffold(
          appBar: barraSuperior,
          body: SafeArea(
            child: Row(
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
                          labelType: NavigationRailLabelType.all,
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
                Expanded(child: AvisoEsquema(child: child)),
              ],
            ),
          ),
        );

      case DisenoNavegacion.barraInferior:
        return Scaffold(
          appBar: barraSuperior,
          body: SafeArea(child: AvisoEsquema(child: child)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: indice < _principalesMovil ? indice : _principalesMovil,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) =>
                i < _principalesMovil ? ir(i) : _abrirMas(context, indice),
            destinations: [
              for (final s in seccionesAdmin.take(_principalesMovil))
                NavigationDestination(icon: Icon(s.icono), label: s.etiqueta),
              NavigationDestination(
                icon: Icon(indice < _principalesMovil ? Icons.menu : seccion.icono),
                label: indice < _principalesMovil ? 'Más' : seccion.etiqueta,
              ),
            ],
          ),
        );
    }
  }

  /// Hoja inferior con el resto de secciones.
  void _abrirMas(BuildContext context, int actual) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (i, s) in seccionesAdmin.indexed.skip(_principalesMovil))
              ListTile(
                leading: Icon(s.icono),
                title: Text(s.etiqueta),
                selected: i == actual,
                onTap: () {
                  Navigator.pop(hoja);
                  context.go(s.ruta);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Columna de navegación fija del escritorio: marca y todas las secciones, con
/// la actual resaltada en rojo.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key, required this.indice, required this.alElegir});

  final int indice;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;

    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: colores.surface,
        border: Border(right: BorderSide(color: colores.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: colores.primary, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TrackPack',
                          style: tema.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Administración',
                          style: tema.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final (i, s) in seccionesAdmin.indexed)
                    _ElementoMenu(
                      seccion: s,
                      seleccionado: i == indice,
                      alPulsar: () => alElegir(i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElementoMenu extends StatelessWidget {
  const _ElementoMenu({required this.seccion, required this.seleccionado, required this.alPulsar});

  final SeccionAdmin seccion;
  final bool seleccionado;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final color = seleccionado ? colores.onPrimary : colores.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: seleccionado ? colores.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: colores.primaryContainer,
          onTap: alPulsar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(seccion.icono, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    seccion.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso fijo si la base de datos tiene una versión anterior a la que necesita
/// la app (falta ejecutar alguna migración). Evita errores de carga confusos.
class AvisoEsquema extends ConsumerWidget {
  const AvisoEsquema({super.key, required this.child});

  /// La versión se guarda desde la migración 07; antes de ella vale 0.
  static int _primeraPendiente(int version) => version == 0 ? 7 : version + 1;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(versionEsquemaProvider).value;
    if (version == null || version >= Config.versionEsquema) return child;

    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: tema.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: ColoresEstado.peligro),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'La base de datos no está actualizada. Ejecuta en el SQL Editor de '
                    'Supabase las migraciones de supabase/migrations desde la '
                    '${_primeraPendiente(version).toString().padLeft(2, '0')} hasta la '
                    '${Config.versionEsquema.toString().padLeft(2, '0')}. '
                    'Hasta entonces algunas secciones no cargarán.',
                    style: TextStyle(color: tema.colorScheme.onErrorContainer),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(versionEsquemaProvider),
                  child: const Text('Comprobar'),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
