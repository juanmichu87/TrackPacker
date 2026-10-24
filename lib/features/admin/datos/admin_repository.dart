import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/formato.dart';
import '../../../core/salidas.dart';
import '../../../core/supabase.dart';
import 'modelos.dart';

/// Acceso a datos del panel de administración. Las lecturas y escrituras
/// directas están protegidas por RLS; lo que toca Auth va por funciones RPC.
class AdminRepository {
  AdminRepository(this._db);

  final SupabaseClient _db;

  // --- Genérico --------------------------------------------------------------

  /// Inserta (id null) o actualiza una fila.
  Future<void> guardar(String tabla, String? id, Json datos) async {
    if (id == null) {
      await _db.from(tabla).insert(datos);
    } else {
      await _db.from(tabla).update(datos).eq('id', id);
    }
  }

  Future<void> eliminar(String tabla, String id) => _db.from(tabla).delete().eq('id', id);

  // --- Resumen y ajustes -----------------------------------------------------

  Future<Resumen> resumen() async =>
      Resumen(Map<String, dynamic>.from(await _db.rpc('admin_resumen') as Map));

  Future<Ajustes> ajustes() async => Ajustes.fromJson(await _db.from('ajustes').select().single());

  Future<void> guardarAjustes({required int diasFotos, required int diasBultos}) => _db
      .from('ajustes')
      .update({'dias_retencion_fotos': diasFotos, 'dias_retencion_bultos': diasBultos})
      .eq('id', true);

  // --- Catálogos -------------------------------------------------------------

  // Ojo: en supabase-dart `.order()` es descendente por defecto, así que se
  // indica siempre `ascending: true`. Los nombres se ordenan además en la app
  // con orden natural («Ruta 2» antes que «Ruta 10»).

  Future<List<Rol>> roles() async =>
      (await _db.from('roles').select('codigo, nombre').order('nombre', ascending: true))
          .map(Rol.fromJson)
          .toList();

  Future<List<Cliente>> clientes() async =>
      (await _db.from('clientes').select().order('nombre', ascending: true))
          .map(Cliente.fromJson)
          .toList()
        ..sort((a, b) => compararNatural(a.nombre, b.nombre));

  Future<List<Area>> areas() async =>
      (await _db.from('areas').select('id, nombre').order('nombre', ascending: true))
          .map(Area.fromJson)
          .toList()
        ..sort((a, b) => compararNatural(a.nombre, b.nombre));

  Future<List<Ruta>> rutas() async =>
      (await _db
              .from('rutas')
              .select('id, nombre, area_id, activa, areas(nombre), ruta_tiendas(count)')
              .order('nombre', ascending: true))
          .map(Ruta.fromJson)
          .toList()
        ..sort((a, b) => compararNatural(a.nombre, b.nombre));

  static const _selectTienda = '*, clientes(nombre), ruta_tiendas(orden, rutas(id, nombre))';

  Future<List<Tienda>> tiendas() async =>
      (await _db.from('tiendas').select(_selectTienda).order('nombre', ascending: true))
          .map(Tienda.fromJson)
          .toList()
        ..sort((a, b) => compararNatural(a.nombre, b.nombre));

  /// Tiendas de una ruta en su orden de reparto.
  Future<List<Tienda>> tiendasDeRuta(String rutaId) async => [
    for (final fila
        in await _db
            .from('ruta_tiendas')
            .select('orden, tiendas($_selectTienda)')
            .eq('ruta_id', rutaId)
            .order('orden', ascending: true, nullsFirst: false))
      Tienda.fromJson(fila['tiendas'] as Json),
  ];

  /// Crea (id null) o actualiza una tienda y fija sus rutas. Devuelve su id.
  Future<String> guardarTienda(String? id, Json datos, {required List<String> rutaIds}) async {
    final String tiendaId;
    if (id == null) {
      tiendaId = (await _db.from('tiendas').insert(datos).select('id').single())['id'] as String;
    } else {
      await _db.from('tiendas').update(datos).eq('id', id);
      tiendaId = id;
    }
    await _db.rpc('admin_rutas_de_tienda', params: {'p_tienda_id': tiendaId, 'p_rutas': rutaIds});
    return tiendaId;
  }

