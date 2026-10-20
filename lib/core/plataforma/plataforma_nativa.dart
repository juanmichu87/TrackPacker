import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../codigos.dart';

/// En Android/iOS no hay pantalla de carga en HTML.
void quitarPantallaCarga() {}

/// Vibración corta (lectura correcta) o larga (error o duplicado).
void vibrar({bool larga = false}) {
  larga ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
}

/// En Android/iOS la cámara no depende de HTTPS.
bool get contextoSeguro => true;

/// Busca códigos de barras en una foto con el lector nativo (ML Kit en
/// Android, Vision en iOS).
Future<List<({String contenido, String? formato})>> leerCodigosDeFoto(
  XFile foto, {
  List<String>? formatos,
}) async {
  final controlador = MobileScannerController(autoStart: false);
  try {
    final captura = await controlador.analyzeImage(
      foto.path,
      formats: [for (final f in formatos ?? formatosEscaner.keys) ?formatosEscaner[f]],
    );
    return [
      for (final b in captura?.barcodes ?? const <Barcode>[])
        if (b.rawValue?.trim().isNotEmpty ?? false)
          (contenido: b.rawValue!.trim(), formato: formatoDesdeEscaner(b.format)),
    ];
  } finally {
    await controlador.dispose();
  }
}
