import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/codigos.dart';
import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../shared/escaner.dart';
import '../../shared/estados.dart';
import '../../shared/panel_scaffold.dart';
import '../../shared/responsive.dart';
import '../../shared/ui.dart';
import 'aviso_lectura.dart';
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

  /// Bultos del reparto, el más reciente primero. Se actualiza en local con
  /// cada escaneo para no recargar todo.
  List<BultoReparto> _bultos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final datos = await ref.read(repartidorRepositoryProvider).datosReparto(widget.reparto);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _bultos = [...datos.bultos];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _actualizar(void Function(List<BultoReparto> bultos) cambio) =>
      setState(() => cambio(_bultos));

  @override
  Widget build(BuildContext context) {
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
        ? _VistaCarga(datos: datos, bultos: _bultos, alCambiar: _actualizar)
        : _VistaEnRuta(datos: datos, bultos: _bultos, alCambiar: _actualizar, alRecargar: _cargar);
  }
}

// =============================================================================
// Carga en la nave
// =============================================================================

class _VistaCarga extends ConsumerStatefulWidget {
  const _VistaCarga({required this.datos, required this.bultos, required this.alCambiar});

  final DatosReparto datos;
  final List<BultoReparto> bultos;
  final void Function(void Function(List<BultoReparto>)) alCambiar;

  @override
  ConsumerState<_VistaCarga> createState() => _VistaCargaState();
}

class _VistaCargaState extends ConsumerState<_VistaCarga> {
  final _cola = ColaEscaneos();
  AvisoLectura? _aviso;
  bool _confirmando = false;

  RepartoActivo get _reparto => widget.datos.reparto;

  void _avisar(AvisoLectura aviso) {
    vibrarSegun(aviso.tipo);
    if (mounted) setState(() => _aviso = aviso);
  }

  void _leido(LecturaCodigo lectura) => _cola.encolar(() => _cargarBulto(lectura));

  Future<void> _cargarBulto(LecturaCodigo lectura) async {
    final resultado = extraerIdConReglas(lectura.contenido, widget.datos.reglas);
    if (resultado case IdInvalido(:final motivo)) {
      _avisar(AvisoLectura('Código no válido. $motivo', TipoAviso.error));
      return;
    }
    final codigo = (resultado as IdValido).id;
    try {
      final respuesta = await ref
          .read(repartidorRepositoryProvider)
          .escanearCarga(_reparto.id, codigo, lectura.formato);
      switch (respuesta) {
        case 'ok':
          widget.alCambiar(
            (b) => b.insert(
              0,
              BultoReparto(
                id: codigo,
                codigo: codigo,
                estado: 'cargado',
                cargadoEn: DateTime.now(),
              ),
            ),
          );
          _avisar(
            AvisoLectura('Cargado $codigo · ${widget.bultos.length} en total', TipoAviso.correcto),
          );
        case 'duplicado':
          _avisar(AvisoLectura('DUPLICADO: $codigo ya está en tu carga', TipoAviso.aviso));
        default:
          _avisar(AvisoLectura('$codigo ya lo cargó hoy otro reparto', TipoAviso.error));
      }
    } catch (e) {
      _avisar(AvisoLectura(mensajeError(e), TipoAviso.error));
    }
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
    final ok = await ejecutar(
      context,
      () => ref.read(repartidorRepositoryProvider).quitarDeCarga(_reparto.id, b.codigo),
    );
    if (!ok) return;
    widget.alCambiar((lista) => lista.removeWhere((x) => x.codigo == b.codigo));
    // La franja indica el nuevo total (si no, seguiría mostrando el último escaneo)
    if (mounted) {
      setState(
        () => _aviso = AvisoLectura(
          'Quitado ${b.codigo} · ${widget.bultos.length} en total',
          TipoAviso.aviso,
        ),
      );
    }
  }

  Future<void> _terminar() async {
    final total = widget.bultos.length;
    if (total == 0) {
      mostrarMensaje(context, 'Escanea al menos un bulto antes de terminar.', error: true);
      return;
    }
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
      formatos: formatosDeReglas(widget.datos.reglas),
      alLeer: _leido,
      disparoUnico: true,
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
      entradaManual: EntradaManual(alEnviar: (t) => _leido(LecturaCodigo(t, null))),
      pie: pie,
    );
  }
}

// =============================================================================
// En ruta: tiendas de la salida y cierre
// =============================================================================

class _VistaEnRuta extends ConsumerStatefulWidget {
  const _VistaEnRuta({
    required this.datos,
    required this.bultos,
    required this.alCambiar,
    required this.alRecargar,
  });

  final DatosReparto datos;
  final List<BultoReparto> bultos;
  final void Function(void Function(List<BultoReparto>)) alCambiar;
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
        builder: (_) => EntregaTiendaPage(
          datos: datos,
          tienda: tienda,
          bultos: bultos,
          alCambiar: widget.alCambiar,
        ),
      ),
    );
  }

  Future<void> _cerrar() async {
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
                    alCambiar: widget.alCambiar,
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
                    const ListaVacia('Esta ruta no tiene tiendas. Avisa al administrador.'),
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
        subtitle: (tienda.direccion?.isNotEmpty ?? false) ? Text(tienda.direccion!) : null,
        trailing: entregados + devoluciones == 0
            ? const Icon(Icons.chevron_right)
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
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
    required this.alCambiar,
    this.alTerminar,
  });

  final DatosReparto datos;
  final TiendaReparto tienda;
  final List<BultoReparto> bultos;
  final void Function(void Function(List<BultoReparto>)) alCambiar;

  /// Si se da, la vista va incrustada en un panel (ordenador): sin barra
  /// superior propia y «Terminar tienda» llama a esto en vez de volver atrás.
  final VoidCallback? alTerminar;

  @override
  ConsumerState<EntregaTiendaPage> createState() => _EntregaTiendaPageState();
}

