import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/codigos.dart';
import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../shared/escaner.dart';
import '../../shared/ui.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';

class ClientesPage extends ConsumerStatefulWidget {
  const ClientesPage({super.key});

  @override
  ConsumerState<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends ConsumerState<ClientesPage> {
  String _busqueda = '';

  void _refrescar() {
    ref.invalidate(clientesProvider);
    ref.invalidate(tiendasProvider);
    ref.invalidate(resumenProvider);
  }

  Future<void> _editar([Cliente? cliente]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _ClienteDialogo(cliente: cliente),
    );
    if (guardado == true) _refrescar();
  }

  Future<void> _eliminar(Cliente c) async {
    if (!await confirmar(
      context,
      titulo: 'Eliminar cliente',
      mensaje: 'Se eliminará "${c.nombre}". Si tiene tiendas o usuarios asociados no se podrá '
          'eliminar; en ese caso, desactívalo.',
      accion: 'Eliminar',
      peligroso: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await ejecutar(
      context,
      () => ref.read(adminRepositoryProvider).eliminar('clientes', c.id),
      exito: 'Cliente eliminado',
    );
    if (ok) _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final tiendas = ref.watch(tiendasProvider).value ?? const <Tienda>[];

    return Column(
      children: [
        BarraLista(
          pista: 'Buscar por nombre o CIF',
          alBuscar: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
          textoNuevo: 'Nuevo cliente',
          alNuevo: () => _editar(),
        ),
        Expanded(
          child: VistaAsync(
            valor: ref.watch(clientesProvider),
            alReintentar: _refrescar,
            datos: (clientes) {
              final filtrados = clientes
                  .where((c) => _busqueda.isEmpty ||
                      c.nombre.toLowerCase().contains(_busqueda) ||
                      (c.cif?.toLowerCase().contains(_busqueda) ?? false))
                  .toList();
              if (filtrados.isEmpty) return const ListaVacia('No hay clientes que mostrar.');

              return ListView.separated(
                itemCount: filtrados.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = filtrados[i];
                  final numTiendas = tiendas.where((t) => t.clienteId == c.id).length;
                  final formatos = c.formatos.map((f) => formatosCodigo[f] ?? f).join(', ');
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
                    title: Text(c.nombre),
                    subtitle: Text([
                      ?c.cif,
                      '$numTiendas ${numTiendas == 1 ? 'tienda' : 'tiendas'}',
                      'Códigos: $formatos',
                    ].join(' · ')),
                    onTap: () => _editar(c),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EtiquetaActivo(c.activo),
                        MenuFila([
                          OpcionMenu('Editar', Icons.edit_outlined, () => _editar(c)),
                          OpcionMenu('Eliminar', Icons.delete_outline, () => _eliminar(c),
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

class _ClienteDialogo extends ConsumerStatefulWidget {
  const _ClienteDialogo({this.cliente});

  final Cliente? cliente;

  @override
  ConsumerState<_ClienteDialogo> createState() => _ClienteDialogoState();
}

class _ClienteDialogoState extends ConsumerState<_ClienteDialogo> {
  late final _nombre = TextEditingController(text: widget.cliente?.nombre);
  late final _cif = TextEditingController(text: widget.cliente?.cif);
  late final _patron = TextEditingController(text: widget.cliente?.patronExtraccion);
  late final _min = TextEditingController(text: widget.cliente?.longitudMin?.toString());
  late final _max = TextEditingController(text: widget.cliente?.longitudMax?.toString());
  late final Set<String> _formatos = {...(widget.cliente?.formatos ?? const ['code128'])};
  late bool _activo = widget.cliente?.activo ?? true;

  /// Última etiqueta de ejemplo leída, para comprobar la configuración.
  LecturaCodigo? _ejemplo;

  @override
  void dispose() {
    for (final c in [_nombre, _cif, _patron, _min, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validarLongitud(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return n == null || n < 1 || n > 64 ? 'Entre 1 y 64' : null;
  }

  /// Lee una etiqueta real y rellena formato, patrón y longitud.
  Future<void> _detectar() async {
    final lectura = await leerCodigo(context, titulo: 'Escanea una etiqueta de este cliente');
    if (lectura == null || !mounted) return;
    final regla = sugerirRegla(lectura.contenido);
    setState(() {
      _ejemplo = lectura;
      if (lectura.formato != null) _formatos.add(lectura.formato!);
      if (regla != null) {
        _patron.text = regla.patron ?? '';
        _min.text = '${regla.longitud}';
        _max.text = '${regla.longitud}';
      }
    });
  }

  Future<void> _guardar() async {
    if (_formatos.isEmpty) {
      throw const ErrorValidacion('Elige al menos un formato de código de barras.');
    }
    await ref.read(adminRepositoryProvider).guardar('clientes', widget.cliente?.id, {
      'nombre': _nombre.text.trim(),
      'cif': textoONulo(_cif.text),
      'formatos': [
        for (final f in formatosCodigo.keys)
          if (_formatos.contains(f)) f,
      ],
      'patron_extraccion': textoONulo(_patron.text),
      'longitud_min': int.tryParse(_min.text.trim()),
      'longitud_max': int.tryParse(_max.text.trim()),
      'activo': _activo,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    void refrescar(String _) => setState(() {});

    return DialogoFormulario(
      titulo: widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente',
      alGuardar: _guardar,
      exito: widget.cliente == null ? 'Cliente creado' : 'Cliente actualizado',
      campos: [
        TextFormField(
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: obligatorio,
        ),
        TextFormField(
          controller: _cif,
          decoration: const InputDecoration(labelText: 'CIF (opcional)'),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Etiquetas de sus bultos', style: tema.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Escanea una etiqueta real de este cliente y se rellenará solo: formato del '
                  'código, qué parte es el ID y cuántos dígitos tiene.',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _detectar,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(_ejemplo == null ? 'Escanear etiqueta de ejemplo' : 'Escanear otra'),
                ),
                if (_ejemplo != null) ...[
                  const SizedBox(height: 12),
                  _PruebaEtiqueta(
                    lectura: _ejemplo!,
                    resultado: extraerId(
                      _ejemplo!.contenido,
                      patron: _patron.text,
                      longitudMin: int.tryParse(_min.text.trim()),
                      longitudMax: int.tryParse(_max.text.trim()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Formatos de código de barras que usa', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(:key, :value) in formatosCodigo.entries)
                  FilterChip(
                    label: Text(value),
                    selected: _formatos.contains(key),
                    onSelected: (s) => setState(() => s ? _formatos.add(key) : _formatos.remove(key)),
                  ),
              ],
            ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Opciones avanzadas'),
          subtitle: const Text('Se rellenan solas al escanear una etiqueta de ejemplo'),
          initiallyExpanded: _patron.text.isNotEmpty,
          childrenPadding: const EdgeInsets.only(top: 8),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _min,
                    decoration: const InputDecoration(labelText: 'Dígitos mínimos'),
                    keyboardType: TextInputType.number,
                    validator: _validarLongitud,
                    onChanged: refrescar,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _max,
                    decoration: const InputDecoration(labelText: 'Dígitos máximos'),
                    keyboardType: TextInputType.number,
                    validator: _validarLongitud,
                    onChanged: refrescar,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                'Cuántos dígitos tiene el ID de sus bultos. Sirve para rechazar lecturas '
                'erróneas, como el código de otra etiqueta. Déjalo vacío si varía.',
                style: tema.textTheme.bodySmall,
              ),
            ),
            TextFormField(
              controller: _patron,
              decoration: const InputDecoration(labelText: 'Patrón para extraer el ID'),
              autocorrect: false,
              onChanged: refrescar,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                try {
                  RegExp(t);
                  return null;
                } on FormatException {
                  return 'Patrón no válido';
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Solo hace falta si la etiqueta lleva letras u otros datos además del ID: '
                'indica qué parte del contenido es el ID. Vacío = todo el código es el ID.',
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activo'),
          value: _activo,
          onChanged: (v) => setState(() => _activo = v),
        ),
      ],
    );
  }
}

/// Resultado de aplicar la configuración actual a la etiqueta de ejemplo.
class _PruebaEtiqueta extends StatelessWidget {
  const _PruebaEtiqueta({required this.lectura, required this.resultado});

  final LecturaCodigo lectura;
  final ResultadoId resultado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (icono, color, texto) = switch (resultado) {
      IdValido(:final id) => (Icons.check_circle, Colors.green, 'ID del bulto: $id'),
      IdInvalido(:final motivo) => (Icons.error, tema.colorScheme.error, motivo),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Formato: ${lectura.nombreFormato}', style: tema.textTheme.bodySmall),
        SelectableText(
          'Contenido leído: ${lectura.contenido}',
          style: tema.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icono, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(texto, style: TextStyle(color: color))),
          ],
        ),
      ],
    );
  }
}
