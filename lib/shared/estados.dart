import 'package:flutter/material.dart';

import '../core/tema.dart';
import 'ui.dart';

/// Texto y color de los estados de la base de datos (estado_bulto, estado_reparto).
const _bultos = {
  'cargado': ('Pendiente', ColoresEstado.informacion),
  'entregado': ('Entregado', ColoresEstado.correcto),
  'no_entregado': ('No entregado', ColoresEstado.peligro),
  'devolucion': ('Devolución', ColoresEstado.aviso),
};

const _repartos = {
  'carga': ('Cargando', ColoresEstado.informacion),
  'en_ruta': ('En ruta', ColoresEstado.aviso),
  'cerrado': ('Cerrado', ColoresEstado.correcto),
  'cerrado_forzoso': ('Cierre forzoso', ColoresEstado.peligro),
};

String textoEstadoBulto(String estado) => _bultos[estado]?.$1 ?? estado;
String textoEstadoReparto(String estado) => _repartos[estado]?.$1 ?? estado;

class EtiquetaBulto extends StatelessWidget {
  const EtiquetaBulto(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = _bultos[estado] ?? (estado, ColoresEstado.neutro);
    return Etiqueta(texto, color: color);
  }
}

class EtiquetaReparto extends StatelessWidget {
  const EtiquetaReparto(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = _repartos[estado] ?? (estado, ColoresEstado.neutro);
    return Etiqueta(texto, color: color);
  }
}
