import 'package:mobile_scanner/mobile_scanner.dart';

/// Formato de la base de datos (enum formato_codigo) → formato del escáner.
const formatosEscaner = <String, BarcodeFormat>{
  'code128': BarcodeFormat.code128,
  'code39': BarcodeFormat.code39,
  'code93': BarcodeFormat.code93,
  'codabar': BarcodeFormat.codabar,
  'ean8': BarcodeFormat.ean8,
  'ean13': BarcodeFormat.ean13,
  'upca': BarcodeFormat.upcA,
  'upce': BarcodeFormat.upcE,
  'itf': BarcodeFormat.itf14,
  'qr': BarcodeFormat.qrCode,
  'datamatrix': BarcodeFormat.dataMatrix,
  'pdf417': BarcodeFormat.pdf417,
  'aztec': BarcodeFormat.aztec,
};

/// Formato del escáner → formato de la base de datos (null si no lo usamos).
String? formatoDesdeEscaner(BarcodeFormat formato) => switch (formato) {
  BarcodeFormat.itf14 || BarcodeFormat.itf2of5 ||
  BarcodeFormat.itf2of5WithChecksum => 'itf',
  _ => formatosEscaner.entries.where((e) => e.value == formato).firstOrNull?.key,
};

sealed class ResultadoId {
  const ResultadoId();
}

final class IdValido extends ResultadoId {
  const IdValido(this.id);

  final String id;
}

final class IdInvalido extends ResultadoId {
  const IdInvalido(this.motivo);

  final String motivo;
}

final _soloDigitos = RegExp(r'^\d+$');

/// Obtiene el ID numérico de un bulto a partir del contenido leído, con la
/// configuración del cliente. Es la misma regla que aplicará el repartidor.
ResultadoId extraerId(
  String leido, {
  String? patron,
  int? longitudMin,
  int? longitudMax,
}) {
  var id = leido.trim();

  if (patron != null && patron.trim().isNotEmpty) {
    final RegExp regex;
    try {
      regex = RegExp(patron.trim());
    } on FormatException {
      return const IdInvalido('El patrón no es una expresión regular válida.');
    }
    final coincidencia = regex.firstMatch(id);
    if (coincidencia == null) {
      return const IdInvalido('El código leído no encaja con el patrón.');
    }
    id = (coincidencia.groupCount >= 1 ? coincidencia.group(1) : coincidencia.group(0)) ?? '';
  }

  if (!_soloDigitos.hasMatch(id)) {
    return IdInvalido('El ID debe ser solo números, pero se obtiene «$id».');
  }
  if (id.length > 64) return const IdInvalido('El ID tiene más de 64 dígitos.');
  if (longitudMin != null && id.length < longitudMin) {
    return IdInvalido('El ID tiene ${id.length} dígitos y el mínimo es $longitudMin.');
  }
  if (longitudMax != null && id.length > longitudMax) {
    return IdInvalido('El ID tiene ${id.length} dígitos y el máximo es $longitudMax.');
  }
  return IdValido(id);
}

/// Configuración propuesta a partir de una etiqueta de ejemplo.
class ReglaSugerida {
  const ReglaSugerida({required this.id, this.patron});

  /// ID que se extraería de la etiqueta de ejemplo.
  final String id;

  /// Null si la etiqueta ya es solo números.
  final String? patron;

  int get longitud => id.length;
}

/// Propone cómo extraer el ID de una etiqueta. Null si no contiene números.
ReglaSugerida? sugerirRegla(String leido) {
  final texto = leido.trim();
  if (_soloDigitos.hasMatch(texto)) return ReglaSugerida(id: texto);

  // GS1-128 con SSCC: (00) seguido de 18 dígitos
  final sscc = RegExp(r'\(00\)(\d{18})').firstMatch(texto);
  if (sscc != null) return ReglaSugerida(id: sscc.group(1)!, patron: r'\(00\)(\d{18})');

  // En otro caso, el bloque de números más largo
  final bloques = RegExp(r'\d+').allMatches(texto).map((m) => m.group(0)!).toList();
  if (bloques.isEmpty) return null;
  final mayor = bloques.reduce((a, b) => b.length > a.length ? b : a);
  return ReglaSugerida(id: mayor, patron: '(?<!\\d)(\\d{${mayor.length}})(?!\\d)');
}
