import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sesion.dart';

/// Pantalla de espera mientras se carga el perfil, o de error si falla.
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (sesion) {
            ErrorSesion(:final mensaje) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                Text(mensaje, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => ref.read(sesionProvider.notifier).reintentar(),
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: () => ref.read(sesionProvider.notifier).cerrarSesion(),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
            _ => const CircularProgressIndicator(),
          },
        ),
      ),
    );
  }
}
