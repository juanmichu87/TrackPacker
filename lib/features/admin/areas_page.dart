import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/ui.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';

class AreasPage extends ConsumerStatefulWidget {
  const AreasPage({super.key});

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

class _AreasPageState extends ConsumerState<AreasPage> {
  String _busqueda = '';

  void _refrescar() {
    ref.invalidate(areasProvider);
    ref.invalidate(rutasProvider);
  }

  Future<void> _editar([Area? area]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _AreaDialogo(area: area),
    );
    if (guardado == true) _refrescar();
  }

  Future<void> _eliminar(Area a) async {
    if (!await confirmar(
      context,
      titulo: 'Eliminar área',
      mensaje: 'Se eliminará "${a.nombre}". Sus rutas quedarán sin área asignada.',
      accion: 'Eliminar',
      peligroso: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await ejecutar(
      context,
      () => ref.read(adminRepositoryProvider).eliminar('areas', a.id),
      exito: 'Área eliminada',
    );
    if (ok) _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final rutas = ref.watch(rutasProvider).value ?? const <Ruta>[];

    return Column(
      children: [
        BarraLista(
          pista: 'Buscar área',
          alBuscar: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
          textoNuevo: 'Nueva área',
          alNuevo: () => _editar(),
        ),
        Expanded(
          child: VistaAsync(
            valor: ref.watch(areasProvider),
            alReintentar: _refrescar,
            datos: (areas) {
              final filtradas =
                  areas.where((a) => a.nombre.toLowerCase().contains(_busqueda)).toList();
              if (filtradas.isEmpty) {
                return const ListaVacia(
                  'No hay áreas. Son opcionales y sirven para agrupar rutas por zona.',
                );
              }
              return ListView.separated(
                itemCount: filtradas.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = filtradas[i];
                  final numRutas = rutas.where((r) => r.areaId == a.id).length;
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.map_outlined)),
                    title: Text(a.nombre),
                    subtitle: Text('$numRutas ${numRutas == 1 ? 'ruta' : 'rutas'}'),
                    onTap: () => _editar(a),
                    trailing: MenuFila([
                      OpcionMenu('Editar', Icons.edit_outlined, () => _editar(a)),
                      OpcionMenu('Eliminar', Icons.delete_outline, () => _eliminar(a),
                          peligrosa: true),
                    ]),
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

class _AreaDialogo extends ConsumerStatefulWidget {
  const _AreaDialogo({this.area});

  final Area? area;

  @override
  ConsumerState<_AreaDialogo> createState() => _AreaDialogoState();
}

class _AreaDialogoState extends ConsumerState<_AreaDialogo> {
  late final _nombre = TextEditingController(text: widget.area?.nombre);

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: widget.area == null ? 'Nueva área' : 'Editar área',
      alGuardar: () => ref
          .read(adminRepositoryProvider)
          .guardar('areas', widget.area?.id, {'nombre': _nombre.text.trim()}),
      exito: widget.area == null ? 'Área creada' : 'Área actualizada',
      campos: [
        TextFormField(
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: obligatorio,
          autofocus: true,
        ),
      ],
    );
  }
}
