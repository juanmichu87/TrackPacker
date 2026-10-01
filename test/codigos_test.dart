import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:track_pack/core/codigos.dart';

String? _id(ResultadoId r) => r is IdValido ? r.id : null;

void main() {
  group('extraerId', () {
    test('sin patrón, el código completo es el ID', () {
      expect(_id(extraerId(' 8412345678901 ')), '8412345678901');
    });

    test('rechaza códigos con letras si no hay patrón', () {
      expect(extraerId('ABC123'), isA<IdInvalido>());
    });

    test('aplica el patrón y se queda con el grupo', () {
      final r = extraerId('(00)123456789012345678', patron: r'\(00\)(\d{18})');
      expect(_id(r), '123456789012345678');
    });

    test('comprueba la longitud', () {
      expect(extraerId('12345', longitudMin: 6), isA<IdInvalido>());
      expect(extraerId('1234567', longitudMax: 6), isA<IdInvalido>());
      expect(_id(extraerId('123456', longitudMin: 6, longitudMax: 6)), '123456');
    });

    test('patrón inválido o que no encaja', () {
      expect(extraerId('123', patron: '('), isA<IdInvalido>());
      expect(extraerId('123', patron: r'X(\d+)'), isA<IdInvalido>());
    });
  });

  group('sugerirRegla', () {
    test('etiqueta solo numérica: sin patrón', () {
      final r = sugerirRegla('8412345678901')!;
      expect(r.patron, isNull);
      expect(r.longitud, 13);
    });

    test('GS1 con SSCC', () {
      final r = sugerirRegla('(00)123456789012345678(400)PEDIDO9')!;
      expect(r.id, '123456789012345678');
      expect(_id(extraerId('(00)123456789012345678(400)PEDIDO9', patron: r.patron)), r.id);
    });

    test('etiqueta mixta: el bloque numérico más largo', () {
      const leido = 'PKG-12-987654321-ES';
      final r = sugerirRegla(leido)!;
      expect(r.id, '987654321');
      expect(_id(extraerId(leido, patron: r.patron)), '987654321');
    });

    test('sin números no hay sugerencia', () {
      expect(sugerirRegla('ABC'), isNull);
    });
  });

  test('formatoDesdeEscaner', () {
    expect(formatoDesdeEscaner(BarcodeFormat.code128), 'code128');
    expect(formatoDesdeEscaner(BarcodeFormat.qrCode), 'qr');
    expect(formatoDesdeEscaner(BarcodeFormat.itf14), 'itf');
    expect(formatoDesdeEscaner(BarcodeFormat.maxiCode), isNull);
  });
}
