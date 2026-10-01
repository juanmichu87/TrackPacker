import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';

class RutasPage extends ConsumerStatefulWidget {
  const RutasPage({super.key});

  @override
  ConsumerState<RutasPage> createState() => _RutasPageState();
}

class _RutasPageState extends ConsumerState<RutasPage> {
  String _busqueda = '';
  String? _areaId;

  Future<void> _editar([Ruta? ruta]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => RutaDialogo(ruta: ruta),
    );
    if (guardado == true) refrescarRutasYTiendas(ref);
  }

  Future<void> _eliminar(Ruta r) async {
    if (!await confirmar(
      context,
      titulo: 'Eliminar ruta',
      mensaje: 'Se eliminará "${r.nombre}" y sus ${r.numTiendas} tiendas quedarán sin ruta. '
          'Si ya tiene repartos registrados no se podrá eliminar; en ese caso, desactívala.',
      accion: 'Eliminar',
      peligroso: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await ejecutar(
      context,
      () => ref.read(adminRepositoryProvider).eliminar('rutas', r.id),
      exito: 'Ruta eliminada',
    );
    if (ok) refrescarRutasYTiendas(ref);
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasProvider).value ?? const <Area>[];

    return Column(
      children: [
        BarraLista(
          pista: 'Buscar ruta',
          alBuscar: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
          filtros: [
            if (areas.isNotEmpty)
              DropdownButton<String?>(
                value: _areaId,
                hint: const Text('Todas las áreas'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas las áreas')),
                  for (final a in areas) DropdownMenuItem(value: a.id, child: Text(a.nombre)),
                ],
                onChanged: (v) => setState(() => _areaId = v),
              ),
          ],
          textoNuevo: 'Nueva ruta',
          alNuevo: () => _editar(),
        ),
        Expanded(
          child: VistaAsync(
            valor: ref.watch(rutasProvider),
            alReintentar: () => refrescarRutasYTiendas(ref),
            datos: (rutas) {
              final filtradas = rutas
                  .where((r) => (_areaId == null || r.areaId == _areaId) &&
                      r.nombre.toLowerCase().contains(_busqueda))
                  .toList();
              if (filtradas.isEmpty) return const ListaVacia('No hay rutas que mostrar.');

              return ListView.separated(
                itemCount: filtradas.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = filtradas[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.alt_route)),
                    title: Text(r.nombre),
                    subtitle: Text([
                      ?r.areaNombre,
                      '${r.numTiendas} ${r.numTiendas == 1 ? 'tienda' : 'tiendas'}',
                    ].join(' · ')),
                    onTap: () => context.go('/admin/rutas/${r.id}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EtiquetaActivo(r.activa),
                        MenuFila([
                          OpcionMenu('Tiendas y orden', Icons.format_list_numbered,
                              () => context.go('/admin/rutas/${r.id}')),
                          OpcionMenu('Editar', Icons.edit_outlined, () => _editar(r)),
                          OpcionMenu('Eliminar', Icons.delete_outline, () => _eliminar(r),
                              peligrosa: true),
                        ]),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Alta y edición de los datos básicos de una ruta.
class RutaDialogo extends ConsumerStatefulWidget {
  const RutaDialogo({super.key, this.ruta});

  final Ruta? ruta;

  @override
  ConsumerState<RutaDialogo> createState() => _RutaDialogoState();
}

class _RutaDialogoState extends ConsumerState<RutaDialogo> {
  late final _nombre = TextEditingController(text: widget.ruta?.nombre);
  late String? _areaId = widget.ruta?.areaId;
  late bool _activa = widget.ruta?.activa ?? true;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasProvider).value ?? const <Area>[];

    return DialogoFormulario(
      titulo: widget.ruta == null ? 'Nueva ruta' : 'Editar ruta',
      alGuardar: () => ref.read(adminRepositoryProvider).guardar('rutas', widget.ruta?.id, {
        'nombre': _nombre.text.trim(),
        'area_id': _areaId,
        'activa': _activa,
      }),
      exito: widget.ruta == null ? 'Ruta creada' : 'Ruta actualizada',
      campos: [
        TextFormField(
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: obligatorio,
          autofocus: true,
        ),
        DropdownButtonFormField<String?>(
          initialValue: _areaId,
          decoration: const InputDecoration(labelText: 'Área (opcional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin área')),
            for (final a in areas) DropdownMenuItem(value: a.id, child: Text(a.nombre)),
          ],
          onChanged: (v) => setState(() => _areaId = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activa'),
          subtitle: const Text('Solo las rutas activas aparecen al repartidor'),
          value: _activa,
          onChanged: (v) => setState(() => _activa = v),
        ),
      ],
    );
  }
}
