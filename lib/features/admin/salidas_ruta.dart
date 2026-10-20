import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../core/salidas.dart';
import '../../core/tema.dart';
import '../../shared/campo_hora.dart';
import '../../shared/ui.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';

/// Salidas (franjas horarias fijas) de una ruta. `tiendas` son las de la ruta
/// en su orden de reparto.
class SalidasRuta extends ConsumerWidget {
  const SalidasRuta({super.key, required this.rutaId, required this.tiendas});

  final String rutaId;
  final List<Tienda> tiendas;

  Future<void> _editar(BuildContext context, WidgetRef ref, [Salida? salida]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _SalidaDialogo(rutaId: rutaId, tiendas: tiendas, salida: salida),
    );
    if (guardado == true) ref.invalidate(salidasDeRutaProvider(rutaId));
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, Salida s) async {
    if (!await confirmar(
      context,
      titulo: 'Eliminar salida',
      mensaje:
          'Se eliminará la salida «${s.nombre}» (${s.franja}). Los repartos ya hechos '
          'se conservan.',
      accion: 'Eliminar',
      peligroso: true,
    )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await ejecutar(
      context,
      () => ref.read(adminRepositoryProvider).eliminar('salidas', s.id),
      exito: 'Salida eliminada',
    );
    if (ok) ref.invalidate(salidasDeRutaProvider(rutaId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: tiendas.isEmpty ? null : () => _editar(context, ref),
                icon: const Icon(Icons.schedule),
                label: const Text('Nueva salida'),
              ),
              Text(
                tiendas.isEmpty
                    ? 'Añade primero tiendas a la ruta.'
                    : 'El repartidor que empiece dentro del horario de una salida solo verá '
                          'sus tiendas, hasta que cierre el reparto.',
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: VistaAsync(
            valor: ref.watch(salidasDeRutaProvider(rutaId)),
            alReintentar: () => ref.invalidate(salidasDeRutaProvider(rutaId)),
            datos: (salidas) {
              if (salidas.isEmpty) {
                return const ListaVacia(
                  'Esta ruta no tiene salidas.\nSin salidas, el repartidor verá todas sus tiendas.',
                );
              }
              final abierta = salidaActual(salidas, DateTime.now());
              final idsRuta = {for (final t in tiendas) t.id};
              return ListView.separated(
                itemCount: salidas.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = salidas[i];
                  final incluidas = s.tiendaIds.where(idsRuta.contains).length;
                  // Salida sin tiendas: el repartidor no podría entregar nada.
                  // Pasa si se quitan de la ruta las tiendas que tenía.
                  final vacia = incluidas == 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: vacia ? ColoresEstado.peligro.withValues(alpha: 0.12) : null,
                      child: Icon(
                        vacia ? Icons.warning_amber_rounded : Icons.schedule,
                        color: vacia ? ColoresEstado.peligro : null,
                      ),
                    ),
                    title: Text('${s.nombre} · empieza ${s.franja}'),
                    subtitle: Text(
                      vacia
                          ? '${textoDias(s.dias)} · SIN TIENDAS: el repartidor no podrá entregar. '
                                'Edítala y elige sus tiendas.'
                          : '${textoDias(s.dias)} · $incluidas de ${tiendas.length} tiendas',
                      style: vacia ? const TextStyle(color: ColoresEstado.peligro) : null,
                    ),
                    onTap: () => _editar(context, ref, s),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s.id == abierta?.id)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Etiqueta('Ahora', color: ColoresEstado.correcto),
                          ),
                        EtiquetaActivo(s.activa),
                        MenuFila([
                          OpcionMenu('Editar', Icons.edit_outlined, () => _editar(context, ref, s)),
                          OpcionMenu(
                            'Eliminar',
                            Icons.delete_outline,
                            () => _eliminar(context, ref, s),
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

class _SalidaDialogo extends ConsumerStatefulWidget {
  const _SalidaDialogo({required this.rutaId, required this.tiendas, this.salida});

  final String rutaId;
  final List<Tienda> tiendas;
  final Salida? salida;

  @override
  ConsumerState<_SalidaDialogo> createState() => _SalidaDialogoState();
}

class _SalidaDialogoState extends ConsumerState<_SalidaDialogo> {
  late final _nombre = TextEditingController(text: widget.salida?.nombre);
  late int? _inicio = widget.salida?.inicio;
  late int? _fin = widget.salida?.fin;
  late final Set<int> _dias = {...widget.salida?.dias ?? nombresDias.keys};
  late bool _activa = widget.salida?.activa ?? true;
  late final Set<String> _tiendas = {
    ...widget.salida?.tiendaIds ?? {for (final t in widget.tiendas) t.id},
  };

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _elegirHora({required bool esInicio}) async {
    final actual = esInicio ? _inicio : _fin;
    final elegida = await showTimePicker(
      context: context,
      initialTime: actual == null
          ? TimeOfDay(hour: esInicio ? 6 : 10, minute: 0)
          : TimeOfDay(hour: actual ~/ 60, minute: actual % 60),
      helpText: esInicio ? 'Hora de inicio' : 'Hora de fin',
      builder: (context, hijo) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: hijo!,
      ),
    );
    if (elegida == null) return;
    final minutos = elegida.hour * 60 + elegida.minute;
    setState(() {
      if (esInicio) {
        _inicio = minutos;
      } else {
        _fin = minutos;
      }
    });
  }

  Future<void> _guardar() async {
    if (_inicio == null || _fin == null) {
      throw const ErrorValidacion('Elige la hora de inicio y la de fin.');
    }
    if (_inicio == _fin) {
      throw const ErrorValidacion('La hora de inicio y la de fin no pueden ser iguales.');
    }
    if (_dias.isEmpty) throw const ErrorValidacion('Elige al menos un día.');
    if (_tiendas.isEmpty) throw const ErrorValidacion('Elige al menos una tienda.');

    await ref
        .read(adminRepositoryProvider)
        .guardarSalida(
          id: widget.salida?.id,
          rutaId: widget.rutaId,
          nombre: _nombre.text.trim(),
          inicio: _inicio!,
          fin: _fin!,
          dias: _dias,
          activa: _activa,
          // En el orden de la ruta
          tiendaIds: [
            for (final t in widget.tiendas)
              if (_tiendas.contains(t.id)) t.id,
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    String hora(int? minutos) => minutos == null ? '--:--' : horaDeMinutos(minutos);
    final cruza = _inicio != null && _fin != null && _fin! < _inicio!;

    return DialogoFormulario(
      titulo: widget.salida == null ? 'Nueva salida' : 'Editar salida',
      alGuardar: _guardar,
      exito: widget.salida == null ? 'Salida creada' : 'Salida actualizada',
      campos: [
        TextFormField(
          controller: _nombre,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej. Mañana, Mediodía, Tarde',
          ),
          validator: obligatorio,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Horario para empezar el reparto', style: tema.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Si el repartidor empieza su reparto dentro de este horario, se le asigna esta '
              'salida. Después puede seguir cargando y entregando sin límite de hora: '
              'no se pierde ningún bulto.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // Móvil: reloj nativo, cómodo con el dedo. Escritorio: campo rápido
            // en el que se escribe o se elige la hora.
            if (esMovil(context))
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _elegirHora(esInicio: true),
                      icon: const Icon(Icons.login),
                      label: Text('Desde ${hora(_inicio)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _elegirHora(esInicio: false),
                      icon: const Icon(Icons.logout),
                      label: Text('Hasta ${hora(_fin)}'),
                    ),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoHora(
                      etiqueta: 'Desde',
                      icono: Icons.login,
                      valor: _inicio,
                      alCambiar: (m) => setState(() => _inicio = m),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CampoHora(
                      etiqueta: 'Hasta',
                      icono: Icons.logout,
                      valor: _fin,
                      alCambiar: (m) => setState(() => _fin = m),
                    ),
                  ),
                ],
              ),
            if (cruza)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Cruza la medianoche: termina al día siguiente.',
                  style: tema.textTheme.bodySmall,
                ),
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Días', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final MapEntry(:key, :value) in nombresDias.entries)
                  FilterChip(
                    label: Text(value),
                    selected: _dias.contains(key),
                    onSelected: (s) => setState(() => s ? _dias.add(key) : _dias.remove(key)),
                  ),
              ],
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activa'),
          value: _activa,
          onChanged: (v) => setState(() => _activa = v),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tiendas de esta salida (${_tiendas.length}/${widget.tiendas.length})',
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _tiendas.addAll(widget.tiendas.map((t) => t.id));
                  }),
                  child: const Text('Todas'),
                ),
                TextButton(onPressed: () => setState(_tiendas.clear), child: const Text('Ninguna')),
              ],
            ),
            for (final (i, t) in widget.tiendas.indexed)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _tiendas.contains(t.id),
                onChanged: (s) =>
                    setState(() => s == true ? _tiendas.add(t.id) : _tiendas.remove(t.id)),
                title: Text('${i + 1}. ${t.nombre}'),
                subtitle: t.clienteNombre == null ? null : Text(t.clienteNombre!),
              ),
          ],
        ),
      ],
    );
  }
}
