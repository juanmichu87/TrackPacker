import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_pack/core/preferencias.dart';
import 'package:track_pack/features/auth/sesion.dart';
import 'package:track_pack/features/repartidor/datos/cola_lecturas.dart';
import 'package:track_pack/features/repartidor/datos/repartidor_repository.dart';
import 'package:track_pack/features/repartidor/reparto_page.dart';

/// Base de datos falsa: sin conexión mientras `conectado` sea false.
class _RepoFalso implements RepartidorRepository {
  bool conectado = false;
  final enviadas = <String>[];
  final respuestas = <String, String>{};

  Future<String> _rpc(String que, String codigo) async {
    if (!conectado) throw Exception('sin conexión');
    enviadas.add('$que $codigo');
    return respuestas[codigo] ?? 'ok';
  }

  @override
  Future<String> escanearCarga(
    String repartoId,
    String codigo,
    String? formato, {
    DateTime? escaneadoEn,
  }) => _rpc('carga', codigo);

  @override
  Future<String> escanearEntrega(
    String repartoId,
    String tiendaId,
    String codigo, {
    DateTime? escaneadoEn,
  }) => _rpc('entrega', codigo);

  @override
  Future<void> quitarDeCarga(String repartoId, String codigo) => _rpc('quitar', codigo);

