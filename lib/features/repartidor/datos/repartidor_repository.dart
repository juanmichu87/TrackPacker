import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codigos.dart';
import '../../../core/formato.dart';
import '../../../core/salidas.dart';
import '../../../core/supabase.dart';

typedef Json = Map<String, dynamic>;

DateTime? _fecha(Object? v) => v == null ? null : DateTime.parse(v as String);

/// Ruta con su ocupación actual (quién la está haciendo).
class RutaRepartidor {
  const RutaRepartidor({
    required this.id,
    required this.nombre,
    required this.numTiendas,
    required this.numSalidas,
    required this.esMia,
    this.ocupadaPor,
    this.ocupadaEstado,
    this.ocupadaDesde,
  });

  factory RutaRepartidor.fromJson(Json j) => RutaRepartidor(
    id: j['ruta_id'] as String,
    nombre: j['ruta'] as String,
    numTiendas: (j['num_tiendas'] as num).toInt(),
    numSalidas: (j['num_salidas'] as num).toInt(),
    ocupadaPor: j['ocupada_por'] as String?,
    ocupadaEstado: j['ocupada_estado'] as String?,
    ocupadaDesde: _fecha(j['ocupada_desde']),
    esMia: j['es_mia'] as bool? ?? false,
  );

  final String id;
  final String nombre;
  final int numTiendas;
  final int numSalidas;
  final String? ocupadaPor;
  final String? ocupadaEstado;
  final DateTime? ocupadaDesde;
  final bool esMia;

  /// Ocupada por otro repartidor.
  bool get ocupada => ocupadaEstado != null && !esMia;
}

/// Reparto abierto del repartidor (carga o en ruta), con sus recuentos.
class RepartoActivo {
  const RepartoActivo({
    required this.id,
    required this.estado,
    required this.rutaId,
    required this.ruta,
    required this.iniciadoEn,
    required this.total,
    required this.entregados,
    required this.pendientes,
    this.salidaId,
    this.salida,
  });

  factory RepartoActivo.fromJson(Json j) => RepartoActivo(
    id: j['id'] as String,
    estado: j['estado'] as String,
    rutaId: j['ruta_id'] as String,
    ruta: j['ruta'] as String,
    iniciadoEn: DateTime.parse(j['iniciado_en'] as String),
    salidaId: j['salida_id'] as String?,
    salida: switch ((j['salida'], j['salida_inicio'])) {
      (final String nombre, final String inicio) => '$nombre (${inicio.substring(0, 5)})',
      _ => null,
    },
    total: (j['total_bultos'] as num).toInt(),
    entregados: (j['entregados'] as num).toInt(),
    pendientes: (j['pendientes'] as num).toInt(),
  );

  final String id;
  final String estado;
  final String rutaId;
  final String ruta;
  final String? salidaId;
  final String? salida;
  final DateTime iniciadoEn;
  final int total;
  final int entregados;
  final int pendientes;

  String get titulo => salida == null ? ruta : '$ruta · $salida';
}

/// Tienda de la ruta, en su orden de reparto.
class TiendaReparto {
  const TiendaReparto({
    required this.id,
    required this.nombre,
    required this.clienteId,
    this.direccion,
    this.orden,
    this.temporal = false,
  });

  final String id;
  final String nombre;
  final String clienteId;
  final String? direccion;
  final int? orden;

  /// Añadida por el repartidor a este reparto (no está en la ruta).
  final bool temporal;
}

/// Tienda que se puede añadir temporalmente al reparto.
class TiendaElegible {
  const TiendaElegible({required this.id, required this.nombre, this.direccion});

  final String id;
  final String nombre;
  final String? direccion;
}

String _direccion(Json t) => [
  t['direccion'],
  t['localidad'],
].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');

const _selectTiendaReparto =
    'id, nombre, direccion, localidad, cliente_id, activa, '
    'clientes(formatos, patron_extraccion, longitud_min, longitud_max)';

class BultoReparto {
  const BultoReparto({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.cargadoEn,
    this.tiendaId,
    this.entregadoEn,
  });

  factory BultoReparto.fromJson(Json j) => BultoReparto(
    id: j['id'] as String,
    codigo: j['codigo'] as String,
    estado: j['estado'] as String,
    tiendaId: j['tienda_id'] as String?,
    cargadoEn: DateTime.parse(j['cargado_en'] as String),
    entregadoEn: _fecha(j['entregado_en']),
  );

  final String id;
  final String codigo;
  final String estado;
  final String? tiendaId;
  final DateTime cargadoEn;
  final DateTime? entregadoEn;
}

/// Todo lo que necesita la pantalla de un reparto, cargado de una vez.
class DatosReparto {
  const DatosReparto({
    required this.reparto,
    required this.tiendas,
    required this.reglas,
    required this.bultos,
    this.deLaRuta = const {},
  });

