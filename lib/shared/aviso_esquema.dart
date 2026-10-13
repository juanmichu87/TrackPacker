import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/supabase.dart';
import '../core/tema.dart';

/// Versión del esquema de la base de datos (0 si es anterior a la migración 07,
/// que creó la columna). La pueden leer todos los usuarios activos.
final versionEsquemaProvider = FutureProvider<int>((ref) async {
  try {
    final fila = await ref
        .watch(supabaseProvider)
        .from('ajustes')
        .select('version_esquema')
        .single();
    return (fila['version_esquema'] as num).toInt();
  } on PostgrestException catch (e) {
    if (e.code == '42703') return 0; // columna inexistente
    rethrow;
  }
});

/// Aviso fijo si la base de datos tiene una versión anterior a la que necesita
/// la app (falta ejecutar alguna migración). Evita errores de carga confusos.
class AvisoEsquema extends ConsumerWidget {
  const AvisoEsquema({super.key, required this.child});

  final Widget child;

  /// La versión se guarda desde la migración 07; antes de ella vale 0.
  static int _primeraPendiente(int version) => version == 0 ? 7 : version + 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(versionEsquemaProvider).value;
    if (version == null || version >= Config.versionEsquema) return child;

    final tema = Theme.of(context);
    String dos(int n) => n.toString().padLeft(2, '0');
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
                    '${dos(_primeraPendiente(version))} hasta la ${dos(Config.versionEsquema)}. '
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
