import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../shared/estados.dart';
import '../../shared/ui.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';

class RepartosPage extends ConsumerStatefulWidget {
  const RepartosPage({super.key});

  @override
  ConsumerState<RepartosPage> createState() => _RepartosPageState();
}

class _RepartosPageState extends ConsumerState<RepartosPage> {
  int _dias = 1;
  String? _estado;
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final valor = ref.watch(repartosProvider(_dias));

    return Column(
      children: [
        BarraLista(
          pista: 'Buscar por ruta o repartidor',
          alBuscar: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
          filtros: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Hoy')),
                ButtonSegment(value: 7, label: Text('7 días')),
                ButtonSegment(value: 14, label: Text('14 días')),
              ],
              selected: {_dias},
              onSelectionChanged: (s) => setState(() => _dias = s.first),
            ),
            DropdownButton<String?>(
              value: _estado,
              hint: const Text('Todos los estados'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos los estados')),
                for (final e in ['carga', 'en_ruta', 'cerrado', 'cerrado_forzoso'])
                  DropdownMenuItem(value: e, child: Text(textoEstadoReparto(e))),
              ],
              onChanged: (v) => setState(() => _estado = v),
            ),
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(repartosProvider(_dias)),
            ),
          ],
        ),
        Expanded(
          child: VistaAsync(
            valor: valor,
            alReintentar: () => ref.invalidate(repartosProvider(_dias)),
            datos: (repartos) {
              final filtrados = repartos.where((r) {
                if (_estado != null && r.estado != _estado) return false;
                if (_busqueda.isEmpty) return true;
                return r.ruta.toLowerCase().contains(_busqueda) ||
                    r.repartidor.toLowerCase().contains(_busqueda);
              }).toList();
              if (filtrados.isEmpty) {
                return const ListaVacia(
                  'Aún no hay repartos en este periodo.\n'
                  'Aparecerán aquí en cuanto un repartidor empiece a cargar su ruta.',
                );
              }
              return ListView.separated(
                itemCount: filtrados.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _FilaReparto(filtrados[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilaReparto extends StatelessWidget {
  const _FilaReparto(this.r);

  final RepartoVista r;

  @override
  Widget build(BuildContext context) {
    final progreso = r.totalBultos == 0 ? 0.0 : r.entregados / r.totalBultos;
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
      title: Text('${r.ruta} · ${r.repartidor}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([
            fechaHora(r.iniciadoEn),
            '${r.totalBultos} bultos',
            '${r.entregados} entregados',
            if (r.pendientes > 0) '${r.pendientes} pendientes',
            if (r.noEntregados > 0) '${r.noEntregados} no entregados',
          ].join(' · ')),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progreso),
        ],
      ),
      trailing: EtiquetaReparto(r.estado),
      onTap: () => context.go('/admin/repartos/${r.id}'),
    );
  }
}

class RepartoDetallePage extends ConsumerStatefulWidget {
  const RepartoDetallePage({super.key, required this.repartoId});

  final String repartoId;

  @override
  ConsumerState<RepartoDetallePage> createState() => _RepartoDetallePageState();
}

class _RepartoDetallePageState extends ConsumerState<RepartoDetallePage> {
  String? _estado;
  String _busqueda = '';

  void _refrescar() {
    ref.invalidate(repartoProvider(widget.repartoId));
    ref.invalidate(bultosDeRepartoProvider(widget.repartoId));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return VistaAsync(
      valor: ref.watch(repartoProvider(widget.repartoId)),
      alReintentar: _refrescar,
      datos: (r) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Volver a repartos',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/admin/repartos'),
                ),
                Text('${r.ruta} · ${r.repartidor}', style: tema.textTheme.titleLarge),
                EtiquetaReparto(r.estado),
                IconButton(
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refrescar,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 24,
              runSpacing: 4,
              children: [
                Text('Inicio: ${fechaHora(r.iniciadoEn)}'),
                if (r.cargaConfirmadaEn != null) Text('Salida: ${fechaHora(r.cargaConfirmadaEn!)}'),
                if (r.cerradoEn != null) Text('Cierre: ${fechaHora(r.cerradoEn!)}'),
                Text('${r.entregados}/${r.totalBultos} entregados'),
                if (r.motivoCierre != null) Text('Motivo del cierre: ${r.motivoCierre}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar código o tienda',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
                  ),
                ),
                for (final e in [null, 'cargado', 'entregado', 'no_entregado', 'devolucion'])
                  ChoiceChip(
                    label: Text(e == null ? 'Todos' : textoEstadoBulto(e)),
                    selected: _estado == e,
                    onSelected: (_) => setState(() => _estado = e),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: VistaAsync(
              valor: ref.watch(bultosDeRepartoProvider(widget.repartoId)),
              alReintentar: _refrescar,
              datos: (bultos) {
                final filtrados = bultos.where((b) {
                  if (_estado != null && b.estado != _estado) return false;
                  if (_busqueda.isEmpty) return true;
                  return b.codigo.contains(_busqueda) ||
                      (b.tienda?.toLowerCase().contains(_busqueda) ?? false);
                }).toList();
                if (filtrados.isEmpty) return const ListaVacia('No hay bultos que mostrar.');

                return ListView.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final b = filtrados[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.qr_code_2),
                      title: Text(b.codigo, style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: Text([
                        'Cargado ${fechaHora(b.cargadoEn)}',
                        if (b.tienda != null) '${b.tienda}${b.cliente == null ? '' : ' (${b.cliente})'}',
                        if (b.entregadoEn != null) 'Entregado ${fechaHora(b.entregadoEn!)}',
                        ?b.motivo,
                      ].join(' · ')),
                      trailing: EtiquetaBulto(b.estado),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
