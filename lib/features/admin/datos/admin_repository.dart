import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<Ajustes> ajustes() async =>
      Ajustes.fromJson(await _db.from('ajustes').select().single());

  Future<void> guardarAjustes({required int diasFotos, required int diasBultos}) => _db
      .from('ajustes')
      .update({'dias_retencion_fotos': diasFotos, 'dias_retencion_bultos': diasBultos})
      .eq('id', true);

  // --- Catálogos -------------------------------------------------------------

  Future<List<Rol>> roles() async =>
      (await _db.from('roles').select('codigo, nombre').order('nombre')).map(Rol.fromJson).toList();

  Future<List<Cliente>> clientes() async =>
      (await _db.from('clientes').select().order('nombre')).map(Cliente.fromJson).toList();

  Future<List<Area>> areas() async =>
      (await _db.from('areas').select('id, nombre').order('nombre')).map(Area.fromJson).toList();

  Future<List<Ruta>> rutas() async => (await _db
          .from('rutas')
          .select('id, nombre, area_id, activa, areas(nombre), tiendas(count)')
          .order('nombre'))
      .map(Ruta.fromJson)
      .toList();

  Future<List<Tienda>> tiendas() async => (await _db
          .from('tiendas')
          .select('*, clientes(nombre), rutas(nombre)')
          .order('nombre'))
      .map(Tienda.fromJson)
      .toList();

  Future<List<Tienda>> tiendasDeRuta(String rutaId) async => (await _db
          .from('tiendas')
          .select('*, clientes(nombre), rutas(nombre)')
          .eq('ruta_id', rutaId)
          .order('orden_en_ruta', nullsFirst: false)
          .order('nombre'))
      .map(Tienda.fromJson)
      .toList();

  /// Deja la ruta con exactamente estas tiendas, en este orden.
  Future<void> ordenarTiendas(String rutaId, List<String> tiendaIds) => _db.rpc(
    'admin_ordenar_tiendas',
    params: {'p_ruta_id': rutaId, 'p_tiendas': tiendaIds},
  );

  // --- Usuarios --------------------------------------------------------------

  Future<List<UsuarioAdmin>> usuarios() async => (await _db
          .from('usuarios')
          .select('*, clientes(nombre)')
          .order('usuario'))
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
  }) => _db.rpc('admin_crear_usuario', params: {
    'p_usuario': usuario,
    'p_contrasena': contrasena,
    'p_rol': rol,
    'p_nombre_completo': nombreCompleto,
    'p_email': email,
    'p_telefono': telefono,
    'p_cliente_id': clienteId,
  });

  Future<void> actualizarUsuario({
    required String id,
    required String usuario,
    required String rol,
    required bool activo,
    String? nombreCompleto,
    String? email,
    String? telefono,
    String? clienteId,
  }) => _db.rpc('admin_actualizar_usuario', params: {
    'p_id': id,
    'p_usuario': usuario,
    'p_rol': rol,
    'p_activo': activo,
    'p_nombre_completo': nombreCompleto,
    'p_email': email,
    'p_telefono': telefono,
    'p_cliente_id': clienteId,
  });

  Future<void> cambiarContrasena(String id, String contrasena) =>
      _db.rpc('admin_cambiar_contrasena', params: {'p_id': id, 'p_contrasena': contrasena});

  Future<void> eliminarUsuario(String id) =>
      _db.rpc('admin_eliminar_usuario', params: {'p_id': id});

  // --- Repartos --------------------------------------------------------------

  Future<List<RepartoVista>> repartos({required DateTime desde}) async => (await _db
          .from('v_repartos')
          .select()
          .gte('iniciado_en', desde.toUtc().toIso8601String())
          .order('iniciado_en', ascending: false)
          .limit(500))
      .map(RepartoVista.fromJson)
      .toList();

  Future<RepartoVista> reparto(String id) async =>
      RepartoVista.fromJson(await _db.from('v_repartos').select().eq('id', id).single());

  Future<List<BultoVista>> bultosDeReparto(String repartoId) async => (await _db
          .from('v_bultos')
          .select('id, codigo, estado, tienda, cliente, cargado_en, entregado_en, motivo')
          .eq('reparto_id', repartoId)
          .order('cargado_en'))
      .map(BultoVista.fromJson)
      .toList();
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseProvider)),
);

// Listas cacheadas. Tras guardar cambios se invalidan con ref.invalidate(...).
final resumenProvider = FutureProvider<Resumen>((ref) => ref.watch(adminRepositoryProvider).resumen());
final ajustesProvider = FutureProvider<Ajustes>((ref) => ref.watch(adminRepositoryProvider).ajustes());
final rolesProvider = FutureProvider<List<Rol>>((ref) => ref.watch(adminRepositoryProvider).roles());
final clientesProvider =
    FutureProvider<List<Cliente>>((ref) => ref.watch(adminRepositoryProvider).clientes());
final areasProvider = FutureProvider<List<Area>>((ref) => ref.watch(adminRepositoryProvider).areas());
final rutasProvider = FutureProvider<List<Ruta>>((ref) => ref.watch(adminRepositoryProvider).rutas());
final tiendasProvider =
    FutureProvider<List<Tienda>>((ref) => ref.watch(adminRepositoryProvider).tiendas());
final usuariosProvider =
    FutureProvider<List<UsuarioAdmin>>((ref) => ref.watch(adminRepositoryProvider).usuarios());

final repartosProvider = FutureProvider.family<List<RepartoVista>, int>(
  (ref, dias) {
    final hoy = DateTime.now();
    final desde = DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: dias - 1));
    return ref.watch(adminRepositoryProvider).repartos(desde: desde);
  },
);
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
