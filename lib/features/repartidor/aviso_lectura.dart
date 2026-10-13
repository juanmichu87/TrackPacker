import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/plataforma/plataforma.dart';
import '../../core/tema.dart';

enum TipoAviso { correcto, aviso, error }

/// Resultado del último escaneo, para mostrarlo bien visible.
class AvisoLectura {
  const AvisoLectura(this.texto, this.tipo);

  final String texto;
  final TipoAviso tipo;
}

/// Franja de color con el resultado del último escaneo. Vibra al cambiar
/// (corta si va bien, larga si hay problema).
class FranjaAviso extends StatelessWidget {
  const FranjaAviso(this.aviso, {super.key});

  final AvisoLectura? aviso;

  @override
  Widget build(BuildContext context) {
    final a = aviso;
    if (a == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: const Text(
          'Escanea un bulto o escribe su código',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    final (color, icono) = switch (a.tipo) {
      TipoAviso.correcto => (ColoresEstado.correcto, Icons.check_circle),
      TipoAviso.aviso => (ColoresEstado.aviso, Icons.warning_amber_rounded),
      TipoAviso.error => (ColoresEstado.peligro, Icons.error),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: color,
      child: Row(
        children: [
          Icon(icono, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              a.texto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vibración según el tipo de aviso.
void vibrarSegun(TipoAviso tipo) => vibrar(larga: tipo != TipoAviso.correcto);

/// Ejecuta los escaneos de uno en uno y en orden, aunque lleguen seguidos
/// (lector de pistola o varias lecturas rápidas).
class ColaEscaneos {
  Future<void> _ultima = Future.value();

  void encolar(Future<void> Function() tarea) {
    _ultima = _ultima.then((_) => tarea()).catchError((Object _) {});
  }
}
