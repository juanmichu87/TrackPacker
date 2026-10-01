import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/sesion.dart';

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
      body: SafeArea(child: child),
    );
  }
}

/// Nombre del usuario y botón de cerrar sesión, para la barra superior.
class AccionesUsuario extends ConsumerWidget {
  const AccionesUsuario({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    final nombre = sesion is SesionIniciada ? sesion.perfil.nombreVisible : '';
    final estrecho = MediaQuery.sizeOf(context).width < 600;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nombre.isNotEmpty && !estrecho)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(nombre, overflow: TextOverflow.ellipsis),
          ),
        IconButton(
          tooltip: nombre.isEmpty ? 'Cerrar sesión' : 'Cerrar sesión ($nombre)',
          icon: const Icon(Icons.logout),
          onPressed: () => ref.read(sesionProvider.notifier).cerrarSesion(),
        ),
      ],
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
