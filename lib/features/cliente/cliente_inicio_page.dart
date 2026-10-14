import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../shared/estados.dart';
import '../../shared/responsive.dart';
import '../../shared/ui.dart';
import 'datos/cliente_repository.dart';
import '../../shared/avisos_cambios.dart';

/// Periodos rápidos del filtro de fecha.
enum Periodo {
  hoy('Hoy'),
  ayer('Ayer'),
  semana('7 días'),
  quincena('14 días'),
  rango('Elegir fechas');

  const Periodo(this.texto);

  final String texto;
}

/// Bultos entregados (o no) en las tiendas del cliente, con búsqueda por
/// fecha, ruta, tienda, estado y código, para atender reclamaciones.
class ClienteInicioPage extends ConsumerStatefulWidget {
  const ClienteInicioPage({super.key});

  @override
  ConsumerState<ClienteInicioPage> createState() => _ClienteInicioPageState();
}

class _ClienteInicioPageState extends ConsumerState<ClienteInicioPage> {
  Periodo _periodo = Periodo.hoy;
  DateTimeRange? _rango;
  String? _rutaId;
  String? _tiendaId;
  String? _estado;
  String _codigo = '';
  Timer? _espera;

  /// Bulto abierto en el panel de detalle (solo en el ordenador).
  BultoCliente? _seleccionado;

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  FiltroBultos get _filtro {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final manana = inicioHoy.add(const Duration(days: 1));
    final (desde, hasta) = switch (_periodo) {
      Periodo.hoy => (inicioHoy, manana),
      Periodo.ayer => (inicioHoy.subtract(const Duration(days: 1)), inicioHoy),
      Periodo.semana => (inicioHoy.subtract(const Duration(days: 6)), manana),
      Periodo.quincena => (inicioHoy.subtract(const Duration(days: 13)), manana),
      Periodo.rango => (
        _rango?.start ?? inicioHoy,
        (_rango?.end ?? inicioHoy).add(const Duration(days: 1)),
      ),
    };
    return (
      desde: desde,
      hasta: hasta,
      rutaId: _rutaId,
      tiendaId: _tiendaId,
      estado: _estado,
      codigo: _codigo,
    );
  }