  /// Deja la ruta con exactamente estas tiendas, en este orden.
  Future<void> ordenarTiendas(String rutaId, List<String> tiendaIds) =>
      _db.rpc('admin_ordenar_tiendas', params: {'p_ruta_id': rutaId, 'p_tiendas': tiendaIds});

  // --- Salidas (franjas horarias de una ruta) ---------------------------------

  Future<List<Salida>> salidasDeRuta(String rutaId) async =>
      (await _db
              .from('salidas')
              .select('*, salida_tiendas(tienda_id)')
              .eq('ruta_id', rutaId)
              .order('hora_inicio', ascending: true))
          .map(Salida.fromJson)
          .toList();

  /// Crea (id null) o actualiza una salida con sus tiendas. Devuelve su id.
  Future<String> guardarSalida({
    String? id,
    required String rutaId,
    required String nombre,
    required int inicio,
    required int fin,
    required Set<int> dias,
    required bool activa,
    required List<String> tiendaIds,
  }) async => await _db.rpc(
    'admin_guardar_salida',
    params: {
      'p_id': id,
      'p_ruta_id': rutaId,
      'p_nombre': nombre,
      'p_hora_inicio': horaDeMinutos(inicio),
      'p_hora_fin': horaDeMinutos(fin),
      'p_dias_semana': dias.toList()..sort(),
      'p_activa': activa,
      'p_tiendas': tiendaIds,
    },
  ) as String;

  // --- Usuarios --------------------------------------------------------------

  Future<List<UsuarioAdmin>> usuarios() async =>
      (await _db.from('usuarios').select('*, clientes(nombre)').order('usuario', ascending: true))
          .map(UsuarioAdmin.fromJson)
          .toList();

  Future<void> crearUsuario({
    required String usuario,
    required String contrasena,
    required String rol,
    String? nombreCompleto,
    String? email,
    String? telefono,
    String? clienteId,
  }) => _db.rpc(
    'admin_crear_usuario',
    params: {
      'p_usuario': usuario,
      'p_contrasena': contrasena,
      'p_rol': rol,
      'p_nombre_completo': nombreCompleto,
      'p_email': email,
      'p_telefono': telefono,
      'p_cliente_id': clienteId,
    },
  );

  Future<void> actualizarUsuario({
    required String id,
    required String usuario,
    required String rol,
    required bool activo,
    String? nombreCompleto,
    String? email,
    String? telefono,
    String? clienteId,
  }) => _db.rpc(
    'admin_actualizar_usuario',
    params: {
      'p_id': id,
      'p_usuario': usuario,
      'p_rol': rol,
      'p_activo': activo,
      'p_nombre_completo': nombreCompleto,
      'p_email': email,
      'p_telefono': telefono,
      'p_cliente_id': clienteId,
    },
  );

  Future<void> cambiarContrasena(String id, String contrasena) =>
      _db.rpc('admin_cambiar_contrasena', params: {'p_id': id, 'p_contrasena': contrasena});

  /// Elimina un reparto con sus bultos, incidencias y fotos (también los
  /// archivos). Devuelve cuántas fotos se borraron.
  Future<int> eliminarReparto(String id) async =>
      _borrarFotos(await _db.rpc('admin_eliminar_reparto', params: {'p_id': id}) as List);

  /// Elimina un usuario con todo su historial (repartos, bultos, fotos,
  /// incidencias). Devuelve cuántas fotos se borraron.
  Future<int> eliminarUsuarioConHistorial(String id) async => _borrarFotos(
    await _db.rpc('admin_eliminar_usuario_con_historial', params: {'p_id': id}) as List,
  );

  /// Borra de Storage los archivos de las fotos ya eliminadas de la base de datos.
  Future<int> _borrarFotos(List rutas) async {
    final archivos = [for (final r in rutas) r as String];
    if (archivos.isNotEmpty) await _db.storage.from('entregas').remove(archivos);
    return archivos.length;
  }

  Future<void> eliminarUsuario(String id) =>
      _db.rpc('admin_eliminar_usuario', params: {'p_id': id});

  // --- Tiendas añadidas por los repartidores -----------------------------------

