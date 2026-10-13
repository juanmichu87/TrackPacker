import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formato.dart';
import '../../../core/supabase.dart';

typedef Json = Map<String, dynamic>;

DateTime? _fecha(Object? v) => v == null ? null : DateTime.parse(v as String);

class RutaSimple {
  const RutaSimple(this.id, this.nombre);

  final String id;
  final String nombre;
}

/// Tienda del cliente con las rutas que la visitan.
class TiendaCliente {
  const TiendaCliente({required this.id, required this.nombre, required this.rutas});

  factory TiendaCliente.fromJson(Json j) => TiendaCliente(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    rutas: [
      for (final rt in (j['ruta_tiendas'] as List?) ?? const [])
        if (rt['rutas'] case final Json r) RutaSimple(r['id'] as String, r['nombre'] as String),
    ],
  );

  final String id;
  final String nombre;
  final List<RutaSimple> rutas;
}

class BultoCliente {
  const BultoCliente({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.cargadoEn,
    this.ruta,
    this.tienda,
    this.repartidor,
    this.entregadoEn,
    this.motivo,
  });

  factory BultoCliente.fromJson(Json j) => BultoCliente(
    id: j['id'] as String,
    codigo: j['codigo'] as String,
    estado: j['estado'] as String,
    ruta: j['ruta'] as String?,
    tienda: j['tienda'] as String?,
    repartidor: j['repartidor'] as String?,
    cargadoEn: DateTime.parse(j['cargado_en'] as String),
    entregadoEn: _fecha(j['entregado_en']),
    motivo: j['motivo'] as String?,
  );

  final String id;
  final String codigo;
  final String estado;
  final String? ruta;
  final String? tienda;
  final String? repartidor;
  final DateTime cargadoEn;
  final DateTime? entregadoEn;
  final String? motivo;
}

class Incidencia {
  const Incidencia({
    required this.id,
    required this.descripcion,
    required this.estado,
    required this.creadoEn,
  });

  factory Incidencia.fromJson(Json j) => Incidencia(
    id: j['id'] as String,
    descripcion: j['descripcion'] as String,
    estado: j['estado'] as String,
    creadoEn: DateTime.parse(j['creado_en'] as String),
  );

  final String id;
  final String descripcion;
  final String estado;
  final DateTime creadoEn;
}

/// Filtro de búsqueda. Es un record para que dos filtros iguales compartan
/// resultado en caché.
typedef FiltroBultos = ({
  DateTime desde,
  DateTime hasta,
  String? rutaId,
  String? tiendaId,
  String? estado,
  String codigo,
});

class ClienteRepository {
  ClienteRepository(this._db);

  final SupabaseClient _db;

  Future<List<TiendaCliente>> tiendas() async =>
      (await _db
              .from('tiendas')
              .select('id, nombre, ruta_tiendas(rutas(id, nombre))')
              .order('nombre', ascending: true))
          .map(TiendaCliente.fromJson)
          .toList()
        ..sort((a, b) => compararNatural(a.nombre, b.nombre));

  /// Bultos de las tiendas del cliente (el RLS solo devuelve los suyos),
  /// filtrados en el servidor.
  Future<List<BultoCliente>> bultos(FiltroBultos f) async {
    var consulta = _db
        .from('v_bultos')
        .select('id, codigo, estado, ruta, tienda, repartidor, cargado_en, entregado_en, motivo')
        .gte('cargado_en', f.desde.toUtc().toIso8601String())
        .lt('cargado_en', f.hasta.toUtc().toIso8601String());
    if (f.rutaId != null) consulta = consulta.eq('ruta_id', f.rutaId!);
    if (f.tiendaId != null) consulta = consulta.eq('tienda_id', f.tiendaId!);
    if (f.estado != null) consulta = consulta.eq('estado', f.estado!);
    if (f.codigo.isNotEmpty) consulta = consulta.ilike('codigo', '%${f.codigo}%');
    return (await consulta.order('cargado_en', ascending: false).limit(1000))
        .map(BultoCliente.fromJson)
        .toList();
  }

  Future<List<Incidencia>> incidencias(String bultoId) async =>
      (await _db
              .from('incidencias')
              .select('id, descripcion, estado, creado_en')
              .eq('bulto_id', bultoId)
              .order('creado_en', ascending: false))
          .map(Incidencia.fromJson)
          .toList();

  Future<void> crearIncidencia(String bultoId, String descripcion) =>
      _db.from('incidencias').insert({'bulto_id': bultoId, 'descripcion': descripcion});
}

final clienteRepositoryProvider = Provider<ClienteRepository>(
  (ref) => ClienteRepository(ref.watch(supabaseProvider)),
);

final tiendasClienteProvider = FutureProvider<List<TiendaCliente>>(
  (ref) => ref.watch(clienteRepositoryProvider).tiendas(),
);

final bultosClienteProvider = FutureProvider.family<List<BultoCliente>, FiltroBultos>(
  (ref, filtro) => ref.watch(clienteRepositoryProvider).bultos(filtro),
);

final incidenciasBultoProvider = FutureProvider.family<List<Incidencia>, String>(
  (ref, bultoId) => ref.watch(clienteRepositoryProvider).incidencias(bultoId),
);
