import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/codigos.dart';
import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/plataforma/plataforma.dart';
import '../../core/tema.dart';
import '../../shared/escaner.dart';
import '../../shared/estados.dart';
import '../../shared/panel_scaffold.dart';
import '../../shared/responsive.dart';
import '../../shared/ui.dart';
import 'aviso_lectura.dart';
import 'datos/cola_lecturas.dart';
import 'datos/repartidor_repository.dart';

/// Reparto abierto: carga (escanear bultos en la nave) o en ruta (entregar
/// por tiendas y cerrar).
class RepartoPage extends ConsumerStatefulWidget {
  const RepartoPage({super.key, required this.reparto});

  final RepartoActivo reparto;

  @override
  ConsumerState<RepartoPage> createState() => _RepartoPageState();
}

class _RepartoPageState extends ConsumerState<RepartoPage> {
  DatosReparto? _datos;
  Object? _error;

  /// Bultos de la base de datos, más lo enviado desde esta pantalla.
  List<BultoReparto> _base = [];

  /// Lo que se muestra (el más reciente primero): los de la base de datos y las
  /// lecturas aún sin enviar. Todas las vistas usan esta misma lista (también
  /// la tienda abierta en otra pantalla) y se actualiza en el sitio.
  final List<BultoReparto> _bultos = [];

  StreamSubscription<ResultadoLectura>? _resultados;

  @override
  void initState() {
    super.initState();
    _resultados = ref.read(colaLecturasProvider.notifier).resultados.listen(_alResponder);
    _cargar();
  }

  @override
  void dispose() {
    _resultados?.cancel();
    super.dispose();
  }

  /// `silencioso`: si falla, se sigue con lo que hay en pantalla.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _error = null);
    try {
      final datos = await ref.read(repartidorRepositoryProvider).datosReparto(widget.reparto);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _base = datos.bultos;
        _recalcular();
      });
    } catch (e) {
      if (mounted && !silencioso) setState(() => _error = e);
    }
  }

  void _recalcular() {
    final pendientes = ref
        .read(colaLecturasProvider)
        .pendientes
        .where((l) => l.repartoId == widget.reparto.id);
    _bultos
      ..clear()
      ..addAll(aplicarLecturas(_base, pendientes));
  }

  /// La base de datos ha respondido a una lectura enviada en segundo plano.
  void _alResponder(ResultadoLectura r) {
    if (r.lectura.repartoId != widget.reparto.id || !mounted) return;
    final rechazo = r.rechazo;
    if (rechazo == null) {
      // Guardada: pasa a la base (la cola la quita justo después)
      _base = aplicarLecturas(_base, [r.lectura], enviadas: true);
      return;
    }
    vibrar(larga: true);
    mostrarMensaje(context, rechazo, error: true);
    unawaited(_cargar(silencioso: true));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(colaLecturasProvider, (_, _) => setState(_recalcular));
    final datos = _datos;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensajeError(_error!), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (datos == null) return const Center(child: CircularProgressIndicator());

    return widget.reparto.estado == 'carga'
        ? _VistaCarga(datos: datos, bultos: _bultos)
        : _VistaEnRuta(datos: datos, bultos: _bultos, alRecargar: _cargar);
  }
}

// =============================================================================
// Carga en la nave
// =============================================================================

class _VistaCarga extends ConsumerStatefulWidget {
  const _VistaCarga({required this.datos, required this.bultos});

  final DatosReparto datos;
  final List<BultoReparto> bultos;

  @override
  ConsumerState<_VistaCarga> createState() => _VistaCargaState();
}

class _VistaCargaState extends ConsumerState<_VistaCarga> {
  final _cola = ColaEscaneos();

  /// La cámara conserva su estado aunque cambie el diseño (teclado, espacio):
  /// reiniciarla en el navegador puede dejarla abierta pero sin leer.
  final _claveEscaner = GlobalKey();
  AvisoLectura? _aviso;
  bool _confirmando = false;

  RepartoActivo get _reparto => widget.datos.reparto;
  ColaLecturas get _envios => ref.read(colaLecturasProvider.notifier);

  void _avisar(AvisoLectura aviso) {
    vibrarSegun(aviso.tipo);
    if (mounted) setState(() => _aviso = aviso);
  }

  Future<void> _leido(LecturaCodigo lectura) => _cola.encolar(() => _cargarBulto(lectura));

  Future<void> _cargarBulto(LecturaCodigo lectura) async {
    final resultado = extraerIdConReglas(lectura.contenido, widget.datos.reglas);
    if (resultado case IdInvalido(:final motivo)) {
      _avisar(AvisoLectura('Código no válido. $motivo', TipoAviso.error));
      return;
    }
    final codigo = (resultado as IdValido).id;
    // Los duplicados se comprueban en el móvil (sin esperar a la conexión); si
    // otro reparto ya lo cargó, se avisa al enviarlo
    if (widget.bultos.any((b) => b.codigo == codigo)) {
      _avisar(AvisoLectura('DUPLICADO: $codigo ya está en tu carga', TipoAviso.aviso));
      return;
    }
    final total = widget.bultos.length + 1;
    _envios.agregar(
      tipo: TipoLectura.carga,
      repartoId: _reparto.id,
      codigo: codigo,
      formato: lectura.formato,
    );
    _avisar(AvisoLectura('Cargado $codigo · $total en total', TipoAviso.correcto));
  }

