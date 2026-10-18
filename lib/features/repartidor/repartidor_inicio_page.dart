import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/ui.dart';
import 'datos/repartidor_repository.dart';
import 'reparto_page.dart';
import 'seleccion_ruta.dart';

/// Inicio del repartidor: si tiene un reparto abierto lo retoma (por ejemplo,
/// tras cerrar la app); si no, elige ruta.
class RepartidorInicioPage extends ConsumerWidget {
  const RepartidorInicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Las rutas se piden a la vez que el reparto abierto (no después): si no
    // hay reparto, la lista ya está cargada o a punto al mostrarse.
    ref.listen(rutasRepartidorProvider, (_, _) {});
    return VistaAsync(
      valor: ref.watch(repartoAbiertoProvider),
      alReintentar: () => ref.invalidate(repartoAbiertoProvider),
      datos: (reparto) => reparto == null
          ? const SeleccionRuta()
          // La clave incluye el estado: al confirmar la carga se rehace la
          // pantalla y pasa a «en ruta».
          : RepartoPage(key: ValueKey('${reparto.id}-${reparto.estado}'), reparto: reparto),
    );
  }
}
