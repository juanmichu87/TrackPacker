import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/shared/avisos_cambios.dart';

void main() {
  testWidgets('la red de seguridad recarga la pantalla cada cierto tiempo', (tester) async {
    var recargas = 0;
    late AvisosCambios avisos;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avisosCambiosProvider.overrideWith((ref) {
            avisos = AvisosCambios.sinTiempoReal(respaldo: const Duration(seconds: 60));
            ref.onDispose(avisos.cerrar);
            return avisos;
          }),
        ],
        child: MaterialApp(
          home: RecargaAutomatica(
            temas: const {TemaCambio.bultos},
            alCambiar: () => recargas++,
            child: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 59));
    expect(recargas, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(recargas, 1);
    await tester.pump(const Duration(seconds: 60));
    expect(recargas, 2);

    await tester.pumpWidget(const SizedBox());
  });
}
