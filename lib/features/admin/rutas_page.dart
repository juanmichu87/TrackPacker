import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../shared/avisos_cambios.dart';
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
      mensaje:
          'Se eliminará "${r.nombre}" con sus salidas. Sus ${r.numTiendas} tiendas no se '
          'borran (siguen en sus otras rutas, si tienen). '
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
        // Tiendas que los repartidores añadieron porque faltaban en la ruta
        RecargaAutomatica(
          temas: const {TemaCambio.repartos},
          alCambiar: () => ref.invalidate(tiendasTemporalesProvider),
          child: const _AvisosTiendasTemporales(),
        ),
        BarraLista(
          pista: 'Buscar ruta',
          alBuscar: (v) => setState(() => _busqueda = normalizarBusqueda(v)),
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
                  .where(
                    (r) =>
                        (_areaId == null || r.areaId == _areaId) &&
                        coincideBusqueda(r.nombre, _busqueda),
                  )
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
                    subtitle: Text(
                      [
                        ?r.areaNombre,
                        '${r.numTiendas} ${r.numTiendas == 1 ? 'tienda' : 'tiendas'}',
                      ].join(' · '),
                    ),
                    onTap: () => context.go('/admin/rutas/${r.id}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EtiquetaActivo(r.activa),
                        MenuFila([
                          OpcionMenu(
                            'Tiendas y orden',
                            Icons.format_list_numbered,
                            () => context.go('/admin/rutas/${r.id}'),
                          ),
                          OpcionMenu('Editar', Icons.edit_outlined, () => _editar(r)),
                          OpcionMenu(
                            'Eliminar',
                            Icons.delete_outline,
                            () => _eliminar(r),
                            peligrosa: true,
                          ),
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

/// Avisos de tiendas que un repartidor añadió a su reparto porque no estaban en
/// la ruta. El admin decide si la añade a la ruta (y a esa salida) o no.
class _AvisosTiendasTemporales extends ConsumerWidget {
  const _AvisosTiendasTemporales();

  Future<void> _resolver(
    BuildContext context,
    WidgetRef ref,
    TiendaTemporal t, {
    required bool agregar,
  }) async {
    if (!agregar &&
        !await confirmar(
          context,
          titulo: 'No añadir ${t.tienda}',
          mensaje:
              'La tienda no se añadirá a la franja. El reparto en el que se usó no cambia. '
              'Si vuelve a hacer falta, el repartidor podrá añadirla otra vez.',
          accion: 'No añadir',
        )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await ejecutar(
      context,
      () => ref.read(adminRepositoryProvider).resolverTiendaTemporal(t.id, agregar: agregar),
      exito: agregar
          ? '${t.tienda} añadida a ${t.ruta}${t.salida == null ? '' : ' (salida ${t.salida})'}'
          : 'Aviso descartado',
    );
    if (!ok) return;
    ref.invalidate(tiendasTemporalesProvider);
    refrescarRutasYTiendas(ref);
    ref.invalidate(salidasDeRutaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avisos = ref.watch(tiendasTemporalesProvider).value ?? const <TiendaTemporal>[];
    if (avisos.isEmpty) return const SizedBox.shrink();
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: ColoresEstado.aviso.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ColoresEstado.aviso.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_business_outlined, color: ColoresEstado.aviso),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tiendas añadidas por repartidores (${avisos.length})',
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Text(
              'No estaban en la franja (salida) del reparto y las necesitaron para entregar. '
              'Decide si las añades a esa franja.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            // Con muchos avisos, la lista se desplaza y no tapa las rutas
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: avisos.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = avisos[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: t.tienda,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text:
                                    ' · ${t.ruta}${t.salida == null ? '' : ' (${t.salida})'}'
                                    ' · ${t.repartidor}, ${fechaHora(t.creadaEn)}',
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _resolver(context, ref, t, agregar: true),
                          child: const Text('Añadir a la franja'),
                        ),
                        TextButton(
                          onPressed: () => _resolver(context, ref, t, agregar: false),
                          child: const Text('No añadir'),
                        ),
                      ],
                    ),
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