  Future<void> _quitar(BultoReparto b) async {
    if (!await confirmar(
      context,
      titulo: 'Quitar de la carga',
      mensaje: '¿Quitar el bulto ${b.codigo} de la carga? Úsalo si lo escaneaste por error.',
      accion: 'Quitar',
      peligroso: true,
    )) {
      return;
    }
    if (!mounted) return;
    final total = widget.bultos.length - 1;
    _envios.quitar(tipo: TipoLectura.quitarCarga, repartoId: _reparto.id, codigo: b.codigo);
    // La franja indica el nuevo total (si no, seguiría mostrando el último escaneo)
    setState(() => _aviso = AvisoLectura('Quitado ${b.codigo} · $total en total', TipoAviso.aviso));
  }

  Future<void> _terminar() async {
    final total = widget.bultos.length;
    if (total == 0) {
      mostrarMensaje(context, 'Escanea al menos un bulto antes de terminar.', error: true);
      return;
    }
    // Al terminar se envía todo lo pendiente: la carga no se confirma sin ello
    setState(() => _confirmando = true);
    final enviado = await enviarPendientes(context, ref, _reparto.id);
    if (!mounted) return;
    setState(() => _confirmando = false);
    if (!enviado) return;
    if (!await confirmar(
      context,
      titulo: 'Terminar la carga',
      mensaje:
          'Has cargado $total ${total == 1 ? 'bulto' : 'bultos'}.\n\n'
          '¿Es correcto? Después ya no podrás añadir más bultos a este reparto.',
      accion: 'Confirmar y salir',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _confirmando = true);
    final ok = await ejecutar(
      context,
      () => ref.read(repartidorRepositoryProvider).confirmarCarga(_reparto.id),
      exito: 'Carga confirmada: ${cantidad(total, 'bulto')}. ¡Buen reparto!',
    );
    if (!mounted) return;
    setState(() => _confirmando = false);
    if (ok) ref.invalidate(repartoAbiertoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escaner = VistaEscaner(
      key: _claveEscaner,
      formatos: formatosDeReglas(widget.datos.reglas),
      alLeer: _leido,
      aceptar: (v) => extraerIdConReglas(v, widget.datos.reglas) is IdValido,
    );
    final lista = _ListaBultos(
      titulo: 'Bultos cargados',
      bultos: widget.bultos,
      vacio: 'Aún no has escaneado ningún bulto.',
      alQuitar: _quitar,
    );
    final pie = _BarraAcciones(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _confirmando ? null : _terminar,
            icon: const Icon(Icons.local_shipping),
            label: Text('Terminar carga (${widget.bultos.length})'),
          ),
        ),
      ],
    );

    return _DisenoEscaneo(
      cabecera: _Cabecera(
        titulo: _reparto.titulo,
        detalle: 'Carga en la nave',
        ajustes: true,
        contador: widget.bultos.length,
        etiquetaContador: 'cargados',
        tema: tema,
      ),
      escaner: escaner,
      aviso: FranjaAviso(_aviso),
      lista: lista,
      entradaManual: EntradaManual(
        alEnviar: (t) => _leido(LecturaCodigo(t, null)),
        alLeerFoto: _leido,
        formatos: formatosDeReglas(widget.datos.reglas),
        aceptar: (v) => extraerIdConReglas(v, widget.datos.reglas) is IdValido,
      ),
      pie: pie,
    );
  }
}

// =============================================================================
// En ruta: tiendas de la salida y cierre
// =============================================================================

class _VistaEnRuta extends ConsumerStatefulWidget {
  const _VistaEnRuta({required this.datos, required this.bultos, required this.alRecargar});

  final DatosReparto datos;
  final List<BultoReparto> bultos;
  final Future<void> Function() alRecargar;

  @override
  ConsumerState<_VistaEnRuta> createState() => _VistaEnRutaState();
}

class _VistaEnRutaState extends ConsumerState<_VistaEnRuta> {
  /// Tienda abierta en el panel derecho (solo en el ordenador).
  TiendaReparto? _tienda;

  DatosReparto get datos => widget.datos;
  List<BultoReparto> get bultos => widget.bultos;

