import 'package:flutter/material.dart';

import '../../core/permisos.dart';
import '../../shared/panel_scaffold.dart';

class RepartidorInicioPage extends StatelessWidget {
  const RepartidorInicioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      titulo: AreaApp.repartidor.titulo,
      child: const EnConstruccion(
        icono: Icons.local_shipping_outlined,
        texto: 'Selección de ruta, carga y entrega de bultos',
      ),
    );
  }
}
