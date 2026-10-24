import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/shared/escaner.dart';

void main() {
  final t0 = DateTime(2026, 10, 24, 9);
  DateTime en(int ms) => t0.add(Duration(milliseconds: ms));

  test('la misma etiqueta delante de la cámara no se repite, aunque pase el tiempo', () {
    final f = FiltroLecturas();
    expect(f.esNueva('A', en(0)), isTrue);
    // La cámara la sigue viendo varias veces por segundo durante 10 s
    for (var ms = 200; ms <= 10000; ms += 200) {
      expect(f.esNueva('A', en(ms)), isFalse, reason: 'a los $ms ms');
    }
  });

  test('vuelve a contar si deja de verse unos segundos', () {
    final f = FiltroLecturas();
    expect(f.esNueva('A', en(0)), isTrue);
    expect(f.esNueva('A', en(500)), isFalse);
    expect(f.esNueva('A', en(4000)), isTrue); // 3,5 s sin verla
  });

  test('otra etiqueta entre medias: la primera cuenta de nuevo (duplicado real)', () {
    final f = FiltroLecturas();
    expect(f.esNueva('A', en(0)), isTrue);
    expect(f.esNueva('B', en(800)), isTrue);
    expect(f.esNueva('A', en(1600)), isTrue);
  });
}
