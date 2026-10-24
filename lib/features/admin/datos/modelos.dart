import '../../../core/formato.dart';

typedef Json = Map<String, dynamic>;

/// Nombre de una relación embebida por PostgREST: `clientes(nombre)` → {'nombre': …}
String? _nombreEmbebido(Object? relacion) => relacion is Map ? relacion['nombre'] as String? : null;

DateTime? _fecha(Object? valor) => valor == null ? null : DateTime.parse(valor as String);

class Rol {
  const Rol({required this.codigo, required this.nombre});

  factory Rol.fromJson(Json j) => Rol(codigo: j['codigo'] as String, nombre: j['nombre'] as String);

  final String codigo;
  final String nombre;
}

class Cliente {
  const Cliente({
    required this.id,
    required this.nombre,
    required this.formatos,
    required this.activo,
    this.cif,
    this.patronExtraccion,
    this.longitudMin,
    this.longitudMax,
  });

  factory Cliente.fromJson(Json j) => Cliente(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    cif: j['cif'] as String?,
    formatos: [for (final f in j['formatos'] as List) f as String],
    patronExtraccion: j['patron_extraccion'] as String?,
    longitudMin: j['longitud_min'] as int?,
    longitudMax: j['longitud_max'] as int?,
    activo: j['activo'] as bool,
  );

  final String id;
  final String nombre;
  final String? cif;
  final List<String> formatos;
  final String? patronExtraccion;
  final int? longitudMin;
  final int? longitudMax;
  final bool activo;
}

class Area {
  const Area({required this.id, required this.nombre});

  factory Area.fromJson(Json j) => Area(id: j['id'] as String, nombre: j['nombre'] as String);

  final String id;
  final String nombre;
}

class Ruta {
  const Ruta({
    required this.id,
    required this.nombre,
    required this.activa,
    required this.numTiendas,
    this.areaId,
    this.areaNombre,
  });

  factory Ruta.fromJson(Json j) {
    final conteo = j['ruta_tiendas'];
    return Ruta(
      id: j['id'] as String,
      nombre: j['nombre'] as String,
      areaId: j['area_id'] as String?,
      areaNombre: _nombreEmbebido(j['areas']),
      activa: j['activa'] as bool,
      numTiendas: conteo is List && conteo.isNotEmpty ? conteo.first['count'] as int : 0,
    );
  }

  final String id;
  final String nombre;
  final String? areaId;
  final String? areaNombre;
  final bool activa;
  final int numTiendas;
}

/// Ruta en la que está una tienda, con su posición en el recorrido.
class RutaDeTienda {
  const RutaDeTienda({required this.id, required this.nombre, this.orden});

  final String id;
  final String nombre;
  final int? orden;

  String get texto => orden == null ? nombre : '$nombre (#$orden)';
}

class Tienda {
  const Tienda({
    required this.id,
    required this.nombre,
    required this.clienteId,
    required this.activa,
    this.clienteNombre,
    this.rutas = const [],
    this.direccion,
    this.codigoPostal,
    this.localidad,
  });

  /// Admite la tienda con sus rutas embebidas: `ruta_tiendas(orden, rutas(id, nombre))`.
  factory Tienda.fromJson(Json j) => Tienda(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    direccion: j['direccion'] as String?,
    codigoPostal: j['codigo_postal'] as String?,
    localidad: j['localidad'] as String?,
    clienteId: j['cliente_id'] as String,
    clienteNombre: _nombreEmbebido(j['clientes']),
    rutas: [
      for (final rt in (j['ruta_tiendas'] as List?) ?? const [])
        if (rt['rutas'] case final Map<String, dynamic> ruta)
          RutaDeTienda(
            id: ruta['id'] as String,
            nombre: ruta['nombre'] as String,
            orden: rt['orden'] as int?,
          ),
    ]..sort((a, b) => compararNatural(a.nombre, b.nombre)),
    activa: j['activa'] as bool,
  );

  final String id;
  final String nombre;
  final String? direccion;
  final String? codigoPostal;
  final String? localidad;
  final String clienteId;
  final String? clienteNombre;
  final List<RutaDeTienda> rutas;
  final bool activa;

  bool estaEnRuta(String rutaId) => rutas.any((r) => r.id == rutaId);

  String get direccionCompleta => [
    direccion,
    codigoPostal,
    localidad,
  ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
}

class UsuarioAdmin {
  const UsuarioAdmin({
    required this.id,
    required this.usuario,
    required this.rol,
    required this.activo,
    this.nombreCompleto,
    this.email,
    this.telefono,
    this.clienteId,
    this.clienteNombre,
  });

  factory UsuarioAdmin.fromJson(Json j) => UsuarioAdmin(
    id: j['id'] as String,
    usuario: j['usuario'] as String,
    nombreCompleto: j['nombre_completo'] as String?,
    email: j['email'] as String?,
    telefono: j['telefono'] as String?,
    rol: j['rol'] as String,
    clienteId: j['cliente_id'] as String?,
    clienteNombre: _nombreEmbebido(j['clientes']),
    activo: j['activo'] as bool,
  );

  final String id;
  final String usuario;
  final String? nombreCompleto;
  final String? email;
  final String? telefono;
  final String rol;
  final String? clienteId;
  final String? clienteNombre;
  final bool activo;

