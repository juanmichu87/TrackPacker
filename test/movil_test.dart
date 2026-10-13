import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/features/admin/admin_shell.dart';
import 'package:track_pack/features/auth/sesion.dart';
import 'package:track_pack/shared/ui.dart';

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
  testWidgets('en el móvil el panel usa barra inferior con «Más»', (tester) async {
    await _pantalla(
      tester,
      const Size(390, 844),
      const AdminShell(ubicacion: '/admin/repartos', child: SizedBox()),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Más'), findsOneWidget);
  });

  testWidgets('una sección de «Más» aparece como activa en la barra', (tester) async {
    await _pantalla(
      tester,
      const Size(390, 844),
      const AdminShell(ubicacion: '/admin/tiendas/x', child: SizedBox()),
    );
    // Título de la barra superior y destino activo de la inferior
    expect(find.text('Tiendas'), findsNWidgets(2));
  });

  testWidgets('en escritorio usa el menú lateral con todas las secciones', (tester) async {
    await _pantalla(
      tester,
      const Size(1280, 800),
      const AdminShell(ubicacion: '/admin/rutas/x', child: SizedBox()),
    );
    expect(find.byType(MenuLateral), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    for (final s in seccionesAdmin) {
      expect(
        find.descendant(of: find.byType(MenuLateral), matching: find.text(s.etiqueta)),
        findsOneWidget,
      );
    }
  });

  testWidgets('en tablet usa la barra lateral de iconos', (tester) async {
    await _pantalla(
      tester,
      const Size(800, 900),
      const AdminShell(ubicacion: '/admin', child: SizedBox()),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(MenuLateral), findsNothing);
  });

  testWidgets('en el móvil los formularios ocupan toda la pantalla', (tester) async {
    await _pantalla(
      tester,
      const Size(390, 844),
      Scaffold(
        body: Column(
          children: [
            BarraLista(alBuscar: (_) {}, alNuevo: () {}, filtros: const [Text('Filtro')]),
            Expanded(
              child: DialogoFormulario(
                titulo: 'Nuevo cliente',
                alGuardar: () async {},
                campos: const [TextField()],
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