class _EntregaTiendaPageState extends ConsumerState<EntregaTiendaPage> {
  final _cola = ColaEscaneos();
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

  void _avisar(AvisoLectura aviso) {
    vibrarSegun(aviso.tipo);
    if (mounted) setState(() => _aviso = aviso);
  }

  // El modo se fija al leer, por si se cambia mientras hay lecturas en cola
  void _leido(LecturaCodigo lectura) {
    final devolucion = _devolucion;
    _cola.encolar(() => devolucion ? _recogerDevolucion(lectura) : _entregar(lectura));
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
    try {
      final respuesta = await ref
          .read(repartidorRepositoryProvider)
          .escanearDevolucion(widget.datos.reparto.id, widget.tienda.id, codigo, lectura.formato);
      switch (respuesta) {
        case 'ok':
          widget.alCambiar(
            (lista) => lista.insert(
              0,
              BultoReparto(
                id: codigo,
                codigo: codigo,
                estado: 'devolucion',
                tiendaId: widget.tienda.id,
                cargadoEn: DateTime.now(),
              ),
            ),
          );
          _avisar(
            AvisoLectura(
              'Devolución $codigo · ${_devolucionesAqui.length} de esta tienda',
              TipoAviso.correcto,
            ),
          );
        case 'duplicado':
          final b = widget.bultos.where((b) => b.codigo == codigo).firstOrNull;
          _avisar(
            AvisoLectura(
              b?.estado == 'devolucion'
                  ? 'DUPLICADO: $codigo ya está como devolución'
                  : '$codigo es un bulto de tu carga, no una devolución',
              TipoAviso.aviso,
            ),
          );
        default:
          _avisar(AvisoLectura('$codigo ya se registró hoy en otro reparto', TipoAviso.error));
      }
      if (mounted) setState(() {});
    } catch (e) {
      _avisar(AvisoLectura(mensajeError(e), TipoAviso.error));
    }
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
    final ok = await ejecutar(
      context,
      () => ref
          .read(repartidorRepositoryProvider)
          .quitarDevolucion(widget.datos.reparto.id, b.codigo),
    );
    if (!ok) return;
    widget.alCambiar(
      (lista) => lista.removeWhere((x) => x.codigo == b.codigo && x.estado == 'devolucion'),
    );
    if (mounted) {
      setState(
        () => _aviso = AvisoLectura(
          'Quitada ${b.codigo} · ${_devolucionesAqui.length} de esta tienda',
          TipoAviso.aviso,
        ),
      );
    }
  }

  Future<void> _entregar(LecturaCodigo lectura) async {
    final codigo = _codigoValido(lectura);
    if (codigo == null) return;
    try {
      final respuesta = await ref
          .read(repartidorRepositoryProvider)
          .escanearEntrega(widget.datos.reparto.id, widget.tienda.id, codigo);
      switch (respuesta) {
        case 'ok':
          widget.alCambiar((lista) {
            final i = lista.indexWhere((b) => b.codigo == codigo);
            final nuevo = BultoReparto(
              id: i >= 0 ? lista[i].id : codigo,
              codigo: codigo,
              estado: 'entregado',
              tiendaId: widget.tienda.id,
              cargadoEn: i >= 0 ? lista[i].cargadoEn : DateTime.now(),
              entregadoEn: DateTime.now(),
            );
            if (i >= 0) lista.removeAt(i);
            lista.insert(0, nuevo);
          });
          _avisar(
            AvisoLectura(
              'Entregado $codigo · ${_entregadosAqui.length} en esta tienda',
              TipoAviso.correcto,
            ),
          );
        case 'ya_entregado':
          final otra = widget.bultos.where((b) => b.codigo == codigo).firstOrNull?.tiendaId;
          final nombreOtra = widget.datos.tiendas.where((t) => t.id == otra).firstOrNull?.nombre;
          _avisar(
            AvisoLectura(
              otra == widget.tienda.id || nombreOtra == null
                  ? 'DUPLICADO: $codigo ya estaba entregado aquí'
                  : '$codigo ya se entregó en $nombreOtra',
              TipoAviso.aviso,
            ),
          );
        default:
          _avisar(AvisoLectura('$codigo no está en tu carga', TipoAviso.error));
      }
      if (mounted) setState(() {});
    } catch (e) {
      _avisar(AvisoLectura(mensajeError(e), TipoAviso.error));
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
        formatos: formatosDeReglas(widget.datos.reglas),
        alLeer: _leido,
        disparoUnico: true,
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
          : _ListaBultos(
              key: const ValueKey('entregados'),
              titulo: 'Entregados en esta tienda',
              bultos: entregadosAqui,
              vacio: 'Escanea cada bulto al descargarlo para marcarlo como entregado.',
            ),
      entradaManual: EntradaManual(alEnviar: (t) => _leido(LecturaCodigo(t, null))),
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

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.sizeOf(context);
    if (!context.esPantallaMovil) {
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
    // Con el teclado abierto (código a mano) o poca altura, la cámara se oculta
    // para que la lista, el campo y los botones de abajo nunca se pierdan.
    final teclado = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(
      builder: (context, restricciones) {
        final conCamara = !teclado && restricciones.maxHeight >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cabecera,
            ?modo,
            if (conCamara)
              SizedBox(height: (tamano.height * 0.34).clamp(200.0, 340.0), child: escaner),
            aviso,
            Expanded(child: lista),
            entradaManual,
            pie,
          ],
        );
      },
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: tema.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
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
    );
  }
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
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(
            b.codigo,
            style: const TextStyle(fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          subtitle: Text(fechaHora(b.entregadoEn ?? b.cargadoEn).substring(11)),
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
