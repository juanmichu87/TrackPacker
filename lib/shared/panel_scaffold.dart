import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/sesion.dart';
import 'aviso_esquema.dart';
import 'responsive.dart';
import 'ui.dart';

/// Estructura común de las zonas con sesión: barra superior con el usuario y
/// botón de cerrar sesión.
class PanelScaffold extends StatelessWidget {
  const PanelScaffold({super.key, required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo), actions: const [AccionesUsuario()]),
      body: SafeArea(child: AvisoEsquema(child: child)),
    );
  }
}

/// Nombre del usuario y botón de ajustes (con cerrar sesión), para la barra superior.
class AccionesUsuario extends ConsumerWidget {
  const AccionesUsuario({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    final nombre = sesion is SesionIniciada ? sesion.perfil.nombreVisible : '';
    final estrecho = context.esPantallaMovil;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nombre.isNotEmpty && !estrecho)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(nombre, overflow: TextOverflow.ellipsis),
          ),
        // Cerrar sesión va dentro de Ajustes (con confirmación) en todos los roles
        const BotonAjustes(),
      ],
    );
  }
}

/// Botón «Ajustes» (⚙) de todos los roles: despliega justo debajo un menú
/// con el usuario y «Cerrar sesión», que pide confirmación. Así el cierre de
/// sesión no está a un toque mientras se trabaja.
class BotonAjustes extends ConsumerWidget {
  const BotonAjustes({super.key});

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    if (!await confirmar(
      context,
      titulo: 'Cerrar sesión',
      mensaje: '¿Seguro que quieres cerrar sesión?',
      accion: 'Cerrar sesión',
      peligroso: true,
    )) {
      return;
    }
    await ref.read(sesionProvider.notifier).cerrarSesion();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final sesion = ref.watch(sesionProvider);
    final perfil = sesion is SesionIniciada ? sesion.perfil : null;

    return MenuAnchor(
      menuChildren: [
        if (perfil != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                const CircleAvatar(radius: 16, child: Icon(Icons.person_outline, size: 18)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(perfil.nombreVisible, style: tema.textTheme.titleSmall),
                    Text('Usuario: ${perfil.usuario}', style: tema.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        MenuItemButton(
          style: MenuItemButton.styleFrom(
            foregroundColor: tema.colorScheme.error,
            minimumSize: const Size(220, 48),
          ),
          leadingIcon: Icon(Icons.logout, color: tema.colorScheme.error),
          onPressed: () => _cerrarSesion(context, ref),
          child: const Text('Cerrar sesión'),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        tooltip: 'Ajustes',
        isSelected: menu.isOpen,
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// Marcador de posición para las pantallas que aún no se han desarrollado.
class EnConstruccion extends StatelessWidget {
  const EnConstruccion({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: tema.colorScheme.primary),
            const SizedBox(height: 16),
            Text(texto, textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('En construcción', style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
