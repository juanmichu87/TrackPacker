import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/features/cliente/cliente_inicio_page.dart';
import 'package:track_pack/features/cliente/datos/cliente_repository.dart';
import 'package:track_pack/shared/avisos_cambios.dart';

final _bulto = BultoCliente(
  id: 'b1',
  codigo: '999000001',
  estado: 'entregado',
  tienda: 'Tienda Prueba',
  ruta: 'Ruta 1',
  cargadoEn: DateTime(2026, 10, 13, 16, 3),
  entregadoEn: DateTime(2026, 10, 13, 16, 4),
);

Future<void> _pantalla(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bultosClienteProvider.overrideWith((ref, _) async => [_bulto]),
        tiendasClienteProvider.overrideWith((ref) async => const []),
        incidenciasBultoProvider.overrideWith((ref, _) async => const []),
        avisosCambiosProvider.overrideWith((ref) {
          final avisos = AvisosCambios.sinTiempoReal();
          ref.onDispose(avisos.cerrar);
          return avisos;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: ClienteInicioPage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cliente en el ordenador: el detalle se abre en el panel derecho', (tester) async {
    await _pantalla(tester, const Size(1280, 800));
    expect(find.text('Selecciona un bulto para ver su detalle.'), findsOneWidget);

    await tester.tap(find.text('999000001'));
    await tester.pumpAndSettle();

    expect(find.text('Bulto 999000001'), findsOneWidget);
    expect(find.text('Reportar un problema'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('cliente en la tablet: el detalle es una ventana centrada', (tester) async {
    await _pantalla(tester, const Size(800, 1024));
    await tester.tap(find.text('999000001'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Bulto 999000001'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('cliente en el móvil: el detalle es un panel inferior', (tester) async {
    await _pantalla(tester, const Size(390, 844));
    expect(find.text('Selecciona un bulto para ver su detalle.'), findsNothing);
    await tester.tap(find.text('999000001'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Bulto 999000001'), findsOneWidget);
  });

  testWidgets('cliente: al buscar un código se busca en todas las fechas', (tester) async {
    FiltroBultos? ultimo;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bultosClienteProvider.overrideWith((ref, filtro) async {
            ultimo = filtro;
            return [_bulto];
          }),
          tiendasClienteProvider.overrideWith((ref) async => const []),
          incidenciasBultoProvider.overrideWith((ref, _) async => const []),
          avisosCambiosProvider.overrideWith((ref) {
            final avisos = AvisosCambios.sinTiempoReal();
            ref.onDispose(avisos.cerrar);
            return avisos;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: ClienteInicioPage())),
      ),
    );
    await tester.pumpAndSettle();
    // «Hoy»: desde el inicio del día
    expect(DateTime.now().difference(ultimo!.desde).inDays, 0);

    await tester.enterText(find.byType(TextField), '0002');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.textContaining('en todas las fechas'), findsOneWidget);
    expect(ultimo!.codigo, '0002');
    expect(DateTime.now().difference(ultimo!.desde).inDays, greaterThanOrEqualTo(14));
  });
}