  /// En el móvil y la tablet la descarga se abre en otra pantalla; en el
  /// ordenador, en el panel derecho junto a la lista de tiendas.
  Future<void> _abrirTienda(TiendaReparto tienda) async {
    if (context.esPantallaEscritorio) {
      setState(() => _tienda = tienda);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntregaTiendaPage(datos: datos, tienda: tienda, bultos: bultos),
      ),
    );
  }

  /// Si a la franja (salida) le falta una tienda, el repartidor la añade a este
  /// reparto (solo a este) para poder entregar allí. El admin recibe el aviso y
  /// decide si la añade a la franja.
  Future<void> _anadirTiendaTemporal() async {
    final elegida = await mostrarPanel<TiendaElegible>(
      context,
      builder: (_) => _SelectorTiendaTemporal(
        excluir: {for (final t in datos.tiendas) t.id},
        deLaRuta: datos.deLaRuta,
      ),
    );
    if (elegida == null || !mounted) return;
    if (!await confirmar(
      context,
      titulo: 'Añadir ${elegida.nombre}',
      mensaje:
          'Se añadirá solo a este reparto, para que puedas entregar allí. '
          'Se avisará al administrador para que decida si la añade a esta franja.',
      accion: 'Añadir',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await ejecutar(
      context,
      () => ref
          .read(repartidorRepositoryProvider)
          .agregarTiendaTemporal(datos.reparto.id, elegida.id),
      exito: '${elegida.nombre} añadida. Se ha avisado al administrador.',
    );
    if (ok) await widget.alRecargar();
  }

  Future<void> _cerrar() async {
    // No se cierra con lecturas sin enviar: se perderían entregas
    if (!await enviarPendientes(context, ref, datos.reparto.id) || !mounted) return;
    final pendientes = bultos.where((b) => b.estado == 'cargado').length;
    final cierre = await showDialog<_Cierre>(
      context: context,
      builder: (_) => _DialogoCierre(pendientes: pendientes),
    );
    if (cierre == null || !mounted) return;
    final ok = await ejecutar(
      context,
      () => ref
          .read(repartidorRepositoryProvider)
          .cerrar(datos.reparto.id, forzoso: pendientes > 0, motivo: cierre.motivo),
      exito: pendientes == 0
          ? 'Reparto cerrado. ¡Todo entregado!'
          : 'Reparto cerrado con $pendientes ${pendientes == 1 ? 'bulto' : 'bultos'} sin entregar',
    );
    if (ok) {
      ref.invalidate(repartoAbiertoProvider);
      ref.invalidate(rutasRepartidorProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escritorio = context.esPantallaEscritorio;
    final tienda = escritorio ? _tienda : null;
    final total = bultos.where((b) => b.estado != 'devolucion').length;
    final entregados = bultos.where((b) => b.estado == 'entregado').length;
    final pendientes = bultos.where((b) => b.estado == 'cargado').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecera(
          titulo: datos.reparto.titulo,
          detalle: 'En ruta · $entregados de ${cantidad(total, 'entregado')}',
          ajustes: true,
          contador: pendientes,
          etiquetaContador: 'pendientes',
          tema: tema,
        ),
        LinearProgressIndicator(value: total == 0 ? 0 : entregados / total, minHeight: 6),
        Expanded(
          child: _ConPanel(
            panel: !escritorio
                ? null
                : tienda == null
                ? const ListaVacia('Elige una tienda para empezar a descargar.')
                : EntregaTiendaPage(
                    key: ValueKey(tienda.id),
                    datos: datos,
                    tienda: tienda,
                    bultos: bultos,
                    alTerminar: () => setState(() => _tienda = null),
                  ),
            child: RefreshIndicator(
              onRefresh: widget.alRecargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  Text(
                    'Elige la tienda en la que vas a descargar',
                    style: tema.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (datos.tiendas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Esta salida no tiene tiendas. Añade abajo la tienda en la que '
                        'tienes que entregar; se avisará al administrador.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final (i, t) in datos.tiendas.indexed)
                    _FilaTienda(
                      numero: i + 1,
                      tienda: t,
                      entregados: bultos
                          .where((b) => b.tiendaId == t.id && b.estado == 'entregado')
                          .length,
                      devoluciones: bultos
                          .where((b) => b.tiendaId == t.id && b.estado == 'devolucion')
                          .length,
                      seleccionada: t.id == tienda?.id,
                      alPulsar: () => _abrirTienda(t),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _anadirTiendaTemporal,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Añadir una tienda que no está en esta franja'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _BarraAcciones(
          children: [
            Expanded(
              child: pendientes == 0
                  ? FilledButton.icon(
                      onPressed: _cerrar,
                      icon: const Icon(Icons.flag),
                      label: const Text('Cerrar reparto'),
                    )
                  : OutlinedButton.icon(
                      onPressed: _cerrar,
                      icon: const Icon(Icons.flag_outlined),
                      label: Text('Cerrar reparto (${cantidad(pendientes, 'pendiente')})'),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilaTienda extends StatelessWidget {
  const _FilaTienda({
    required this.numero,
    required this.tienda,
    required this.entregados,
    required this.alPulsar,
    this.devoluciones = 0,
    this.seleccionada = false,
  });

  final int numero;
  final TiendaReparto tienda;
  final int entregados;
  final int devoluciones;
  final VoidCallback alPulsar;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        selected: seleccionada,
        leading: CircleAvatar(child: Text('$numero')),
        title: Text(tienda.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        // El recuento va bajo el nombre: a la derecha lo aplastaba en el móvil
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tienda.direccion?.isNotEmpty ?? false) Text(tienda.direccion!),
            if (tienda.temporal)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Etiqueta('Temporal · añadida por ti', color: ColoresEstado.aviso),
              ),
            if (entregados + devoluciones > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (entregados > 0)
                      Etiqueta(cantidad(entregados, 'entregado'), color: ColoresEstado.correcto),
                    if (devoluciones > 0)
                      Etiqueta(
                        cantidad(devoluciones, 'devolución', 'devoluciones'),
                        color: ColoresEstado.aviso,
                      ),
                  ],
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: alPulsar,
      ),
    );
  }
}

// =============================================================================
// Entrega en una tienda: escanear al descargar y foto
// =============================================================================

class EntregaTiendaPage extends ConsumerStatefulWidget {
  const EntregaTiendaPage({
    super.key,
    required this.datos,
    required this.tienda,
    required this.bultos,
    this.alTerminar,
  });

  final DatosReparto datos;
  final TiendaReparto tienda;

  /// Lista compartida con la pantalla del reparto (se actualiza en el sitio).
  final List<BultoReparto> bultos;

  /// Si se da, la vista va incrustada en un panel (ordenador): sin barra
  /// superior propia y «Terminar tienda» llama a esto en vez de volver atrás.
  final VoidCallback? alTerminar;

  @override
  ConsumerState<EntregaTiendaPage> createState() => _EntregaTiendaPageState();
}

class _EntregaTiendaPageState extends ConsumerState<EntregaTiendaPage> {
  final _cola = ColaEscaneos();

  /// La cámara conserva su estado aunque cambie el diseño (teclado, espacio):
  /// reiniciarla en el navegador puede dejarla abierta pero sin leer.
  final _claveEscaner = GlobalKey();
  AvisoLectura? _aviso;
  int _fotos = 0;
  bool _subiendoFoto = false;

  /// false: se escanean bultos para entregarlos. true: se escanean paquetes que
  /// la tienda da al repartidor para devolver.
  bool _devolucion = false;

  List<BultoReparto> _deEstaTienda(String estado) =>
      widget.bultos.where((b) => b.tiendaId == widget.tienda.id && b.estado == estado).toList();

  List<BultoReparto> get _entregadosAqui => _deEstaTienda('entregado');
  List<BultoReparto> get _devolucionesAqui => _deEstaTienda('devolucion');
  ColaLecturas get _envios => ref.read(colaLecturasProvider.notifier);

  void _avisar(AvisoLectura aviso) {
    vibrarSegun(aviso.tipo);
    if (mounted) setState(() => _aviso = aviso);
  }

  // El modo se fija al leer, por si se cambia mientras hay lecturas en cola
  Future<void> _leido(LecturaCodigo lectura) {
    final devolucion = _devolucion;
    return _cola.encolar(() => devolucion ? _recogerDevolucion(lectura) : _entregar(lectura));
  }

  /// ID del código según las reglas de los clientes, o null (ya avisado).
  String? _codigoValido(LecturaCodigo lectura) {
    final resultado = extraerIdConReglas(lectura.contenido, widget.datos.reglas);
    if (resultado case IdInvalido(:final motivo)) {
      _avisar(AvisoLectura('Código no válido. $motivo', TipoAviso.error));
      return null;
    }
    return (resultado as IdValido).id;
  }

  Future<void> _recogerDevolucion(LecturaCodigo lectura) async {
    final codigo = _codigoValido(lectura);
    if (codigo == null) return;
    final b = widget.bultos.where((b) => b.codigo == codigo).firstOrNull;
    if (b != null) {
      _avisar(
        AvisoLectura(
          b.estado == 'devolucion'
              ? 'DUPLICADO: $codigo ya está como devolución'
              : '$codigo es un bulto de tu carga, no una devolución',
          TipoAviso.aviso,
        ),
      );
      return;
    }
    final total = _devolucionesAqui.length + 1;
    _envios.agregar(
      tipo: TipoLectura.devolucion,
      repartoId: widget.datos.reparto.id,
      tiendaId: widget.tienda.id,
      codigo: codigo,
      formato: lectura.formato,
    );
    _avisar(AvisoLectura('Devolución $codigo · $total de esta tienda', TipoAviso.correcto));
  }

  Future<void> _quitarDevolucion(BultoReparto b) async {
    if (!await confirmar(
      context,
      titulo: 'Quitar devolución',
      mensaje: '¿Quitar ${b.codigo} de las devoluciones? Úsalo si lo escaneaste por error.',
      accion: 'Quitar',
      peligroso: true,
    )) {
      return;
    }
    if (!mounted) return;
    final total = _devolucionesAqui.length - 1;
    _envios.quitar(
      tipo: TipoLectura.quitarDevolucion,
      repartoId: widget.datos.reparto.id,
      codigo: b.codigo,
    );
    setState(
      () => _aviso = AvisoLectura('Quitada ${b.codigo} · $total de esta tienda', TipoAviso.aviso),
    );
  }

  /// Último recurso si ni la cámara ni la foto leen la etiqueta: se marca
  /// desde la lista del camión, con confirmación.
  Future<void> _entregarAMano(BultoReparto b) async {
    if (!await confirmar(
      context,
      titulo: 'Entregar sin escanear',
      mensaje:
          '¿Marcar ${b.codigo} como entregado en ${widget.tienda.nombre}?\n\n'
          'Úsalo solo si el lector no consigue leer la etiqueta. Comprueba que el '
          'código coincide con el del bulto.',
      accion: 'Marcar entregado',
    )) {
      return;
    }
    _cola.encolar(() => _entregar(LecturaCodigo(b.codigo, null)));
  }

  Future<void> _entregar(LecturaCodigo lectura) async {
    final codigo = _codigoValido(lectura);
    if (codigo == null) return;
    // Se comprueba con la carga que hay en el móvil, sin esperar a la conexión
    final b = widget.bultos.where((b) => b.codigo == codigo).firstOrNull;
    switch (b?.estado) {
      case null:
        _avisar(AvisoLectura('$codigo no está en tu carga', TipoAviso.error));
      case 'devolucion':
        _avisar(
          AvisoLectura('$codigo es una devolución, no un bulto de tu carga', TipoAviso.aviso),
        );
      case 'cargado':
        final total = _entregadosAqui.length + 1;
        _envios.agregar(
          tipo: TipoLectura.entrega,
          repartoId: widget.datos.reparto.id,
          tiendaId: widget.tienda.id,
          codigo: codigo,
        );
        _avisar(AvisoLectura('Entregado $codigo · $total en esta tienda', TipoAviso.correcto));
      default:
        final otra = b!.tiendaId;
        final nombreOtra = widget.datos.tiendas.where((t) => t.id == otra).firstOrNull?.nombre;
        _avisar(
          AvisoLectura(
            otra == widget.tienda.id || nombreOtra == null
                ? 'DUPLICADO: $codigo ya estaba entregado aquí'
                : '$codigo ya se entregó en $nombreOtra',
            TipoAviso.aviso,
          ),
        );
    }
  }

  Future<void> _foto() async {
    final XFile? foto;
    try {
      foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 70,
      );
    } catch (_) {
      if (mounted) mostrarMensaje(context, 'No se pudo abrir la cámara.', error: true);
      return;
    }
    if (foto == null || !mounted) return;
    setState(() => _subiendoFoto = true);
    final ok = await ejecutar(
      context,
      () => ref
          .read(repartidorRepositoryProvider)
          .subirFoto(
            repartoId: widget.datos.reparto.id,
            tiendaId: widget.tienda.id,
            foto: foto!,
            numBultos: _entregadosAqui.length,
          ),
      exito: 'Foto de entrega guardada',
    );
    if (!mounted) return;
    setState(() {
      _subiendoFoto = false;
      if (ok) _fotos++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // En el móvil esta pantalla va aparte: se redibuja cuando cambia la cola
    ref.watch(colaLecturasProvider);
    final tema = Theme.of(context);
    final entregadosAqui = _entregadosAqui;
    final devolucionesAqui = _devolucionesAqui;
    final pendientes = widget.bultos.where((b) => b.estado == 'cargado').length;

    final incrustada = widget.alTerminar != null;
    final contenido = _DisenoEscaneo(
      cabecera: _Cabecera(
        // En pantalla propia el nombre de la tienda ya está en la barra superior
        titulo: incrustada ? widget.tienda.nombre : widget.datos.reparto.titulo,
        detalle: 'Descarga · ${pendientes == 1 ? 'queda' : 'quedan'} $pendientes en el camión',
        contador: _devolucion ? devolucionesAqui.length : entregadosAqui.length,
        etiquetaContador: _devolucion ? 'devoluciones aquí' : 'entregados aquí',
        tema: tema,
      ),
      modo: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.download_done),
              label: Text('Entregar (${entregadosAqui.length})'),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.assignment_return_outlined),
              label: Text('Devoluciones (${devolucionesAqui.length})'),
            ),
          ],
          selected: {_devolucion},
          onSelectionChanged: (s) => setState(() {
            _devolucion = s.first;
            _aviso = null;
          }),
        ),
      ),
      escaner: VistaEscaner(
        key: _claveEscaner,
        formatos: formatosDeReglas(widget.datos.reglas),
        alLeer: _leido,
        aceptar: (v) => extraerIdConReglas(v, widget.datos.reglas) is IdValido,
      ),
      aviso: FranjaAviso(_aviso),
      lista: _devolucion
          ? _ListaBultos(
              key: const ValueKey('devoluciones'),
              titulo: 'Devoluciones de esta tienda',
              bultos: devolucionesAqui,
              vacio:
                  'Escanea aquí los paquetes que la tienda te da para devolver. '
                  'Quedarán marcados como devolución (amarillo).',
              alQuitar: _quitarDevolucion,
              textoQuitar: 'Quitar de devoluciones',
            )
          : _ListaEntrega(
              key: const ValueKey('entregados'),
              entregados: entregadosAqui,
              enCamion: widget.bultos.where((b) => b.estado == 'cargado').toList(),
              alEntregarAMano: _entregarAMano,
            ),
      entradaManual: EntradaManual(
        alEnviar: (t) => _leido(LecturaCodigo(t, null)),
        alLeerFoto: _leido,
        formatos: formatosDeReglas(widget.datos.reglas),
        aceptar: (v) => extraerIdConReglas(v, widget.datos.reglas) is IdValido,
      ),
      pie: _BarraAcciones(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _subiendoFoto ? null : _foto,
              icon: _subiendoFoto
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera),
              label: Text(_fotos == 0 ? 'Foto de entrega' : 'Otra foto ($_fotos)'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: widget.alTerminar ?? () => Navigator.pop(context),
              icon: const Icon(Icons.done),
              label: const Text('Terminar tienda'),
            ),
          ),
        ],
      ),
    );
    if (incrustada) return contenido;
    return Scaffold(
      appBar: AppBar(title: Text(widget.tienda.nombre)),
      body: SafeArea(child: contenido),
    );
  }
}

/// Lista con un panel de detalle a la derecha (ordenador). Sin panel, solo la lista.
class _ConPanel extends StatelessWidget {
  const _ConPanel({required this.child, this.panel});

  final Widget child;
  final Widget? panel;

  @override
  Widget build(BuildContext context) {
    if (panel == null) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 380, child: child),
        const VerticalDivider(width: 1),
        Expanded(child: panel!),
      ],
    );
  }
}

