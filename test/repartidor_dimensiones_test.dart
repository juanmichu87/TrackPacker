// Comprueba la vista del repartidor en muchos tamaños de pantalla: que nada
// se desborde y que todos los botones y opciones de navegación estén dentro de
// la pantalla, sin nada encima que los tape (se pueden pulsar).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_pack/core/router.dart';
import 'package:track_pack/features/auth/sesion.dart';
import 'package:track_pack/features/repartidor/datos/repartidor_repository.dart';
import 'package:track_pack/features/repartidor/reparto_page.dart';
import 'package:track_pack/features/repartidor/seleccion_ruta.dart';
import 'package:track_pack/shared/aviso_esquema.dart';
import 'package:track_pack/shared/avisos_cambios.dart';
import 'package:track_pack/shared/shell_panel.dart';

const _tamanos = <String, Size>{
  'móvil pequeño': Size(320, 568),
  'móvil': Size(360, 640),
  'móvil grande': Size(412, 915),
  'móvil en horizontal': Size(800, 360),
  'tablet vertical': Size(768, 1024),
  'tablet horizontal': Size(1024, 768),
  'portátil': Size(1280, 720),
  'PC': Size(1366, 768),
  'monitor grande': Size(1920, 1080),
};

RepartoActivo _reparto(String estado) => RepartoActivo(
  id: 'r1',
  estado: estado,
  rutaId: 'ruta1',
  ruta: 'Ruta 7',
  salida: '14:00 PM (13:00)',
  iniciadoEn: DateTime(2026, 10, 20, 13),
  total: 18,
  entregados: 3,
  pendientes: 15,
);

class _SesionFalsa extends SesionNotifier {
  @override
  EstadoSesion build() => const SinSesion();
}

