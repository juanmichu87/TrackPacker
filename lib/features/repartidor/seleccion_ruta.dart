import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/salidas.dart';
import '../../core/tema.dart';
import '../../shared/estados.dart';
import '../../shared/responsive.dart';
import '../../shared/ui.dart';
import 'datos/repartidor_repository.dart';
import '../../shared/avisos_cambios.dart';

/// Lista de rutas con su ocupación. Al elegir una, se elige la salida y se
/// empieza el reparto (estado «carga»).
class SeleccionRuta extends ConsumerStatefulWidget {
  const SeleccionRuta({super.key});

  @override
  ConsumerState<SeleccionRuta> createState() => _SeleccionRutaState();
}

class _SeleccionRutaState extends ConsumerState<SeleccionRuta> {
  bool _iniciando = false;

  Future<void> _elegir(RutaRepartidor ruta) async {
    if (_iniciando) return;
    final repo = ref.read(repartidorRepositoryProvider);

    if (ruta.ocupada &&
        !await confirmar(
          context,
          titulo: 'Ruta ocupada',
          mensaje:
              '${ruta.ocupadaPor ?? 'Otro repartidor'} ya está con «${ruta.nombre}» '
              '(${textoEstadoReparto(ruta.ocupadaEstado!).toLowerCase()} desde las '
              '${horaDe(ruta.ocupadaDesde!)}).\n\n¿Quieres empezarla tú también, por ejemplo '
              'como apoyo?',
          accion: 'Continuar',
        )) {
      return;
    }

    setState(() => _iniciando = true);
    try {
      final salidas = await repo.salidas(ruta.id);
      if (!mounted) return;
      String? salidaId;
      if (salidas.isNotEmpty) {
        final elegida = await mostrarPanel<Salida>(
          context,
          builder: (_) => _SelectorSalida(ruta: ruta, salidas: salidas),
        );
        if (elegida == null) return;
        salidaId = elegida.id;
      }
      if (!mounted) return;
      final ok = await ejecutar(context, () => repo.iniciar(ruta.id, salidaId));
      if (ok) ref.invalidate(repartoAbiertoProvider);
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  @override
  Widget build(BuildContext context) => RecargaAutomatica(
    temas: const {TemaCambio.repartos},
    alCambiar: () => ref.invalidate(rutasRepartidorProvider),
    child: _contenido(context),
  );

  Widget _contenido(BuildContext context) {
    final tema = Theme.of(context);
    return Stack(
      children: [
        VistaAsync(
          valor: ref.watch(rutasRepartidorProvider),
          alReintentar: () => ref.invalidate(rutasRepartidorProvider),
          datos: (rutas) => RefreshIndicator(
            onRefresh: () => ref.refresh(rutasRepartidorProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Elige tu ruta', style: tema.textTheme.titleLarge)),
                    IconButton(
                      tooltip: 'Actualizar',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.invalidate(rutasRepartidorProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (rutas.isEmpty) const ListaVacia('No hay rutas activas.'),
                // 1 columna en el móvil, 2 en tablet, 3 en escritorio
                RejillaAdaptable(
                  anchoMinimo: 340,
                  maxColumnas: 3,
                  children: [
                    for (final r in rutas)
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: r.ocupada
                                ? ColoresEstado.peligro.withValues(alpha: 0.12)
                                : ColoresEstado.correcto.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.alt_route,
                              color: r.ocupada ? ColoresEstado.peligro : ColoresEstado.correcto,
                            ),
                          ),
                          title: Text(r.nombre, style: tema.textTheme.titleMedium),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r.numTiendas} tiendas'
                                '${r.numSalidas == 0 ? '' : ' · ${r.numSalidas} salidas'}',
                              ),
                              if (r.ocupada)
                                Text(
                                  'Ocupada por ${r.ocupadaPor ?? 'otro repartidor'} · '
                                  '${textoEstadoReparto(r.ocupadaEstado!).toLowerCase()} desde las '
                                  '${horaDe(r.ocupadaDesde!)}',
                                  style: const TextStyle(
                                    color: ColoresEstado.peligro,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          trailing: r.ocupada
                              ? const Etiqueta('Ocupada', color: ColoresEstado.peligro)
                              : const Etiqueta('Disponible', color: ColoresEstado.correcto),
                          onTap: _iniciando ? null : () => _elegir(r),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_iniciando)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// Elige la salida: propone la que está en su horario o, si no hay, la próxima.
class _SelectorSalida extends StatelessWidget {
  const _SelectorSalida({required this.ruta, required this.salidas});

  final RutaRepartidor ruta;
  final List<Salida> salidas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ahora = DateTime.now();
    final actual = salidaActual(salidas, ahora);
    final proxima = actual == null ? proximaSalida(salidas, ahora) : null;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text('¿Qué salida vas a hacer?', style: tema.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            actual != null
                ? 'Ahora toca «${actual.nombre}». Solo verás sus tiendas.'
                : 'Ninguna salida está en su horario ahora mismo. Elige la que vas a hacer.',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final s in salidas)
            Card(
              shape: s.id == (actual ?? proxima)?.id
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: tema.colorScheme.primary, width: 2),
                    )
                  : null,
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(s.nombre),
                subtitle: Text(
                  'Empieza ${s.franja} · ${textoDias(s.dias)} · ${s.tiendaIds.length} tiendas',
                ),
                trailing: s.id == actual?.id
                    ? const Etiqueta('Ahora', color: ColoresEstado.correcto)
                    : s.id == proxima?.id
                    ? const Etiqueta('Próxima', color: ColoresEstado.informacion)
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
            ),
        ],
      ),
    );
  }
}

/// "07:12" en hora local.
String horaDe(DateTime momento) => fechaHora(momento).substring(11);
