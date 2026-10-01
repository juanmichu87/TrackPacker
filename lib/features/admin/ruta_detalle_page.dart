import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errores.dart';
import '../../shared/ui.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';
import 'rutas_page.dart';

/// Tiendas de una ruta: añadir, quitar y ordenar (el orden es el del reparto).
class RutaDetallePage extends ConsumerStatefulWidget {
  const RutaDetallePage({super.key, required this.rutaId});

  final String rutaId;

  @override
  ConsumerState<RutaDetallePage> createState() => _RutaDetallePageState();
}

class _RutaDetallePageState extends ConsumerState<RutaDetallePage> {
  List<Tienda>? _tiendas;
  Object? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final tiendas = await ref.read(adminRepositoryProvider).tiendasDeRuta(widget.rutaId);
      if (mounted) setState(() => _tiendas = tiendas);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Guarda la nueva lista (qué tiendas y en qué orden). Si falla, vuelve atrás.
  Future<void> _aplicar(List<Tienda> nuevas, {String? exito}) async {
    final anteriores = _tiendas;
    setState(() {
      _tiendas = nuevas;
      _guardando = true;
    });
    final ok = await ejecutar(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .ordenarTiendas(widget.rutaId, [for (final t in nuevas) t.id]),
      exito: exito,
    );
    if (!mounted) return;
    setState(() {
      if (!ok) _tiendas = anteriores;
      _guardando = false;
    });
    refrescarRutasYTiendas(ref);
  }

  void _reordenar(int desde, int hasta) {
    final lista = [...?_tiendas];
    lista.insert(hasta, lista.removeAt(desde));
    _aplicar(lista);
  }

  Future<void> _anadir() async {
    final actuales = {for (final t in _tiendas ?? const <Tienda>[]) t.id};
    final seleccion = await showDialog<List<Tienda>>(
      context: context,
      builder: (_) => _SelectorTiendas(excluir: actuales),
    );
    if (seleccion == null || seleccion.isEmpty) return;
    await _aplicar(
      [...?_tiendas, ...seleccion],
      exito: seleccion.length == 1 ? 'Tienda añadida' : '${seleccion.length} tiendas añadidas',
    );
  }

  Future<void> _quitar(Tienda t) async {
    if (!await confirmar(
      context,
      titulo: 'Quitar tienda',
      mensaje: '"${t.nombre}" quedará sin ruta asignada.',
      accion: 'Quitar',
    )) {
      return;
    }
    await _aplicar([...?_tiendas]..removeWhere((x) => x.id == t.id), exito: 'Tienda quitada');
  }

  Future<void> _editarRuta(Ruta ruta) async {
    final guardado = await showDialog<bool>(context: context, builder: (_) => RutaDialogo(ruta: ruta));
    if (guardado == true) refrescarRutasYTiendas(ref);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rutas = ref.watch(rutasProvider).value;
    final ruta = rutas?.where((r) => r.id == widget.rutaId).firstOrNull;
    final tiendas = _tiendas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Volver a rutas',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin/rutas'),
              ),
              Text(ruta?.nombre ?? 'Ruta', style: tema.textTheme.titleLarge),
              if (ruta?.areaNombre != null) Chip(label: Text(ruta!.areaNombre!)),
              if (ruta != null) EtiquetaActivo(ruta.activa),
              if (ruta != null)
                OutlinedButton.icon(
                  onPressed: () => _editarRuta(ruta),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar ruta'),
                ),
              FilledButton.icon(
                onPressed: _guardando || tiendas == null ? null : _anadir,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Añadir tiendas'),
              ),
              if (_guardando)
                const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Arrastra las tiendas para ordenarlas según el recorrido del reparto.',
            style: tema.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch ((tiendas, _error)) {
            (_, final Object e) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mensajeError(e)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
                ],
              ),
            ),
            (null, _) => const Center(child: CircularProgressIndicator()),
            (final List<Tienda> lista, _) when lista.isEmpty =>
              const ListaVacia('Esta ruta aún no tiene tiendas. Pulsa «Añadir tiendas».'),
            (final List<Tienda> lista, _) => ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: lista.length,
              onReorderItem: _guardando ? (_, _) {} : _reordenar,
              itemBuilder: (context, i) {
                final t = lista[i];
                return ListTile(
                  key: ValueKey(t.id),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_indicator),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(radius: 14, child: Text('${i + 1}')),
                    ],
                  ),
                  title: Text(t.nombre),
                  subtitle: Text([?t.clienteNombre, t.direccionCompleta]
                      .where((p) => p.isNotEmpty)
                      .join(' · ')),
                  trailing: IconButton(
                    tooltip: 'Quitar de la ruta',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _guardando ? null : () => _quitar(t),
                  ),
                );
              },
            ),
          },
        ),
      ],
    );
  }
}

/// Selección múltiple de tiendas activas que no están en la ruta.
class _SelectorTiendas extends ConsumerStatefulWidget {
  const _SelectorTiendas({required this.excluir});

  final Set<String> excluir;

  @override
  ConsumerState<_SelectorTiendas> createState() => _SelectorTiendasState();
}

class _SelectorTiendasState extends ConsumerState<_SelectorTiendas> {
  final _seleccion = <String>{};
  String _busqueda = '';
  bool _soloSinRuta = true;

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(tiendasProvider);

    return AlertDialog(
      title: const Text('Añadir tiendas a la ruta'),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por tienda, cliente o localidad',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo tiendas sin ruta'),
              value: _soloSinRuta,
              onChanged: (v) => setState(() => _soloSinRuta = v ?? true),
            ),
            Expanded(
              child: VistaAsync(
                valor: todas,
                alReintentar: () => ref.invalidate(tiendasProvider),
                datos: (tiendas) {
                  final candidatas = tiendas.where((t) {
                    if (!t.activa || widget.excluir.contains(t.id)) return false;
                    if (_soloSinRuta && t.rutaId != null) return false;
                    if (_busqueda.isEmpty) return true;
                    return [t.nombre, t.clienteNombre, t.localidad]
                        .any((c) => c?.toLowerCase().contains(_busqueda) ?? false);
                  }).toList();
                  if (candidatas.isEmpty) {
                    return const ListaVacia('No hay tiendas disponibles con este filtro.');
                  }
                  return ListView(
                    children: [
                      for (final t in candidatas)
                        CheckboxListTile(
                          value: _seleccion.contains(t.id),
                          onChanged: (s) => setState(
                            () => s == true ? _seleccion.add(t.id) : _seleccion.remove(t.id),
                          ),
                          title: Text(t.nombre),
                          subtitle: Text([
                            ?t.clienteNombre,
                            if (t.rutaNombre != null) 'Se moverá desde ${t.rutaNombre}',
                          ].join(' · ')),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _seleccion.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final t in todas.value ?? const <Tienda>[])
                    if (_seleccion.contains(t.id)) t,
                ]),
          child: Text(_seleccion.isEmpty ? 'Añadir' : 'Añadir (${_seleccion.length})'),
        ),
      ],
    );
  }
}
