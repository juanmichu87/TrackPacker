import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'aviso_esquema.dart';
import 'panel_scaffold.dart';
import 'responsive.dart';

/// Una sección del menú de un panel.
class SeccionPanel {
  const SeccionPanel(this.ruta, this.etiqueta, this.icono);

  final String ruta;
  final String etiqueta;
  final IconData icono;
}

/// Sección activa: la de ruta más larga que encaja con la ubicación (así las
/// páginas de detalle, como /admin/rutas/123, marcan su sección).
int indiceDeSeccion(List<SeccionPanel> secciones, String ubicacion) {
  var mejor = 0;
  for (final (i, s) in secciones.indexed) {
    final encaja = ubicacion == s.ruta || ubicacion.startsWith('${s.ruta}/');
    if (encaja && s.ruta.length > secciones[mejor].ruta.length) mejor = i;
  }
  return mejor;
}

/// Estructura común de los paneles de todos los roles, adaptada al tamaño:
/// - escritorio: menú lateral fijo con todas las secciones;
/// - tablet: barra lateral de iconos con nombre;
/// - móvil: barra inferior (las primeras secciones y «Más» con el resto).
/// Con una sola sección no se muestra navegación en móvil ni tablet.
/// Añadir una pantalla a un rol = añadir una [SeccionPanel] a su lista.
class ShellPanel extends StatelessWidget {
  const ShellPanel({
    super.key,
    required this.area,
    required this.secciones,
    required this.ubicacion,
    required this.child,
    this.principalesMovil = 3,
  });

  /// Nombre del área bajo la marca del menú (p. ej. «Administración»).
  final String area;
  final List<SeccionPanel> secciones;
  final String ubicacion;
  final Widget child;

  /// Secciones fijas en la barra inferior del móvil; el resto va en «Más».
  final int principalesMovil;

  @override
  Widget build(BuildContext context) {
    final indice = indiceDeSeccion(secciones, ubicacion);
    final seccion = secciones[indice];
    final conNavegacion = secciones.length > 1;
    // Contenido centrado y con ancho máximo en pantallas grandes
    final contenido = AvisoEsquema(child: ContenidoCentrado(child: child));

    void ir(int i) => context.go(secciones[i].ruta);

    final barraSuperior = AppBar(title: Text(seccion.etiqueta), actions: const [AccionesUsuario()]);

    switch (context.tamano) {
      case TamanoPantalla.escritorio:
        return Scaffold(
          body: Row(
            children: [
              MenuLateral(area: area, secciones: secciones, indice: indice, alElegir: ir),
              Expanded(
                child: Scaffold(
                  appBar: barraSuperior,
                  body: SafeArea(child: contenido),
                ),
              ),
            ],
          ),
        );

      case TamanoPantalla.tablet:
        return Scaffold(
          appBar: barraSuperior,
          body: SafeArea(
            child: !conNavegacion
                ? contenido
                : Row(
                    children: [
                      _BarraIconos(secciones: secciones, indice: indice, alElegir: ir),
                      const VerticalDivider(width: 1),
                      Expanded(child: contenido),
                    ],
                  ),
          ),
        );

      case TamanoPantalla.movil:
        return Scaffold(
          appBar: barraSuperior,
          body: SafeArea(child: contenido),
          bottomNavigationBar: !conNavegacion
              ? null
              : _BarraInferior(
                  secciones: secciones,
                  indice: indice,
                  principales: principalesMovil,
                  alElegir: ir,
                ),
        );
    }
  }
}

class _BarraIconos extends StatelessWidget {
  const _BarraIconos({required this.secciones, required this.indice, required this.alElegir});

  final List<SeccionPanel> secciones;
  final int indice;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    // Desplazable por si la ventana es baja
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: restricciones.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: indice,
              onDestinationSelected: alElegir,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final s in secciones)
                  NavigationRailDestination(icon: Icon(s.icono), label: Text(s.etiqueta)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.secciones,
    required this.indice,
    required this.principales,
    required this.alElegir,
  });

  final List<SeccionPanel> secciones;
  final int indice;
  final int principales;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    // Si caben todas (hasta 5), sin «Más»
    final todasCaben = secciones.length <= 5;
    final fijas = todasCaben ? secciones.length : principales;
    final seccion = secciones[indice];
    final enMas = indice >= fijas;

    return NavigationBar(
      selectedIndex: enMas ? fijas : indice,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) => i < fijas ? alElegir(i) : _abrirMas(context),
      destinations: [
        for (final s in secciones.take(fijas))
          NavigationDestination(icon: Icon(s.icono), label: s.etiqueta),
        if (!todasCaben)
          NavigationDestination(
            icon: Icon(enMas ? seccion.icono : Icons.menu),
            label: enMas ? seccion.etiqueta : 'Más',
          ),
      ],
    );
  }

  /// Hoja inferior con el resto de secciones.
  void _abrirMas(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (i, s) in secciones.indexed.skip(principales))
              ListTile(
                leading: Icon(s.icono),
                title: Text(s.etiqueta),
                selected: i == indice,
                onTap: () {
                  Navigator.pop(hoja);
                  alElegir(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Columna de navegación fija del escritorio: marca, área y todas las
/// secciones, con la actual resaltada en rojo.
class MenuLateral extends StatelessWidget {
  const MenuLateral({
    super.key,
    required this.area,
    required this.secciones,
    required this.indice,
    required this.alElegir,
  });

  final String area;
  final List<SeccionPanel> secciones;
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
                          area,
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
                  for (final (i, s) in secciones.indexed)
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

  final SeccionPanel seccion;
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