// =============================================================================
// Cierre del reparto
// =============================================================================

class _Cierre {
  const _Cierre({this.motivo});

  final String? motivo;
}

/// Cierre normal (todo entregado) o forzoso, con aviso claro, motivo y
/// confirmación expresa para evitar cierres por error.
class _DialogoCierre extends StatefulWidget {
  const _DialogoCierre({required this.pendientes});

  final int pendientes;

  @override
  State<_DialogoCierre> createState() => _DialogoCierreState();
}

class _DialogoCierreState extends State<_DialogoCierre> {
  final _motivo = TextEditingController();
  bool _entendido = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final n = widget.pendientes;

    if (n == 0) {
      return AlertDialog(
        title: const Text('Cerrar reparto'),
        content: const Text('Todos los bultos están entregados. ¿Cerrar el reparto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, const _Cierre()),
            child: const Text('Cerrar reparto'),
          ),
        ],
      );
    }

    final puedeCerrar = _entendido && _motivo.text.trim().isNotEmpty;
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: ColoresEstado.peligro, size: 40),
      title: Text('${n == 1 ? 'Queda' : 'Quedan'} ${cantidad(n, 'bulto')} sin entregar'),
      scrollable: true,
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Si cierras ahora, ${n == 1 ? 'ese bulto quedará marcado' : 'esos bultos quedarán marcados'} '
              'como «${textoEstadoBulto('no_entregado')}» (rojo) y el cliente lo verá. '
              'Revisa el camión antes de continuar.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motivo,
              decoration: const InputDecoration(
                labelText: 'Motivo (obligatorio)',
                hintText: 'Ej. tienda cerrada, bulto dañado…',
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _entendido,
              onChanged: (v) => setState(() => _entendido = v ?? false),
              title: Text(
                'Confirmo que ${n == 1 ? 'queda' : 'quedan'} ${cantidad(n, 'bulto')} sin entregar',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ColoresEstado.peligro),
          onPressed: puedeCerrar
              ? () => Navigator.pop(context, _Cierre(motivo: _motivo.text.trim()))
              : null,
          child: const Text('Cerrar con pendientes'),
        ),
      ],
    );
  }
}

