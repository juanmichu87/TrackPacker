import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema.dart';
import '../../core/formato.dart';
import '../../shared/ui.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';

/// Valor del filtro de ruta para las tiendas sin ruta asignada.
const _sinRuta = '__sin_ruta__';

class TiendasPage extends ConsumerStatefulWidget {
  const TiendasPage({super.key});

  @override
  ConsumerState<TiendasPage> createState() => _TiendasPageState();
}

class _TiendasPageState extends ConsumerState<TiendasPage> {
  String _busqueda = '';
  String? _rutaId;
  String? _clienteId;

  Future<void> _editar([Tienda? tienda]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _TiendaDialogo(tienda: tienda),
    );
    if (guardado == true) refrescarRutasYTiendas(ref);
  }

  Future<void> _eliminar(Tienda t) async {
    if (!await confirmar(
      context,
      titulo: 'Eliminar tienda',
      mensaje:
          'Se eliminará "${t.nombre}". Si tiene entregas registradas no se podrá eliminar; '
          'en ese caso, desactívala.',
      accion: 'Eliminar',
      peligroso: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await ejecutar(
      context,
      () => ref.read(adminRepositoryProvider).eliminar('tiendas', t.id),
      exito: 'Tienda eliminada',
    );
    if (ok) refrescarRutasYTiendas(ref);
  }

  @override
  Widget build(BuildContext context) {
    final rutas = ref.watch(rutasProvider).value ?? const <Ruta>[];
    final clientes = ref.watch(clientesProvider).value ?? const <Cliente>[];

    return Column(
      children: [
        BarraLista(
          pista: 'Buscar por tienda, dirección o localidad',
          alBuscar: (v) => setState(() => _busqueda = normalizarBusqueda(v)),
          filtros: [
            DropdownButton<String?>(
              value: _rutaId,
              hint: const Text('Todas las rutas'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas las rutas')),
                const DropdownMenuItem(value: _sinRuta, child: Text('Sin ruta')),
                for (final r in rutas) DropdownMenuItem(value: r.id, child: Text(r.nombre)),
              ],
              onChanged: (v) => setState(() => _rutaId = v),
            ),
            DropdownButton<String?>(
              value: _clienteId,
              hint: const Text('Todos los clientes'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos los clientes')),
                for (final c in clientes) DropdownMenuItem(value: c.id, child: Text(c.nombre)),
              ],
              onChanged: (v) => setState(() => _clienteId = v),
            ),
          ],
          textoNuevo: 'Nueva tienda',
          alNuevo: () => _editar(),
        ),
        Expanded(
          child: VistaAsync(
            valor: ref.watch(tiendasProvider),
            alReintentar: () => refrescarRutasYTiendas(ref),
            datos: (tiendas) {
              final filtradas = tiendas.where((t) {
                if (_rutaId == _sinRuta && t.rutas.isNotEmpty) return false;
                if (_rutaId != null && _rutaId != _sinRuta && !t.estaEnRuta(_rutaId!)) return false;
                if (_clienteId != null && t.clienteId != _clienteId) return false;
                if (_busqueda.isEmpty) return true;
                return [
                  t.nombre,
                  t.direccion,
                  t.localidad,
                  t.codigoPostal,
                ].any((c) => coincideBusqueda(c, _busqueda));
              }).toList();
              if (filtradas.isEmpty) return const ListaVacia('No hay tiendas que mostrar.');

              return ListView.separated(
                itemCount: filtradas.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = filtradas[i];
                  final ruta = t.rutas.isEmpty
                      ? 'Sin ruta'
                      : t.rutas.map((r) => r.texto).join(', ');
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
                    title: Text(t.nombre),
                    subtitle: Text(
                      [
                        ?t.clienteNombre,
                        ruta,
                        t.direccionCompleta,
                      ].where((p) => p.isNotEmpty).join(' · '),
                    ),
                    onTap: () => _editar(t),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (t.rutas.isEmpty && t.activa)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Etiqueta('Sin ruta', color: ColoresEstado.aviso),
                          ),
                        EtiquetaActivo(t.activa),
                        MenuFila([
                          OpcionMenu('Editar', Icons.edit_outlined, () => _editar(t)),
                          OpcionMenu(
                            'Eliminar',
                            Icons.delete_outline,
                            () => _eliminar(t),
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

class _TiendaDialogo extends ConsumerStatefulWidget {
  const _TiendaDialogo({this.tienda});

  final Tienda? tienda;

  @override
  ConsumerState<_TiendaDialogo> createState() => _TiendaDialogoState();
}

class _TiendaDialogoState extends ConsumerState<_TiendaDialogo> {
  late final _nombre = TextEditingController(text: widget.tienda?.nombre);
  late final _direccion = TextEditingController(text: widget.tienda?.direccion);
  late final _cp = TextEditingController(text: widget.tienda?.codigoPostal);
  late final _localidad = TextEditingController(text: widget.tienda?.localidad);
  late String? _clienteId = widget.tienda?.clienteId;
  late final Set<String> _rutas = {for (final r in widget.tienda?.rutas ?? const []) r.id};
  late bool _activa = widget.tienda?.activa ?? true;

  @override
  void dispose() {
    for (final c in [_nombre, _direccion, _cp, _localidad]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final clientes = ref.watch(clientesProvider).value ?? const <Cliente>[];
    final rutas = ref.watch(rutasProvider).value ?? const <Ruta>[];

    return DialogoFormulario(
      titulo: widget.tienda == null ? 'Nueva tienda' : 'Editar tienda',
      alGuardar: () => ref
          .read(adminRepositoryProvider)
          .guardarTienda(
            widget.tienda?.id,
            {
              'nombre': _nombre.text.trim(),
              'cliente_id': _clienteId,
              'direccion': textoONulo(_direccion.text),
              'codigo_postal': textoONulo(_cp.text),
              'localidad': textoONulo(_localidad.text),
              'activa': _activa,
            },
            rutaIds: [
              for (final r in rutas)
                if (_rutas.contains(r.id)) r.id,
            ],
          ),
      exito: widget.tienda == null ? 'Tienda creada' : 'Tienda actualizada',
      campos: [
        TextFormField(
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: obligatorio,
          autofocus: true,
        ),
        DropdownButtonFormField<String>(
          initialValue: _clienteId,
          decoration: const InputDecoration(labelText: 'Cliente'),
          items: [for (final c in clientes) DropdownMenuItem(value: c.id, child: Text(c.nombre))],
          onChanged: (v) => setState(() => _clienteId = v),
          validator: (v) => v == null ? 'Elige el cliente' : null,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rutas', style: tema.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Puede estar en varias. En una ruta nueva se coloca al final; el orden '
              'se ajusta desde la página de la ruta.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in rutas)
                  FilterChip(
                    label: Text(r.nombre),
                    selected: _rutas.contains(r.id),
                    onSelected: (s) => setState(() => s ? _rutas.add(r.id) : _rutas.remove(r.id)),
                  ),
              ],
            ),
          ],
        ),
        TextFormField(
          controller: _direccion,
          decoration: const InputDecoration(labelText: 'Dirección'),
        ),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: TextFormField(
                controller: _cp,
                decoration: const InputDecoration(labelText: 'Código postal'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _localidad,
                decoration: const InputDecoration(labelText: 'Localidad'),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activa'),
          value: _activa,
          onChanged: (v) => setState(() => _activa = v),
        ),
      ],
    );
  }
}