  final RepartoActivo reparto;

  /// Todas las tiendas de la ruta (también las de otras franjas): al añadir
  /// una tienda temporal se ofrecen primero.
  final Set<String> deLaRuta;

  /// Tiendas de la salida (o de la ruta si no tiene salida), en orden.
  final List<TiendaReparto> tiendas;

  /// Reglas de lectura de los clientes de esas tiendas.
  final List<ReglaCliente> reglas;
  final List<BultoReparto> bultos;
}

class RepartidorRepository {
  RepartidorRepository(this._db);

  final SupabaseClient _db;

  Future<List<RutaRepartidor>> rutas() async => [
    for (final f in await _db.rpc('rutas_para_repartidor') as List)
      RutaRepartidor.fromJson(f as Json),
  ]..sort((a, b) => compararNatural(a.nombre, b.nombre));

  Future<List<Salida>> salidas(String rutaId) async =>
      (await _db
              .from('salidas')
              .select('*, salida_tiendas(tienda_id)')
              .eq('ruta_id', rutaId)
              .eq('activa', true)
              .order('hora_inicio', ascending: true))
          .map(Salida.fromJson)
          .toList();

  /// Reparto abierto del usuario (como mucho hay uno).
  Future<RepartoActivo?> repartoAbierto() async {
    final fila = await _db
        .from('v_repartos')
        .select()
        .inFilter('estado', ['carga', 'en_ruta'])
        .order('iniciado_en', ascending: false)
        .limit(1)
        .maybeSingle();
    return fila == null ? null : RepartoActivo.fromJson(fila);
  }

  /// Carga en paralelo todo lo necesario para trabajar con un reparto.
  Future<DatosReparto> datosReparto(RepartoActivo reparto) async {
    final (filasTiendas, filasSalida, filasBultos, filasTemporales) = await (
      _db
          .from('ruta_tiendas')
          // Las reglas de lectura del cliente llegan embebidas (sin otra consulta)
          .select('orden, tiendas($_selectTiendaReparto)')
          .eq('ruta_id', reparto.rutaId)
          .order('orden', ascending: true, nullsFirst: false),
      reparto.salidaId == null
          ? Future.value(const <Json>[])
          : _db.from('salida_tiendas').select('tienda_id').eq('salida_id', reparto.salidaId!),
      _db
          .from('bultos')
          .select('id, codigo, estado, tienda_id, cargado_en, entregado_en')
          .eq('reparto_id', reparto.id)
          .order('cargado_en', ascending: false),
      _temporales(reparto.id),
    ).wait;

    final deLaSalida = {for (final f in filasSalida) f['tienda_id'] as String};
    final tiendas = [
      for (final f in filasTiendas)
        if (f['tiendas'] case final Json t when t['activa'] == true)
          if (reparto.salidaId == null || deLaSalida.contains(t['id']))
            TiendaReparto(
              id: t['id'] as String,
              nombre: t['nombre'] as String,
              clienteId: t['cliente_id'] as String,
              direccion: _direccion(t),
              orden: f['orden'] as int?,
            ),
      // Las que añadió el repartidor, al final
      for (final f in filasTemporales)
        if (f['tiendas'] case final Json t)
          TiendaReparto(
            id: t['id'] as String,
            nombre: t['nombre'] as String,
            clienteId: t['cliente_id'] as String,
            direccion: _direccion(t),
            temporal: true,
          ),
    ];

    // Una regla por cliente de las tiendas visibles
    final reglasPorCliente = <String, ReglaCliente>{
      for (final f in [...filasTiendas, ...filasTemporales])
        if (f['tiendas'] case final Json t)
          if (tiendas.any((x) => x.id == t['id']))
            if (t['clientes'] case final Json c)
              t['cliente_id'] as String: ReglaCliente.fromJson(c),
    };
    final reglas = reglasPorCliente.values.toList();

    return DatosReparto(
      reparto: reparto,
      tiendas: tiendas,
      deLaRuta: {
        for (final f in filasTiendas)
          if (f['tiendas'] case final Json t) t['id'] as String,
      },
      reglas: reglas,
      bultos: [for (final f in filasBultos) BultoReparto.fromJson(f)],
    );
  }

  /// Tiendas temporales del reparto (vacío si la base de datos aún no tiene
  /// la migración 13).
  Future<List<Json>> _temporales(String repartoId) async {
    try {
      return await _db
          .from('tiendas_temporales')
          .select('tiendas($_selectTiendaReparto)')
          .eq('reparto_id', repartoId)
          .order('creada_en', ascending: true);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return const [];
      rethrow;
    }
  }

