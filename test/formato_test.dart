import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/core/formato.dart';

void main() {
  test('la búsqueda ignora tildes y mayúsculas', () {
    final busqueda = normalizarBusqueda('  Aguilas ');
    expect(coincideBusqueda('Las ÁGUILAS', busqueda), isTrue);
    expect(coincideBusqueda('Pampanas EMBAJADORES', normalizarBusqueda('embajadóres')), isTrue);
    // Tilde como carácter combinado: «A» + U+0301
    expect(coincideBusqueda('Las ÁGUILAS', busqueda), isTrue);
    expect(coincideBusqueda(null, busqueda), isFalse);
    expect(coincideBusqueda('PINCHETE', busqueda), isFalse);
  });

  test('orden natural', () {
    final rutas = ['Ruta Apoyo', 'Ruta 10', 'Ruta 2', 'ruta 1'];
    rutas.sort(compararNatural);
    expect(rutas, ['ruta 1', 'Ruta 2', 'Ruta 10', 'Ruta Apoyo']);
  });
}
