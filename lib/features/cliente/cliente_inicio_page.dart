import 'package:flutter/material.dart';

import '../../core/permisos.dart';
import '../../shared/panel_scaffold.dart';

class ClienteInicioPage extends StatelessWidget {
  const ClienteInicioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      titulo: AreaApp.cliente.titulo,
      child: const EnConstruccion(
        icono: Icons.storefront_outlined,
        texto: 'Bultos entregados por tienda e incidencias',
      ),
    );
  }
}