// =============================================================================
// Piezas comunes
// =============================================================================

/// Escáner arriba y lista debajo en el móvil; lado a lado en pantallas anchas.
class _DisenoEscaneo extends StatelessWidget {
  const _DisenoEscaneo({
    required this.cabecera,
    required this.escaner,
    required this.aviso,
    required this.lista,
    required this.entradaManual,
    required this.pie,
    this.modo,
  });

  /// Selector opcional bajo la cabecera (p. ej. entregar / devoluciones).
  final Widget? modo;
  final Widget cabecera;
  final Widget escaner;
  final Widget aviso;
  final Widget lista;
  final Widget entradaManual;
  final Widget pie;

  /// Ancho mínimo para poner cámara y lista lado a lado (cada una con sitio).
  static const anchoDosColumnas = 720.0;

  /// Altura de cabecera, selector, campo y botones de abajo (aprox.) más un
  /// mínimo para la lista: lo que debe caber además de la cámara.
  static const alturaResto = 440.0;

  /// Cámara y lista cuando se desplazan juntas (pantallas bajas).
  static const alturaCamaraCompacta = 200.0;
  static const alturaListaCompacta = 260.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // Se decide por el espacio que tiene (en el ordenador puede ir en un panel
    // estrecho), no por el tamaño de la pantalla
    // (con poca altura, p. ej. un móvil girado, una columna que se desplaza)
    builder: (context, restricciones) =>
        restricciones.maxWidth >= anchoDosColumnas && restricciones.maxHeight >= alturaResto + 80
        ? _dosColumnas()
        : _unaColumna(context, restricciones.maxHeight),
  );

  Widget _dosColumnas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cabecera,
        ?modo,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: escaner),
                    aviso,
                    entradaManual,
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: lista),
            ],
          ),
        ),
        pie,
      ],
    );
  }

  /// Una columna (móvil o panel estrecho). Con el teclado abierto se oculta la
  /// cámara. Si falta altura, cámara y lista se desplazan juntas: el campo del
  /// código y los botones de abajo quedan siempre fijos y a la vista.
  Widget _unaColumna(BuildContext context, double alto) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom > 0;
    final alturaCamara = (alto * 0.34).clamp(180.0, 340.0);
    final cabe = alto - alturaCamara >= alturaResto;

    // Con el teclado abierto la cámara se oculta, pero sigue montada: así no se
    // reinicia al cerrarlo
    Widget camara(double altura) => Offstage(
      offstage: teclado,
      child: SizedBox(height: altura, child: escaner),
    );

    final Widget centro = cabe || teclado
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?modo,
              camara(alturaCamara),
              aviso,
              Expanded(child: lista),
            ],
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?modo,
                camara(alturaCamaraCompacta),
                aviso,
                SizedBox(height: alturaListaCompacta, child: lista),
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cabecera,
        Expanded(child: centro),
        entradaManual,
        pie,
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.titulo,
    required this.detalle,
    required this.contador,
    required this.etiquetaContador,
    required this.tema,
    this.ajustes = false,
  });

  final String titulo;
  final String detalle;
  final int contador;
  final String etiquetaContador;
  final ThemeData tema;

  /// Muestra el botón de ajustes (cerrar sesión) a la izquierda del recuento.
  final bool ajustes;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tema.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: tema.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(detalle, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$contador',
                      style: tema.textTheme.headlineMedium?.copyWith(
                        color: tema.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(etiquetaContador, style: tema.textTheme.bodySmall),
                  ],
                ),
                if (ajustes) ...[const SizedBox(width: 4), const BotonAjustes()],
              ],
            ),
          ),
          const _EstadoEnvios(),
        ],
      ),
    );
  }
}