  @override
  Future<DatosReparto> datosReparto(RepartoActivo reparto) async => DatosReparto(
    reparto: reparto,
    tiendas: const [TiendaReparto(id: 't1', nombre: 'Tienda Uno', clienteId: 'c1')],
    reglas: const [],
    bultos: const [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(ProviderContainer, _RepoFalso)> _contenedor({_RepoFalso? repo}) async {
  final r = repo ?? _RepoFalso();
  final c = ProviderContainer(
    overrides: [
      repartidorRepositoryProvider.overrideWithValue(r),
      preferenciasProvider.overrideWithValue(await SharedPreferences.getInstance()),
    ],
    retry: (_, _) => null,
  );
  return (c, r);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sin conexión la lectura se guarda en el móvil y se envía al volver', () async {
    final (c, repo) = await _contenedor();
    final cola = c.read(colaLecturasProvider.notifier);

    cola.agregar(tipo: TipoLectura.carga, repartoId: 'r1', codigo: '111');
    await cola.enviarAhora();
    expect(c.read(colaLecturasProvider).pendientes, hasLength(1));
    expect(c.read(colaLecturasProvider).sinConexion, isTrue);
    expect(repo.enviadas, isEmpty);

    repo.conectado = true;
    await cola.enviarAhora();
    expect(c.read(colaLecturasProvider).pendientes, isEmpty);
    expect(c.read(colaLecturasProvider).sinConexion, isFalse);
    expect(repo.enviadas, ['carga 111']);
    c.dispose();
  });

  test('las lecturas sobreviven a cerrar la app y se envían al abrirla', () async {
    final (c1, _) = await _contenedor();
    final cola1 = c1.read(colaLecturasProvider.notifier);
    cola1.agregar(tipo: TipoLectura.carga, repartoId: 'r1', codigo: '111');
    cola1.agregar(tipo: TipoLectura.carga, repartoId: 'r1', codigo: '222');
    await cola1.enviarAhora();
    c1.dispose(); // se cierra la app (o se apaga el teléfono)

    final repo = _RepoFalso()..conectado = true;
    final (c2, _) = await _contenedor(repo: repo);
    expect(c2.read(colaLecturasProvider).pendientes, hasLength(2));
    await c2.read(colaLecturasProvider.notifier).enviarAhora();
    expect(repo.enviadas, ['carga 111', 'carga 222']); // en el mismo orden
    expect(c2.read(colaLecturasProvider).pendientes, isEmpty);
    c2.dispose();
  });

  test('quitar una lectura sin enviar no manda nada', () async {
    final (c, repo) = await _contenedor();
    final cola = c.read(colaLecturasProvider.notifier);
    cola.agregar(tipo: TipoLectura.carga, repartoId: 'r1', codigo: '111');
    await cola.enviarAhora();
    cola.quitar(tipo: TipoLectura.quitarCarga, repartoId: 'r1', codigo: '111');
    expect(c.read(colaLecturasProvider).pendientes, isEmpty);

    repo.conectado = true;
    await cola.enviarAhora();
    expect(repo.enviadas, isEmpty);
    c.dispose();
  });

  test('un reenvío que ya había llegado no cuenta como error', () async {
    final (c, repo) = await _contenedor();
    repo
      ..conectado = true
      ..respuestas['111'] = 'duplicado'
      ..respuestas['222'] = 'duplicado_otro_reparto';
    final cola = c.read(colaLecturasProvider.notifier);
    final resultados = <ResultadoLectura>[];
    final sub = cola.resultados.listen(resultados.add);

    cola.agregar(tipo: TipoLectura.carga, repartoId: 'r1', codigo: '111');
    cola.agregar(tipo: TipoLectura.carga, repartoId: 'r1', codigo: '222');
    await cola.enviarAhora();

    expect(resultados.map((r) => r.rechazo), [isNull, contains('otro reparto')]);
    expect(c.read(colaLecturasProvider).pendientes, isEmpty);
    await sub.cancel();
    c.dispose();
  });

  test('las lecturas sin enviar se ven en la lista del reparto', () {
    final base = [
      BultoReparto(id: 'a', codigo: '111', estado: 'cargado', cargadoEn: DateTime(2026)),
    ];
    final hora = DateTime(2026, 1, 1, 10);
    final lista = aplicarLecturas(base, [
      LecturaPendiente(
        id: '1',
        tipo: TipoLectura.entrega,
        repartoId: 'r1',
        codigo: '111',
        tiendaId: 't1',
        escaneadoEn: hora,
      ),
      LecturaPendiente(
        id: '2',
        tipo: TipoLectura.devolucion,
        repartoId: 'r1',
        codigo: '999',
        tiendaId: 't1',
        escaneadoEn: hora,
      ),
    ]);
    expect(lista.map((b) => (b.codigo, b.estado, b.sinEnviar)), [
      ('999', 'devolucion', true),
      ('111', 'entregado', true),
    ]);
  });

  testWidgets('carga sin conexión: se sigue escaneando y no se termina hasta enviarlo', (
    tester,
  ) async {
    final repo = _RepoFalso();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repartidorRepositoryProvider.overrideWithValue(repo),
          preferenciasProvider.overrideWithValue(prefs),
          sesionProvider.overrideWith(_SesionFalsa.new),
        ],
        retry: (_, _) => null,
        child: MaterialApp(
          home: Scaffold(
            body: RepartoPage(
              reparto: RepartoActivo(
                id: 'r1',
                estado: 'carga',
                rutaId: 'ruta1',
                ruta: 'Ruta 1',
                iniciadoEn: DateTime(2026, 10, 13, 8),
                total: 0,
                entregados: 0,
                pendientes: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    Future<void> escribir(String codigo) async {
      await tester.enterText(find.widgetWithText(TextField, 'O escribe el código'), codigo);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
    }

    // Botón de enviar: desactivado con el campo vacío, se activa al escribir
    IconButton enviar() => tester.widget(find.widgetWithIcon(IconButton, Icons.send));
    expect(enviar().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'O escribe el código'), '123456789');
    await tester.pump();
    expect(enviar().onPressed, isNotNull);
    await tester.tap(find.byTooltip('Enviar código'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Cargado 123456789 · 1 en total'), findsOneWidget);
    expect(enviar().onPressed, isNull); // el campo se vacía tras enviar
    expect(find.textContaining('sin enviar'), findsWidgets);

    // Duplicado detectado en el móvil, sin conexión
    await escribir('123456789');
    expect(find.text('DUPLICADO: 123456789 ya está en tu carga'), findsOneWidget);

    // Terminar no confirma mientras falte enviar algo
    await tester.tap(find.text('Terminar carga (1)'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Faltan 1 lectura por enviar'), findsOneWidget);
    expect(find.text('Terminar la carga'), findsNothing);

    // Vuelve la conexión: se envía y desaparece el aviso de pendientes
    repo.conectado = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(repo.enviadas, ['carga 123456789']);
    expect(find.textContaining('· sin enviar'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}

class _SesionFalsa extends SesionNotifier {
  @override
  EstadoSesion build() => const SinSesion();
}
