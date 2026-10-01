import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/codigos.dart';
import '../core/formato.dart';

/// Resultado de leer un código: contenido y formato (null si se escribió a mano
/// o el escáner no lo identifica).
class LecturaCodigo {
  const LecturaCodigo(this.contenido, this.formato);

  final String contenido;
  final String? formato;

  String get nombreFormato =>
      formato == null ? 'Desconocido' : formatosCodigo[formato] ?? formato!;
}

/// Abre la cámara, lee un único código y lo devuelve. También permite
/// escribirlo a mano (útil sin cámara o con un lector de pistola).
Future<LecturaCodigo?> leerCodigo(BuildContext context, {String titulo = 'Escanear código'}) =>
    showDialog<LecturaCodigo>(context: context, builder: (_) => _DialogoEscaner(titulo: titulo));

class _DialogoEscaner extends StatefulWidget {
  const _DialogoEscaner({required this.titulo});

  final String titulo;

  @override
  State<_DialogoEscaner> createState() => _DialogoEscanerState();
}

class _DialogoEscanerState extends State<_DialogoEscaner> {
  final _controlador = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: formatosEscaner.values.toList(),
  );
  final _manual = TextEditingController();
  bool _leido = false;

  @override
  void dispose() {
    _controlador.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    final codigo = captura.barcodes.where((b) => b.rawValue?.isNotEmpty ?? false).firstOrNull;
    if (codigo == null) return;
    _leido = true;
    Navigator.pop(context, LecturaCodigo(codigo.rawValue!, formatoDesdeEscaner(codigo.format)));
  }

  void _usarManual() {
    final texto = _manual.text.trim();
    if (texto.isEmpty) return;
    Navigator.pop(context, LecturaCodigo(texto, null));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ColoredBox(
                  color: Colors.black,
                  child: MobileScanner(
                    controller: _controlador,
                    onDetect: _alDetectar,
                    errorBuilder: (context, error) => _ErrorCamara(error),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Apunta la cámara a la etiqueta.'),
            const SizedBox(height: 16),
            TextField(
              controller: _manual,
              decoration: const InputDecoration(
                labelText: 'O escribe / pega el código',
                helperText: 'Si escribes el código, el formato no se puede detectar',
                isDense: true,
              ),
              onSubmitted: (_) => _usarManual(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _usarManual, child: const Text('Usar código escrito')),
      ],
    );
  }
}

class _ErrorCamara extends StatelessWidget {
  const _ErrorCamara(this.error);

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final mensaje = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'No hay permiso para usar la cámara. Actívalo en el navegador o en los ajustes del móvil.',
      MobileScannerErrorCode.unsupported => 'Este dispositivo o navegador no permite usar la cámara.',
      _ => 'No se pudo abrir la cámara.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