/// Franja con las lecturas guardadas en el móvil que aún no han llegado a la
/// base de datos. No se ve si está todo enviado.
class _EstadoEnvios extends ConsumerWidget {
  const _EstadoEnvios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cola = ref.watch(colaLecturasProvider);
    final n = cola.pendientes.length;
    if (n == 0) return const SizedBox.shrink();
    final texto = cola.sinConexion
        ? '${cantidad(n, 'lectura')} sin enviar · sin conexión. Se enviarán solas, '
              'puedes seguir escaneando.'
        : 'Enviando ${cantidad(n, 'lectura')}…';
    return Material(
      color: ColoresEstado.aviso.withValues(alpha: cola.sinConexion ? 0.18 : 0.08),
      child: InkWell(
        onTap: () => unawaited(ref.read(colaLecturasProvider.notifier).enviarAhora()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              Icon(
                cola.sinConexion ? Icons.cloud_off_outlined : Icons.cloud_upload_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Envía ya las lecturas pendientes del reparto (al terminar la carga o cerrar).
/// Devuelve false, con un aviso, si no se ha podido enviar todo.
Future<bool> enviarPendientes(BuildContext context, WidgetRef ref, String repartoId) async {
  if (ref.read(colaLecturasProvider).pendientesDe(repartoId) == 0) return true;
  final cola = ref.read(colaLecturasProvider.notifier);
  await cola.enviarAhora();
  final quedan = ref.read(colaLecturasProvider).pendientesDe(repartoId);
  if (quedan == 0) return true;
  if (context.mounted) {
    mostrarMensaje(
      context,
      'Faltan ${cantidad(quedan, 'lectura')} por enviar y ahora no hay conexión. '
      'Se enviarán solas en cuanto la haya; inténtalo de nuevo en un momento.',
      error: true,
    );
  }
  return false;
}

class _ListaBultos extends StatelessWidget {
  const _ListaBultos({
    super.key,
    required this.titulo,
    required this.bultos,
    required this.vacio,
    this.alQuitar,
    this.textoQuitar = 'Quitar de la carga',
  });

  final String titulo;
  final List<BultoReparto> bultos;
  final String vacio;
  final void Function(BultoReparto)? alQuitar;
  final String textoQuitar;

  @override
  Widget build(BuildContext context) {
    if (bultos.isEmpty) return ListaVacia(vacio);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: bultos.length + 1,
      separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '$titulo (${bultos.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          );
        }
        final b = bultos[i - 1];
        return ListTile(
          dense: true,
          leading: _IconoBulto(b),
          title: Text(
            b.codigo,
            style: const TextStyle(fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          subtitle: Text(_hora(b)),
          trailing: alQuitar == null
              ? EtiquetaBulto(b.estado)
              : IconButton(
                  tooltip: textoQuitar,
                  icon: const Icon(Icons.undo),
                  onPressed: () => alQuitar!(b),
                ),
        );
      },
    );
  }
}

/// Hora del bulto y, si aún no ha llegado a la base de datos, «sin enviar».
String _hora(BultoReparto b) {
  final hora = fechaHora(b.entregadoEn ?? b.cargadoEn).substring(11);
  return b.sinEnviar ? '$hora · sin enviar' : hora;
}

class _IconoBulto extends StatelessWidget {
  const _IconoBulto(this.bulto);

  final BultoReparto bulto;

  @override
  Widget build(BuildContext context) => bulto.sinEnviar
      ? const Tooltip(
          message: 'Guardado en el móvil, pendiente de enviar',
          child: Icon(Icons.cloud_upload_outlined, color: ColoresEstado.aviso),
        )
      : const Icon(Icons.inventory_2_outlined);
}

/// Buscador de tiendas para añadir temporalmente al reparto.
class _SelectorTiendaTemporal extends ConsumerStatefulWidget {
  const _SelectorTiendaTemporal({required this.excluir, required this.deLaRuta});

  final Set<String> excluir;
  final Set<String> deLaRuta;

  @override
  ConsumerState<_SelectorTiendaTemporal> createState() => _SelectorTiendaTemporalState();
}

class _SelectorTiendaTemporalState extends ConsumerState<_SelectorTiendaTemporal> {
  late final _tiendas = ref.read(repartidorRepositoryProvider).tiendasElegibles(widget.excluir);
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿En qué tienda tienes que entregar?', style: tema.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Solo para este reparto. El administrador decidirá si la añade a la franja.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar tienda',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = normalizarBusqueda(v)),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: FutureBuilder(
                future: _tiendas,
                builder: (context, estado) {
                  if (estado.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(mensajeError(estado.error!)),
                    );
                  }
                  final tiendas = estado.data;
                  if (tiendas == null) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final filtradas = [
                    for (final t in tiendas)
                      if (_busqueda.isEmpty ||
                          coincideBusqueda(t.nombre, _busqueda) ||
                          coincideBusqueda(t.direccion, _busqueda))
                        t,
                  ];
                  if (filtradas.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay tiendas con ese nombre.'),
                    );
                  }
                  final deLaRuta = [
                    for (final t in filtradas)
                      if (widget.deLaRuta.contains(t.id)) t,
                  ];
                  final otras = [
                    for (final t in filtradas)
                      if (!widget.deLaRuta.contains(t.id)) t,
                  ];
                  Widget titulo(String texto) => Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: Text(texto, style: tema.textTheme.titleSmall),
                  );
                  Widget fila(TiendaElegible t) => ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(t.nombre),
                    subtitle: (t.direccion?.isNotEmpty ?? false) ? Text(t.direccion!) : null,
                    onTap: () => Navigator.pop(context, t),
                  );
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      if (deLaRuta.isNotEmpty) ...[
                        titulo('De esta ruta, en otras franjas'),
                        for (final t in deLaRuta) fila(t),
                      ],
                      if (otras.isNotEmpty) ...[
                        titulo(deLaRuta.isEmpty ? 'Tiendas' : 'Otras tiendas'),
                        for (final t in otras) fila(t),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de la entrega en una tienda: lo entregado aquí y, debajo, lo que
/// queda en el camión con un botón para entregarlo a mano si no se puede leer.
class _ListaEntrega extends StatelessWidget {
  const _ListaEntrega({
    super.key,
    required this.entregados,
    required this.enCamion,
    required this.alEntregarAMano,
  });

  final List<BultoReparto> entregados;
  final List<BultoReparto> enCamion;
  final void Function(BultoReparto) alEntregarAMano;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget titulo(String texto) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(texto, style: tema.textTheme.titleSmall),
    );
    Widget fila(BultoReparto b, Widget final_) => ListTile(
      dense: true,
      leading: _IconoBulto(b),
      title: Text(
        b.codigo,
        style: const TextStyle(fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]),
      ),
      subtitle: Text(_hora(b)),
      trailing: final_,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        titulo('Entregados en esta tienda (${entregados.length})'),
        if (entregados.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Escanea cada bulto al descargarlo para marcarlo como entregado.'),
          ),
        for (final b in entregados) fila(b, EtiquetaBulto(b.estado)),
        if (enCamion.isNotEmpty) ...[
          const Divider(height: 24),
          titulo('Quedan en el camión (${enCamion.length})'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Si una etiqueta no se puede leer ni con foto, márcala aquí.',
              style: tema.textTheme.bodySmall,
            ),
          ),
          for (final b in enCamion)
            fila(b, TextButton(onPressed: () => alEntregarAMano(b), child: const Text('Entregar'))),
        ],
      ],
    );
  }
}

/// Barra inferior de acciones. Deja margen a la derecha para que la etiqueta
/// de Netlify (si alguien no la ha ocultado) no tape un botón.
class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    const alto = Size.fromHeight(52);
    const texto = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    return Material(
      elevation: 4,
      color: tema.colorScheme.surface,
      child: Theme(
        // Botones altos y con texto grande: se pulsan bien con una mano
        data: tema.copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: alto, textStyle: texto),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(minimumSize: alto, textStyle: texto),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 44),
          child: Row(children: children),
        ),
      ),
    );
  }
}
