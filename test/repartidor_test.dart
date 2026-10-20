import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/features/auth/sesion.dart';
import 'package:track_pack/features/repartidor/datos/repartidor_repository.dart';
import 'package:track_pack/features/repartidor/reparto_page.dart';

final _reparto = RepartoActivo(
  id: 'r1',
  estado: 'en_ruta',
  rutaId: 'ruta1',
  ruta: 'Ruta 1',
  iniciadoEn: DateTime(2026, 10, 13, 16),
  total: 2,
  entregados: 0,
  pendientes: 2,
);

class _SesionFalsa extends SesionNotifier {
  @override
  EstadoSesion build() => const SinSesion();
}

class _RepoFalso implements RepartidorRepository {
  @override
  Future<DatosReparto> datosReparto(RepartoActivo reparto) async => DatosReparto(
    reparto: reparto,
    tiendas: const [
      TiendaReparto(id: 't1', nombre: 'Tienda Uno', clienteId: 'c1'),
      TiendaReparto(id: 't2', nombre: 'Tienda Dos', clienteId: 'c1'),
    ],
    reglas: const [],
    bultos: [
      BultoReparto(id: 'b1', codigo: '999000001', estado: 'cargado', cargadoEn: DateTime(2026)),
      BultoReparto(id: 'b2', codigo: '999000002', estado: 'cargado', cargadoEn: DateTime(2026)),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pantalla(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repartidorRepositoryProvider.overrideWithValue(_RepoFalso()),
        sesionProvider.overrideWith(_SesionFalsa.new),
      ],
      child: MaterialApp(
        home: Scaffold(body: RepartoPage(reparto: _reparto)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('repartidor en el ordenador: la descarga se abre junto a las tiendas', (
    tester,
  ) async {
    await _pantalla(tester, const Size(1280, 800));
    expect(find.text('Elige una tienda para empezar a descargar.'), findsOneWidget);

    await tester.tap(find.text('Tienda Uno'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Misma pantalla: la lista de tiendas sigue a la vista y no hay otra ruta
    expect(find.text('Tienda Dos'), findsOneWidget);
    expect(find.text('Terminar tienda'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    // Si la etiqueta no se puede leer: lo que queda en el camión se entrega a mano
    expect(find.text('Quedan en el camión (2)'), findsOneWidget);
    expect(find.byTooltip('Leer desde foto'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Entregar').first);
    await tester.pumpAndSettle();
    expect(find.text('Entregar sin escanear'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // En la tienda se pueden recoger devoluciones
    await tester.tap(find.text('Devoluciones (0)'));
    await tester.pump();
    expect(find.textContaining('paquetes que la tienda te da para devolver'), findsOneWidget);
    expect(find.text('devoluciones aquí'), findsOneWidget);

    await tester.tap(find.text('Terminar tienda'));
    await tester.pump();
    expect(find.text('Elige una tienda para empezar a descargar.'), findsOneWidget);
  });

  testWidgets('repartidor en el móvil: la descarga se abre en otra pantalla', (tester) async {
    await _pantalla(tester, const Size(390, 844));
    expect(find.text('Elige una tienda para empezar a descargar.'), findsNothing);

    await tester.tap(find.text('Tienda Uno'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tienda Dos'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Tienda Uno'), findsOneWidget);
  });
}
