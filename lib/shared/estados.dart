import 'package:flutter/material.dart';

import 'ui.dart';

/// Texto y color de los estados de la base de datos (estado_bulto, estado_reparto).
const _bultos = {
  'cargado': ('Pendiente', Colors.blue),
  'entregado': ('Entregado', Colors.green),
  'no_entregado': ('No entregado', Colors.red),
  'devolucion': ('Devolución', Colors.amber),
};

const _repartos = {
  'carga': ('Cargando', Colors.blue),
  'en_ruta': ('En ruta', Colors.orange),
  'cerrado': ('Cerrado', Colors.green),
  'cerrado_forzoso': ('Cierre forzoso', Colors.red),
};

String textoEstadoBulto(String estado) => _bultos[estado]?.$1 ?? estado;
String textoEstadoReparto(String estado) => _repartos[estado]?.$1 ?? estado;

class EtiquetaBulto extends StatelessWidget {
  const EtiquetaBulto(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = _bultos[estado] ?? (estado, Colors.grey);
    return Etiqueta(texto, color: color);
  }
}

class EtiquetaReparto extends StatelessWidget {
  const EtiquetaReparto(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = _repartos[estado] ?? (estado, Colors.grey);
    return Etiqueta(texto, color: color);
  }
}