  /// Avisos pendientes (vacío si la base de datos aún no tiene la migración 13).
  Future<List<TiendaTemporal>> tiendasTemporales() async {
    try {
      return (await _db
              .from('tiendas_temporales')
              .select(
                'id, creada_en, tiendas(nombre), repartos(rutas(nombre), salidas(nombre)), '
                'repartidor:usuarios!tiendas_temporales_repartidor_id_fkey(nombre_completo, usuario)',
              )
              .eq('estado', 'pendiente')
              .order('creada_en', ascending: false))
          .map(TiendaTemporal.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return const [];
      rethrow;
    }
  }

  /// Añadir la tienda a la ruta (y a la salida) o descartar el aviso.
  Future<void> resolverTiendaTemporal(String id, {required bool agregar}) =>
      _db.rpc('admin_resolver_tienda_temporal', params: {'p_id': id, 'p_agregar': agregar});

  // --- Repartos --------------------------------------------------------------

  /// Repartos del periodo y, además, los que siguen abiertos aunque
  /// empezaran antes (un reparto de ayer sin cerrar debe verse en «Hoy»).
  Future<List<RepartoVista>> repartos({required DateTime desde}) async =>
      (await _db
              .from('v_repartos')
              .select()
              .or('iniciado_en.gte.${desde.toUtc().toIso8601String()},estado.in.(carga,en_ruta)')
              .order('iniciado_en', ascending: false)
              .limit(500))
          .map(RepartoVista.fromJson)
          .toList();

  Future<RepartoVista> reparto(String id) async =>
      RepartoVista.fromJson(await _db.from('v_repartos').select().eq('id', id).single());

  Future<List<BultoVista>> bultosDeReparto(String repartoId) async =>
      (await _db
              .from('v_bultos')
              .select('id, codigo, estado, tienda, cliente, cargado_en, entregado_en, motivo')
              .eq('reparto_id', repartoId)
              .order('cargado_en', ascending: true))
          .map(BultoVista.fromJson)
          .toList();
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseProvider)),
);

// Listas cacheadas. Tras guardar cambios se invalidan con ref.invalidate(...).
final resumenProvider = FutureProvider<Resumen>(
  (ref) => ref.watch(adminRepositoryProvider).resumen(),
);
final ajustesProvider = FutureProvider<Ajustes>(
  (ref) => ref.watch(adminRepositoryProvider).ajustes(),
);
final rolesProvider = FutureProvider<List<Rol>>(
  (ref) => ref.watch(adminRepositoryProvider).roles(),
);
final clientesProvider = FutureProvider<List<Cliente>>(
  (ref) => ref.watch(adminRepositoryProvider).clientes(),
);
final areasProvider = FutureProvider<List<Area>>(
  (ref) => ref.watch(adminRepositoryProvider).areas(),
);
final rutasProvider = FutureProvider<List<Ruta>>(
  (ref) => ref.watch(adminRepositoryProvider).rutas(),
);
final tiendasProvider = FutureProvider<List<Tienda>>(
  (ref) => ref.watch(adminRepositoryProvider).tiendas(),
);
final usuariosProvider = FutureProvider<List<UsuarioAdmin>>(
  (ref) => ref.watch(adminRepositoryProvider).usuarios(),
);

final tiendasTemporalesProvider = FutureProvider<List<TiendaTemporal>>(
  (ref) => ref.watch(adminRepositoryProvider).tiendasTemporales(),
);

final salidasDeRutaProvider = FutureProvider.family<List<Salida>, String>(
  (ref, rutaId) => ref.watch(adminRepositoryProvider).salidasDeRuta(rutaId),
);

final repartosProvider = FutureProvider.family<List<RepartoVista>, int>((ref, dias) {
  final hoy = DateTime.now();
  final desde = DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: dias - 1));
  return ref.watch(adminRepositoryProvider).repartos(desde: desde);
});
final repartoProvider = FutureProvider.family<RepartoVista, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).reparto(id),
);
final bultosDeRepartoProvider = FutureProvider.family<List<BultoVista>, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).bultosDeReparto(id),
);

/// Invalida todo lo que depende de rutas y tiendas (recuentos, listas, resumen).
void refrescarRutasYTiendas(WidgetRef ref) {
  ref.invalidate(rutasProvider);
  ref.invalidate(tiendasProvider);
  ref.invalidate(resumenProvider);
}
