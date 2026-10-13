import 'dart:async';
import 'dart:js_interop';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

/// Vibración corta (lectura correcta) o larga (error o duplicado). Los
/// navegadores que no la admiten (p. ej. Safari en iPhone) la ignoran.
void vibrar({bool larga = false}) {
  try {
    web.window.navigator.vibrate((larga ? 400 : 80).toJS);
  } catch (_) {}
}

/// El navegador solo permite usar la cámara en páginas seguras (HTTPS o localhost).
bool get contextoSeguro => web.window.isSecureContext;

// --- Lectura de códigos en fotos con ZXing (zxing-wasm) -----------------------
// Es la misma librería que usa el escáner en directo cuando el navegador no
// trae lector propio, en la versión fijada por mobile_scanner.

const _urlZxing = 'https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.3/dist/iife/reader/index.js';

/// Formato de la base de datos → nombres de zxing-wasm.
const _formatosZxing = {
  'code128': ['Code128'],
  'code39': ['Code39'],
  'code93': ['Code93'],
  'codabar': ['Codabar'],
  'ean8': ['EAN8'],
  'ean13': ['EAN13'],
  'upca': ['UPCA'],
  'upce': ['UPCE'],
  'itf': ['ITF', 'ITF14'],
  'qr': ['QRCode'],
  'datamatrix': ['DataMatrix'],
  'pdf417': ['PDF417'],
  'aztec': ['Aztec'],
};

String? _formatoDesdeZxing(String nombre) {
  for (final MapEntry(:key, :value) in _formatosZxing.entries) {
    if (value.any(nombre.startsWith)) return key;
  }
  return null;
}

@JS('ZXingWASM')
external _ZXing? get _zxing;

extension type _ZXing(JSObject _) implements JSObject {
  external JSPromise<JSArray<_Resultado>> readBarcodes(JSAny imagen, _Opciones opciones);
}

extension type _Opciones._(JSObject _) implements JSObject {
  external factory _Opciones({
    JSArray<JSString> formats,
    bool tryHarder,
    bool tryRotate,
    bool tryInvert,
    bool tryDownscale,
  });
}

extension type _Resultado(JSObject _) implements JSObject {
  external String? get text;
  external String get format;
  external bool get isValid;
}

Future<void>? _cargando;

Future<void> _cargarZxing() {
  if (_zxing != null) return Future.value();
  return _cargando ??= () {
    final listo = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = _urlZxing
      ..crossOrigin = 'anonymous'
      ..async = true;
    script.onload = ((web.Event _) => listo.complete()).toJS;
    script.onerror = ((web.Event _) {
      _cargando = null;
      listo.completeError(
        StateError('No se pudo cargar el lector de códigos. Revisa la conexión a internet.'),
      );
    }).toJS;
    web.document.head!.append(script);
    return listo.future.timeout(const Duration(seconds: 30));
  }();
}

/// Busca códigos de barras en una foto. Devuelve los encontrados (puede haber
/// varios en una misma etiqueta) con su formato de la base de datos.
Future<List<({String contenido, String? formato})>> leerCodigosDeFoto(
  XFile foto, {
  List<String>? formatos,
}) async {
  await _cargarZxing();
  final zxing = _zxing!;
  final bytes = await foto.readAsBytes();
  final imagen = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: foto.mimeType ?? 'image/jpeg'),
  );
  final nombres = [for (final f in formatos ?? _formatosZxing.keys) ...?_formatosZxing[f]];
  final resultados = await zxing
      .readBarcodes(
        imagen,
        _Opciones(
          formats: [for (final n in nombres) n.toJS].toJS,
          tryHarder: true,
          tryRotate: true,
          tryInvert: true,
          tryDownscale: true,
        ),
      )
      .toDart;
  return [
    for (final r in resultados.toDart)
      if (r.isValid && (r.text?.trim().isNotEmpty ?? false))
        (contenido: r.text!.trim(), formato: _formatoDesdeZxing(r.format)),
  ];
}
