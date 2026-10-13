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