  Future<void> _elegirPeriodo(Periodo p) async {
    if (p != Periodo.rango) {
      setState(() => _periodo = p);
      return;
    }
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: hoy.subtract(const Duration(days: 60)),
      lastDate: hoy,
      initialDateRange: _rango,
      helpText: 'Elige las fechas',
    );
    if (rango == null) return;
    setState(() {
      _periodo = Periodo.rango;
      _rango = rango;
    });
  }

  void _buscarCodigo(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _codigo = texto.replaceAll(RegExp(r'\D'), ''));
    });
  }

  /// En el ordenador el detalle se abre en el panel derecho, como en una app de
  /// escritorio; en móvil y tablet, en una ventana emergente.
  void _verBulto(BultoCliente b) {
    if (context.esPantallaEscritorio) {
      setState(() => _seleccionado = b);
    } else {
      mostrarPanel<void>(context, builder: (_) => _DetalleBulto(bulto: b));
    }
  }

  List<TiendaCliente> _tiendasDeRuta(List<TiendaCliente> tiendas) => _rutaId == null
      ? tiendas
      : tiendas.where((t) => t.rutas.any((r) => r.id == _rutaId)).toList();

  /// Ruta, tienda y estado. Se usan en la barra (tablet y escritorio) y en el
  /// panel de filtros (móvil). `alCambiar` permite refrescar ese panel.
  List<Widget> _desplegables(List<TiendaCliente> tiendas, VoidCallback alCambiar) {
    final rutas = {
      for (final t in tiendas)
        for (final r in t.rutas) r.id: r.nombre,
    }.entries.toList()..sort((a, b) => compararNatural(a.value, b.value));
    final tiendasFiltradas = _tiendasDeRuta(tiendas);
    final expandido = context.esPantallaMovil;

    void cambiar(VoidCallback cambio) {
      setState(cambio);
      alCambiar();
    }

    return [
      DropdownButton<String?>(
        value: _rutaId,
        isExpanded: expandido,
        hint: const Text('Todas las rutas'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todas las rutas')),
          for (final r in rutas) DropdownMenuItem(value: r.key, child: Text(r.value)),
        ],
        onChanged: (v) => cambiar(() {
          _rutaId = v;
          if (_tiendaId != null && !_tiendasDeRuta(tiendas).any((t) => t.id == _tiendaId)) {
            _tiendaId = null;
          }
        }),
      ),
      DropdownButton<String?>(
        value: tiendasFiltradas.any((t) => t.id == _tiendaId) ? _tiendaId : null,
        isExpanded: expandido,
        hint: const Text('Todas las tiendas'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todas las tiendas')),
          for (final t in tiendasFiltradas) DropdownMenuItem(value: t.id, child: Text(t.nombre)),
        ],
        onChanged: (v) => cambiar(() => _tiendaId = v),
      ),
      DropdownButton<String?>(
        value: _estado,
        isExpanded: expandido,
        hint: const Text('Todos los estados'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos los estados')),
          // El cliente solo ve bultos con tienda asignada (ya repartidos)
          for (final e in ['entregado', 'no_entregado', 'devolucion'])
            DropdownMenuItem(value: e, child: Text(textoEstadoBulto(e))),
        ],
        onChanged: (v) => cambiar(() => _estado = v),
      ),
    ];
  }

  int get _filtrosActivos => [_rutaId, _tiendaId, _estado].whereType<String>().length;

  /// Móvil: ruta, tienda y estado en un panel inferior.
  void _abrirFiltros() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (contexto, refrescarHoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filtros', style: Theme.of(contexto).textTheme.titleLarge),
              const SizedBox(height: 8),
              // Consumer: el panel se redibuja cuando llegan las tiendas
              Consumer(
                builder: (_, refHoja, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in _desplegables(
                      refHoja.watch(tiendasClienteProvider).value ?? const [],
                      () => refrescarHoja(() {}),
                    ))
                      Padding(padding: const EdgeInsets.only(bottom: 8), child: d),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _rutaId = _tiendaId = _estado = null);
                      refrescarHoja(() {});
                    },
                    child: const Text('Quitar filtros'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(contexto),
                    child: const Text('Ver resultados'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget get _buscador => TextField(
    decoration: const InputDecoration(
      hintText: 'Buscar por código de bulto',
      prefixIcon: Icon(Icons.search),
      isDense: true,
    ),
    keyboardType: TextInputType.number,
    onChanged: _buscarCodigo,
  );

  Widget get _periodos => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final p in Periodo.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                p == Periodo.rango && _periodo == Periodo.rango && _rango != null
                    ? '${fecha(_rango!.start)} – ${fecha(_rango!.end)}'
                    : p.texto,
              ),
              selected: _periodo == p,
              onSelected: (_) => _elegirPeriodo(p),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => RecargaAutomatica(
    temas: const {TemaCambio.cliente},
    alCambiar: () {
      ref.invalidate(bultosClienteProvider);
      ref.invalidate(incidenciasBultoProvider);
    },
    child: _contenido(context),
  );

  Widget _contenido(BuildContext context) {
    final tema = Theme.of(context);
    final filtro = _filtro;
    final valor = ref.watch(bultosClienteProvider(filtro));
    // Se observa aquí para tenerlas listas (y en caché) al abrir los filtros
    final tiendas = ref.watch(tiendasClienteProvider).value ?? const <TiendaCliente>[];
    void actualizar() => ref.invalidate(bultosClienteProvider(filtro));

    final barraFiltros = Responsivo(
      // Móvil: buscador y botón de filtros; los periodos debajo
      movil: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buscador),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _filtrosActivos > 0,
                label: Text('$_filtrosActivos'),
                child: IconButton.filledTonal(
                  tooltip: 'Filtros',
                  icon: const Icon(Icons.tune),
                  onPressed: _abrirFiltros,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _periodos,
        ],
      ),
      // Tablet y escritorio: todo a la vista
      tablet: (_) => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 240, child: _buscador),
          _periodos,
          ..._desplegables(tiendas, () {}),
          IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: actualizar),
        ],
      ),
    );

    final escritorio = context.esPantallaEscritorio;
    // Si el bulto abierto ya no está en los resultados (otros filtros), se cierra
    final seleccionado = valor.value?.where((b) => b.id == _seleccionado?.id).firstOrNull;

    final lista = VistaAsync(
      valor: valor,
      alReintentar: actualizar,
      datos: (bultos) {
        if (bultos.isEmpty) {
          return const ListaVacia(
            'No hay bultos con estos filtros.\nPrueba con otras fechas o quita algún filtro.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(bultosClienteProvider(filtro).future),
          child: ListView.separated(
            itemCount: bultos.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = bultos[i];
              return ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(
                  b.codigo,
                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                ),
                subtitle: Text(
                  [
                    ?b.tienda,
                    ?b.ruta,
                    if (b.entregadoEn != null)
                      'Entregado ${fechaHora(b.entregadoEn!)}'
                    else
                      'Cargado ${fechaHora(b.cargadoEn)}',
                    ?b.motivo,
                  ].join(' · '),
                ),
                trailing: EtiquetaBulto(b.estado),
                selected: escritorio && b.id == seleccionado?.id,
                onTap: () => _verBulto(b),
              );
            },
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: barraFiltros),
        if (valor.value case final bultos?) _Resumen(bultos: bultos),
        const Divider(height: 1),
        Expanded(
          child: !escritorio
              ? lista
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: lista),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 400,
                      child: seleccionado == null
                          ? const ListaVacia('Selecciona un bulto para ver su detalle.')
                          : SingleChildScrollView(
                              padding: const EdgeInsets.only(top: 20),
                              child: _DetalleBulto(
                                key: ValueKey(seleccionado.id),
                                bulto: seleccionado,
                              ),
                            ),
                    ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Text(
            'Los datos se conservan 14 días.',
            style: tema.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.bultos});

  final List<BultoCliente> bultos;

  @override
  Widget build(BuildContext context) {
    int contar(String estado) => bultos.where((b) => b.estado == estado).length;
    final datos = [
      ('Total', bultos.length, Paleta.texto),
      ('Entregados', contar('entregado'), ColoresEstado.correcto),
      ('No entregados', contar('no_entregado'), ColoresEstado.peligro),
      ('Devoluciones', contar('devolucion'), ColoresEstado.aviso),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          for (final (texto, n, color) in datos)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$n ',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  TextSpan(text: texto),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Detalle de un bulto con sus incidencias y la opción de reportar un problema.
class _DetalleBulto extends ConsumerWidget {
  const _DetalleBulto({super.key, required this.bulto});

  final BultoCliente bulto;

  Future<void> _reportar(BuildContext context, WidgetRef ref) async {
    final texto = TextEditingController();
    final enviado = await showDialog<bool>(
      context: context,
      builder: (_) => DialogoFormulario(
        titulo: 'Reportar un problema',
        textoGuardar: 'Enviar',
        exito: 'Incidencia enviada. El equipo de reparto la revisará.',
        alGuardar: () =>
            ref.read(clienteRepositoryProvider).crearIncidencia(bulto.id, texto.text.trim()),
        campos: [
          Text('Bulto ${bulto.codigo}${bulto.tienda == null ? '' : ' · ${bulto.tienda}'}'),
          TextFormField(
            controller: texto,
            decoration: const InputDecoration(
              labelText: '¿Qué ha ocurrido?',
              hintText: 'Ej. no ha llegado, llegó dañado, faltan unidades…',
            ),
            maxLines: 4,
            maxLength: 2000,
            validator: obligatorio,
            autofocus: true,
          ),
        ],
      ),
    );
    if (enviado == true) ref.invalidate(incidenciasBultoProvider(bulto.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final incidencias = ref.watch(incidenciasBultoProvider(bulto.id));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Bulto ${bulto.codigo}', style: tema.textTheme.titleLarge)),
                EtiquetaBulto(bulto.estado),
              ],
            ),
            const SizedBox(height: 12),
            for (final (etiqueta, valor) in [
              ('Tienda', bulto.tienda),
              ('Ruta', bulto.ruta),
              ('Repartidor', bulto.repartidor),
              ('Cargado', fechaHora(bulto.cargadoEn)),
              ('Entregado', bulto.entregadoEn == null ? null : fechaHora(bulto.entregadoEn!)),
              ('Motivo', bulto.motivo),
            ])
              if (valor != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$etiqueta: ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: valor),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            Text('Incidencias', style: tema.textTheme.titleSmall),
            const SizedBox(height: 4),
            switch (incidencias) {
              AsyncData(:final value) when value.isEmpty => const Text('Ninguna por ahora.'),
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final i in value)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.forum_outlined),
                      title: Text(i.descripcion),
                      subtitle: Text('${fechaHora(i.creadoEn)} · ${i.estado.replaceAll('_', ' ')}'),
                    ),
                ],
              ),
              AsyncError() => const Text('No se pudieron cargar las incidencias.'),
              _ => const LinearProgressIndicator(),
            },
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _reportar(context, ref),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Reportar un problema'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
