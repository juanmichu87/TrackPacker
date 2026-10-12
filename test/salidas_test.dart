import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/core/salidas.dart';

Salida _salida(
  String nombre,
  String inicio,
  String fin, {
  Set<int> dias = const {1, 2, 3, 4, 5, 6, 7},
  bool activa = true,
}) => Salida(
  id: nombre,
  rutaId: 'r',
  nombre: nombre,
  inicio: minutosDeHora(inicio),
  fin: minutosDeHora(fin),
  dias: dias,
  activa: activa,
  tiendaIds: const {},
);

// 2026-10-05 es lunes
DateTime _lunes(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

void main() {
  final manana = _salida('Mañana', '06:00', '10:00');
  final tarde = _salida('Tarde', '16:00:00', '19:00:00');

  test('detecta la salida abierta según la hora', () {
    expect(salidaActual([manana, tarde], _lunes(7, 30))?.nombre, 'Mañana');
    expect(salidaActual([manana, tarde], _lunes(16))?.nombre, 'Tarde');
    expect(salidaActual([manana, tarde], _lunes(12)), isNull);
  });

  test('la hora de fin no está incluida', () {
    expect(manana.abiertaEn(_lunes(9, 59)), isTrue);
    expect(manana.abiertaEn(_lunes(10)), isFalse);
  });

  test('respeta los días de la semana y si está activa', () {
    final laborables = _salida('Lab', '06:00', '10:00', dias: {1, 2, 3, 4, 5});
    expect(laborables.abiertaEn(_lunes(7)), isTrue);
    expect(laborables.abiertaEn(DateTime(2026, 10, 10, 7)), isFalse); // sábado
    expect(_salida('X', '06:00', '10:00', activa: false).abiertaEn(_lunes(7)), isFalse);
  });

  test('franja que cruza la medianoche cuenta para el día en que empieza', () {
    final noche = _salida('Noche', '22:00', '02:00', dias: {6}); // sábado
    expect(noche.abiertaEn(DateTime(2026, 10, 10, 23)), isTrue); // sábado 23:00
    expect(noche.abiertaEn(DateTime(2026, 10, 11, 1)), isTrue); // domingo 01:00
    expect(noche.abiertaEn(DateTime(2026, 10, 11, 23)), isFalse); // domingo 23:00
    expect(noche.franja, '22:00–02:00');
  });

  test('si se solapan, gana la que empezó más tarde', () {
    final larga = _salida('Larga', '06:00', '14:00');
    final corta = _salida('Corta', '09:00', '11:00');
    expect(salidaActual([larga, corta], _lunes(9, 30))?.nombre, 'Corta');
  });

  test('interpreta horas escritas a mano (24 h)', () {
    expect(parsearHora('7'), 7 * 60);
    expect(parsearHora('07'), 7 * 60);
    expect(parsearHora('730'), 7 * 60 + 30);
    expect(parsearHora('0730'), 7 * 60 + 30);
    expect(parsearHora('7:30'), 7 * 60 + 30);
    expect(parsearHora('7.30'), 7 * 60 + 30);
    expect(parsearHora('7h30'), 7 * 60 + 30);
    expect(parsearHora('23:59'), 23 * 60 + 59);
    expect(parsearHora('0'), 0);
    expect(parsearHora('24:00'), isNull);
    expect(parsearHora('7:60'), isNull);
    expect(parsearHora('abc'), isNull);
    expect(parsearHora(''), isNull);
  });

  test('textos de días', () {
    expect(textoDias({1, 2, 3, 4, 5, 6, 7}), 'Todos los días');
    expect(textoDias({1, 2, 3, 4, 5}), 'L a V');
    expect(textoDias({1, 3, 5}), 'L X V');
  });
}
