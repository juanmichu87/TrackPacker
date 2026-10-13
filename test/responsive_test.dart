import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/core/router.dart';
import 'package:track_pack/features/auth/sesion.dart';
import 'package:track_pack/shared/responsive.dart';
import 'package:track_pack/shared/shell_panel.dart';

class _SesionFalsa extends SesionNotifier {
  @override
  EstadoSesion build() => const SinSesion();
}

Future<void> _pantalla(WidgetTester tester, Size tamano, Widget hijo) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sesionProvider.overrideWith(_SesionFalsa.new)],
      child: MaterialApp(home: hijo),
    ),
  );
}

void main() {
  test('puntos de corte únicos', () {
    expect(TamanoPantalla.para(375), TamanoPantalla.movil);
    expect(TamanoPantalla.para(599), TamanoPantalla.movil);
    expect(TamanoPantalla.para(600), TamanoPantalla.tablet);
    expect(TamanoPantalla.para(999), TamanoPantalla.tablet);
    expect(TamanoPantalla.para(1000), TamanoPantalla.escritorio);
  });

  test('la rejilla calcula las columnas que caben', () {
    // Resumen: tarjetas de 150 px mínimo
    expect(RejillaAdaptable.columnasPara(343, 150, 6, 12), 2); // móvil
    expect(RejillaAdaptable.columnasPara(1200, 150, 6, 12), 6); // escritorio (tope 6)
    // Rutas del repartidor: 340 px mínimo, máximo 3
    expect(RejillaAdaptable.columnasPara(343, 340, 3, 12), 1);
    expect(RejillaAdaptable.columnasPara(760, 340, 3, 12), 2);
    expect(RejillaAdaptable.columnasPara(1200, 340, 3, 12), 3);
    expect(RejillaAdaptable.columnasPara(100, 340, 3, 12), 1); // nunca menos de 1
  });

  testWidgets('repartidor en el móvil: sin barra de navegación (una sola sección)', (tester) async {
    await _pantalla(
      tester,
      const Size(390, 844),
      const ShellPanel(
        area: 'Reparto',
        secciones: seccionesRepartidor,
        ubicacion: '/repartidor',
        child: SizedBox(),
      ),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Mi reparto'), findsOneWidget); // título de la barra superior
  });

  testWidgets('cliente en escritorio: menú lateral con su sección marcada', (tester) async {
    await _pantalla(
      tester,
      const Size(1280, 800),
      const ShellPanel(
        area: 'Mis entregas',
        secciones: seccionesCliente,
        ubicacion: '/cliente',
        child: SizedBox(),
      ),
    );
    expect(find.byType(MenuLateral), findsOneWidget);
    expect(find.descendant(of: find.byType(MenuLateral), matching: find.text('Mis entregas')),
        findsNWidgets(2)); // nombre del área y sección
  });

  testWidgets('cliente en tablet: sin barra lateral (una sola sección)', (tester) async {
    await _pantalla(
      tester,
      const Size(800, 1000),
      const ShellPanel(
        area: 'Mis entregas',
        secciones: seccionesCliente,
        ubicacion: '/cliente',
        child: SizedBox(),
      ),
    );
    expect(find.byType(NavigationRail), findsNothing);
  });
}
