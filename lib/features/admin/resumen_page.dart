import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui.dart';
import 'datos/admin_repository.dart';

class ResumenPage extends ConsumerWidget {
  const ResumenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VistaAsync(
      valor: ref.watch(resumenProvider),
      alReintentar: () => ref.invalidate(resumenProvider),
      datos: (r) => RefreshIndicator(
        onRefresh: () => ref.refresh(resumenProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text('Hoy', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(resumenProvider),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (r.bultosHoy == 0 && r.repartosAbiertos == 0)
              const _Aviso(
                Icons.info_outline,
                'Aún no hay repartos hoy. Los datos aparecerán en cuanto un repartidor '
                'empiece a cargar su ruta.',
              ),
            if (r.clientes == 0 || r.rutas == 0 || r.tiendas == 0)
              const _Aviso(
                Icons.lightbulb_outline,
                'Para empezar, crea al menos un cliente, una ruta y sus tiendas, '
                'y un usuario repartidor.',
              ),
            _Tarjetas([
              _Dato('Bultos cargados', r.bultosHoy, Icons.inventory_2_outlined, '/admin/repartos'),
              _Dato('Entregados', r.entregadosHoy, Icons.check_circle_outline, '/admin/repartos',
                  color: Colors.green),
              _Dato('Pendientes', r.pendientesHoy, Icons.schedule, '/admin/repartos',
                  color: Colors.blue),
              _Dato('No entregados', r.noEntregadosHoy, Icons.report_outlined, '/admin/repartos',
                  color: r.noEntregadosHoy > 0 ? Colors.red : null),
              _Dato('Repartos en curso', r.repartosAbiertos, Icons.local_shipping_outlined,
                  '/admin/repartos'),
              _Dato('Incidencias abiertas', r.incidenciasAbiertas, Icons.forum_outlined, null,
                  color: r.incidenciasAbiertas > 0 ? Colors.orange : null),
            ]),
            const SizedBox(height: 24),
            Text('Configuración', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _Tarjetas([
              for (final MapEntry(:key, :value) in r.usuariosPorRol.entries)
                _Dato('Usuarios · $key', value, Icons.person_outline, '/admin/usuarios'),
              if (r.usuariosInactivos > 0)
                _Dato('Usuarios inactivos', r.usuariosInactivos, Icons.person_off_outlined,
                    '/admin/usuarios', color: Colors.grey),
              _Dato('Clientes', r.clientes, Icons.business_outlined, '/admin/clientes'),
              _Dato('Rutas', r.rutas, Icons.alt_route, '/admin/rutas'),
              _Dato('Tiendas', r.tiendas, Icons.storefront_outlined, '/admin/tiendas'),
              _Dato('Tiendas sin ruta', r.tiendasSinRuta, Icons.wrong_location_outlined,
                  '/admin/tiendas', color: r.tiendasSinRuta > 0 ? Colors.orange : null),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Dato {
  const _Dato(this.titulo, this.valor, this.icono, this.ruta, {this.color});

  final String titulo;
  final int valor;
  final IconData icono;
  final String? ruta;
  final Color? color;
}

class _Tarjetas extends StatelessWidget {
  const _Tarjetas(this.datos);

  final List<_Dato> datos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final d in datos)
          SizedBox(
            width: 200,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: d.ruta == null ? null : () => context.go(d.ruta!),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(d.icono, color: d.color ?? tema.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        '${d.valor}',
                        style: tema.textTheme.headlineMedium?.copyWith(color: d.color),
                      ),
                      Text(d.titulo, style: tema.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(leading: Icon(icono), title: Text(texto)),
    ),
  );
}