class _RepoFalso implements RepartidorRepository {
  @override
  Future<DatosReparto> datosReparto(RepartoActivo reparto) async => DatosReparto(
    reparto: reparto,
    // Nombres largos, como los reales, para forzar el texto
    tiendas: [
      for (final (i, n) in [
        'Aguilera NAVE (Cross)',
        'Pampanas EMBAJADORES',
        'Peralta HERMOSA',
        'Recambios ALHAMBRA',
        'Sansecar ALGETE',
        'Las ÁGUILAS',
      ].indexed)
        TiendaReparto(
          id: 't$i',
          nombre: n,
          clienteId: 'c1',
          direccion: 'Calle de prueba $i, Madrid',
        ),
    ],
    reglas: const [],
    bultos: [
      for (var i = 0; i < 18; i++)
        BultoReparto(
          id: 'b$i',
          codigo: '000213${700 + i}',
          estado: i < 3 ? 'entregado' : 'cargado',
          tiendaId: i < 3 ? 't0' : null,
          cargadoEn: DateTime(2026, 10, 20, 13, i),
          entregadoEn: i < 3 ? DateTime(2026, 10, 20, 14, i) : null,
        ),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _rutas = [
  for (var i = 1; i <= 9; i++)
    RutaRepartidor(
      id: 'ruta$i',
      nombre: i == 9 ? 'Ruta Apoyo' : 'Ruta $i',
      numTiendas: 3 + i % 4,
      numSalidas: 4,
      esMia: false,
      ocupadaPor: i == 2 ? 'Carlos Oliver' : null,
      ocupadaEstado: i == 2 ? 'en_ruta' : null,
    ),
];

/// Pinta la página dentro de la estructura real del repartidor (sin barra
/// superior; menú lateral en el ordenador).
Future<void> _pintar(WidgetTester tester, Size tamano, Widget pagina) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repartidorRepositoryProvider.overrideWithValue(_RepoFalso()),
        sesionProvider.overrideWith(_SesionFalsa.new),
        versionEsquemaProvider.overrideWith((ref) async => 99),
        rutasRepartidorProvider.overrideWith((ref) async => _rutas),
        avisosCambiosProvider.overrideWith((ref) {
          final avisos = AvisosCambios.sinTiempoReal();
          ref.onDispose(avisos.cerrar);
          return avisos;
        }),
      ],
      child: MaterialApp(
        home: ShellPanel(
          area: 'Reparto',
          secciones: seccionesRepartidor,
          ubicacion: '/repartidor',
          conBarraSuperior: false,
          child: pagina,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// El control está entero dentro de la pantalla y se puede pulsar (no hay
/// nada encima que lo tape).
void _accesible(WidgetTester tester, Finder control, Size tamano, String donde) {
  expect(control, findsWidgets, reason: '$donde: no aparece');
  final pantalla = Offset.zero & tamano;
  final rect = tester.getRect(control.first);
  expect(
    pantalla.contains(rect.topLeft) && pantalla.contains(rect.bottomRight - const Offset(1, 1)),
    isTrue,
    reason: '$donde: se sale de la pantalla ($rect)',
  );
  expect(control.first.hitTestable(), findsOneWidget, reason: '$donde: está tapado');
}

void main() {
  for (final MapEntry(key: nombre, value: tamano) in _tamanos.entries) {
    // En un teléfono girado el lector se pausa (aviso de girar el móvil)
    final esMovilHorizontal = tamano.width > tamano.height && tamano.height < 600;
    group('repartidor · $nombre (${tamano.width.toInt()}×${tamano.height.toInt()})', () {
      testWidgets('elegir ruta', (tester) async {
        await _pintar(tester, tamano, const SeleccionRuta());
        expect(tester.takeException(), isNull);
        _accesible(tester, find.text('Ruta 1'), tamano, 'primera ruta');
        _accesible(tester, find.byTooltip('Ajustes'), tamano, 'ajustes');
        _accesible(tester, find.byTooltip('Actualizar'), tamano, 'actualizar');
      });

      testWidgets('carga en la nave', (tester) async {
        await _pintar(tester, tamano, RepartoPage(reparto: _reparto('carga')));
        expect(tester.takeException(), isNull);
        _accesible(tester, find.textContaining('Terminar carga'), tamano, 'terminar carga');
        _accesible(tester, find.byType(TextField), tamano, 'campo del código');
        _accesible(tester, find.text('Usar'), tamano, 'botón usar');
        _accesible(tester, find.byTooltip('Leer desde foto'), tamano, 'leer desde foto');
        _accesible(tester, find.byTooltip('Ajustes'), tamano, 'ajustes');
        if (!esMovilHorizontal) {
          _accesible(tester, find.text('Escanear etiqueta'), tamano, 'escanear etiqueta');
        }
      });

      testWidgets('en ruta y entrega en tienda', (tester) async {
        await _pintar(tester, tamano, RepartoPage(reparto: _reparto('en_ruta')));
        expect(tester.takeException(), isNull);
        _accesible(tester, find.textContaining('Cerrar reparto'), tamano, 'cerrar reparto');
        _accesible(tester, find.text('Aguilera NAVE (Cross)'), tamano, 'primera tienda');
        _accesible(tester, find.byTooltip('Ajustes'), tamano, 'ajustes');

        await tester.tap(find.text('Aguilera NAVE (Cross)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        _accesible(tester, find.text('Terminar tienda'), tamano, 'terminar tienda');
        _accesible(tester, find.textContaining('Foto de entrega'), tamano, 'foto de entrega');
        _accesible(tester, find.textContaining('Entregar ('), tamano, 'modo entregar');
        _accesible(tester, find.textContaining('Devoluciones ('), tamano, 'modo devoluciones');
        _accesible(tester, find.text('Usar'), tamano, 'botón usar');
        _accesible(tester, find.byTooltip('Leer desde foto'), tamano, 'leer desde foto');
        if (!esMovilHorizontal) {
          _accesible(tester, find.text('Escanear etiqueta'), tamano, 'escanear etiqueta');
        }
        if (tamano.width < 1000) {
          // Pantalla propia: la flecha para volver a la lista de tiendas
          _accesible(tester, find.byType(BackButton), tamano, 'volver');
        }
      });
    });
  }
}