  /// Tiendas activas que se pueden añadir temporalmente (todas menos las que
  /// ya tiene el reparto).
  Future<List<TiendaElegible>> tiendasElegibles(Set<String> excluir) async => [
    for (final t
        in await _db
            .from('tiendas')
            .select('id, nombre, direccion, localidad')
            .eq('activa', true)
            .order('nombre', ascending: true))
      if (!excluir.contains(t['id']))
        TiendaElegible(
          id: t['id'] as String,
          nombre: t['nombre'] as String,
          direccion: _direccion(t),
        ),
  ]..sort((a, b) => compararNatural(a.nombre, b.nombre));

  /// Añade una tienda solo a este reparto; el admin recibe el aviso.
  Future<void> agregarTiendaTemporal(String repartoId, String tiendaId) => _db.rpc(
    'agregar_tienda_temporal',
    params: {'p_reparto_id': repartoId, 'p_tienda_id': tiendaId},
  );

  Future<void> iniciar(String rutaId, String? salidaId) =>
      _db.rpc('iniciar_reparto', params: {'p_ruta_id': rutaId, 'p_salida_id': salidaId});

  /// 'ok', 'duplicado' o 'duplicado_otro_reparto'
  Future<String> escanearCarga(String repartoId, String codigo, String? formato) async =>
      await _db.rpc(
        'escanear_carga',
        params: {
          'p_reparto_id': repartoId,
          'p_codigo': codigo,
          'p_formato': formato,
          'p_escaneado_en': DateTime.now().toUtc().toIso8601String(),
        },
      ) as String;

  Future<void> quitarDeCarga(String repartoId, String codigo) =>
      _db.rpc('quitar_bulto_carga', params: {'p_reparto_id': repartoId, 'p_codigo': codigo});

  Future<int> confirmarCarga(String repartoId) async =>
      (await _db.rpc('confirmar_carga', params: {'p_reparto_id': repartoId}) as num).toInt();

  /// 'ok', 'ya_entregado' o 'no_cargado'
  Future<String> escanearEntrega(String repartoId, String tiendaId, String codigo) async =>
      await _db.rpc(
        'escanear_entrega',
        params: {
          'p_reparto_id': repartoId,
          'p_tienda_id': tiendaId,
          'p_codigo': codigo,
          'p_escaneado_en': DateTime.now().toUtc().toIso8601String(),
        },
      ) as String;

  /// Paquete que la tienda da al repartidor para devolver. Devuelve 'ok',
  /// 'duplicado' o 'duplicado_otro_reparto'.
  Future<String> escanearDevolucion(
    String repartoId,
    String tiendaId,
    String codigo,
    String? formato,
  ) async => await _db.rpc(
    'escanear_devolucion',
    params: {
      'p_reparto_id': repartoId,
      'p_tienda_id': tiendaId,
      'p_codigo': codigo,
      'p_formato': formato,
      'p_escaneado_en': DateTime.now().toUtc().toIso8601String(),
    },
  ) as String;

  Future<void> quitarDevolucion(String repartoId, String codigo) =>
      _db.rpc('quitar_devolucion', params: {'p_reparto_id': repartoId, 'p_codigo': codigo});

  /// Cierra el reparto. Los bultos pendientes quedan como «No entregado».
  /// Devuelve cuántos bultos quedaban pendientes.
  Future<int> cerrar(String repartoId, {bool forzoso = false, String? motivo}) async =>
      (await _db.rpc(
        'cerrar_reparto',
        params: {'p_reparto_id': repartoId, 'p_forzoso': forzoso, 'p_motivo': motivo},
      ) as num).toInt();

  /// Sube la foto de entrega de una tienda.
  Future<void> subirFoto({
    required String repartoId,
    required String tiendaId,
    required XFile foto,
    required int numBultos,
  }) async {
    final aleatorio = Random().nextInt(1 << 32).toRadixString(16);
    final ruta = '$repartoId/${DateTime.now().millisecondsSinceEpoch}-$aleatorio.jpg';
    await _db.storage
        .from('entregas')
        .uploadBinary(
          ruta,
          await foto.readAsBytes(),
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    await _db.from('fotos_entrega').insert({
      'reparto_id': repartoId,
      'tienda_id': tiendaId,
      'ruta_storage': ruta,
      'num_bultos': numBultos,
    });
  }
}

final repartidorRepositoryProvider = Provider<RepartidorRepository>(
  (ref) => RepartidorRepository(ref.watch(supabaseProvider)),
);

final rutasRepartidorProvider = FutureProvider<List<RutaRepartidor>>(
  (ref) => ref.watch(repartidorRepositoryProvider).rutas(),
);

final repartoAbiertoProvider = FutureProvider<RepartoActivo?>(
  (ref) => ref.watch(repartidorRepositoryProvider).repartoAbierto(),
);
