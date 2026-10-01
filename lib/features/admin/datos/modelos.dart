typedef Json = Map<String, dynamic>;

/// Nombre de una relación embebida por PostgREST: `clientes(nombre)` → {'nombre': …}
String? _nombreEmbebido(Object? relacion) =>
    relacion is Map ? relacion['nombre'] as String? : null;

DateTime? _fecha(Object? valor) => valor == null ? null : DateTime.parse(valor as String);

class Rol {
  const Rol({required this.codigo, required this.nombre});

  factory Rol.fromJson(Json j) =>
      Rol(codigo: j['codigo'] as String, nombre: j['nombre'] as String);

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
    final conteo = j['tiendas'];
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

class Tienda {
  const Tienda({
    required this.id,
    required this.nombre,
    required this.clienteId,
    required this.activa,
    this.clienteNombre,
    this.rutaId,
    this.rutaNombre,
    this.ordenEnRuta,
    this.direccion,
    this.codigoPostal,
    this.localidad,
  });

  factory Tienda.fromJson(Json j) => Tienda(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    direccion: j['direccion'] as String?,
    codigoPostal: j['codigo_postal'] as String?,
    localidad: j['localidad'] as String?,
    clienteId: j['cliente_id'] as String,
    clienteNombre: _nombreEmbebido(j['clientes']),
    rutaId: j['ruta_id'] as String?,
    rutaNombre: _nombreEmbebido(j['rutas']),
    ordenEnRuta: j['orden_en_ruta'] as int?,
    activa: j['activa'] as bool,
  );

  final String id;
  final String nombre;
  final String? direccion;
  final String? codigoPostal;
  final String? localidad;
  final String clienteId;
  final String? clienteNombre;
  final String? rutaId;
  final String? rutaNombre;
  final int? ordenEnRuta;
  final bool activa;

  String get direccionCompleta => [direccion, codigoPostal, localidad]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(', ');
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
    this.cargaConfirmadaEn,
    this.cerradoEn,
    this.motivoCierre,
  });

  factory RepartoVista.fromJson(Json j) => RepartoVista(
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
}