  String get nombreVisible {
    final nombre = nombreCompleto?.trim() ?? '';
    return nombre.isEmpty ? usuario : nombre;
  }
}

class RepartoVista {
  const RepartoVista({
    required this.id,
    required this.estado,
    required this.iniciadoEn,
    required this.rutaId,
    required this.ruta,
    required this.repartidor,
    required this.totalBultos,
    required this.entregados,
    required this.pendientes,
    required this.noEntregados,
    this.devoluciones = 0,
    this.cargaConfirmadaEn,
    this.cerradoEn,
    this.motivoCierre,
    this.salida,
  });

  factory RepartoVista.fromJson(Json j) => RepartoVista(
    salida: switch ((j['salida'], j['salida_inicio'], j['salida_fin'])) {
      (final String nombre, final String inicio, final String fin) =>
        '$nombre ${inicio.substring(0, 5)}–${fin.substring(0, 5)}',
      _ => null,
    },
    id: j['id'] as String,
    estado: j['estado'] as String,
    iniciadoEn: DateTime.parse(j['iniciado_en'] as String),
    cargaConfirmadaEn: _fecha(j['carga_confirmada_en']),
    cerradoEn: _fecha(j['cerrado_en']),
    motivoCierre: j['motivo_cierre'] as String?,
    rutaId: j['ruta_id'] as String,
    ruta: j['ruta'] as String,
    repartidor: j['repartidor'] as String? ?? '—',
    totalBultos: j['total_bultos'] as int,
    entregados: j['entregados'] as int,
    pendientes: j['pendientes'] as int,
    noEntregados: j['no_entregados'] as int,
    devoluciones: (j['devoluciones'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String estado;
  final DateTime iniciadoEn;
  final DateTime? cargaConfirmadaEn;
  final DateTime? cerradoEn;
  final String? motivoCierre;
  final String rutaId;
  final String ruta;
  final String repartidor;
  final int totalBultos;
  final int entregados;
  final int pendientes;
  final int noEntregados;

  /// Paquetes que las tiendas dieron al repartidor para devolver.
  final int devoluciones;

  /// Salida del reparto ("Mañana 06:00–10:00"), si se hizo con salida.
  final String? salida;
}

class BultoVista {
  const BultoVista({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.cargadoEn,
    this.tienda,
    this.cliente,
    this.entregadoEn,
    this.motivo,
  });

  factory BultoVista.fromJson(Json j) => BultoVista(
    id: j['id'] as String,
    codigo: j['codigo'] as String,
    estado: j['estado'] as String,
    tienda: j['tienda'] as String?,
    cliente: j['cliente'] as String?,
    cargadoEn: DateTime.parse(j['cargado_en'] as String),
    entregadoEn: _fecha(j['entregado_en']),
    motivo: j['motivo'] as String?,
  );

  final String id;
  final String codigo;
  final String estado;
  final String? tienda;
  final String? cliente;
  final DateTime cargadoEn;
  final DateTime? entregadoEn;
  final String? motivo;
}

class Ajustes {
  const Ajustes({required this.diasRetencionFotos, required this.diasRetencionBultos});

  factory Ajustes.fromJson(Json j) => Ajustes(
    diasRetencionFotos: j['dias_retencion_fotos'] as int,
    diasRetencionBultos: j['dias_retencion_bultos'] as int,
  );

  final int diasRetencionFotos;
  final int diasRetencionBultos;
}

class Resumen {
  const Resumen(this._j);

  final Json _j;

  int _n(String clave) => (_j[clave] as num?)?.toInt() ?? 0;
  int _bultos(String clave) => ((_j['bultos_hoy'] as Map?)?[clave] as num?)?.toInt() ?? 0;

  Map<String, int> get usuariosPorRol => {
    for (final e in ((_j['usuarios_por_rol'] as Map?) ?? {}).entries)
      e.key as String: (e.value as num).toInt(),
  };
  int get usuariosInactivos => _n('usuarios_inactivos');
  int get clientes => _n('clientes');
  int get rutas => _n('rutas');
  int get tiendas => _n('tiendas');
  int get tiendasSinRuta => _n('tiendas_sin_ruta');
  int get repartosAbiertos => _n('repartos_abiertos');
  int get incidenciasAbiertas => _n('incidencias_abiertas');
  int get bultosHoy => _bultos('total');
  int get entregadosHoy => _bultos('entregados');
  int get pendientesHoy => _bultos('pendientes');
  int get noEntregadosHoy => _bultos('no_entregados');
  int get devolucionesHoy => _bultos('devoluciones');
  int get tiendasTemporales => _n('tiendas_temporales');
}

/// Tienda que un repartidor añadió a su reparto porque no estaba en la ruta.
class TiendaTemporal {
  const TiendaTemporal({
    required this.id,
    required this.tienda,
    required this.ruta,
    required this.repartidor,
    required this.creadaEn,
    this.salida,
  });

  factory TiendaTemporal.fromJson(Json j) {
    final reparto = j['repartos'] as Json? ?? const {};
    final usuario = j['repartidor'] as Json? ?? const {};
    final nombre = (usuario['nombre_completo'] as String?)?.trim() ?? '';
    return TiendaTemporal(
      id: j['id'] as String,
      tienda: (j['tiendas'] as Json?)?['nombre'] as String? ?? '—',
      ruta: (reparto['rutas'] as Json?)?['nombre'] as String? ?? '—',
      salida: (reparto['salidas'] as Json?)?['nombre'] as String?,
      repartidor: nombre.isNotEmpty ? nombre : usuario['usuario'] as String? ?? '—',
      creadaEn: DateTime.parse(j['creada_en'] as String),
    );
  }

  final String id;
  final String tienda;
  final String ruta;
  final String? salida;
  final String repartidor;
  final DateTime creadaEn;
}
