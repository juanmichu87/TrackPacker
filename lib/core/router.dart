import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_shell.dart';
import '../features/admin/ajustes_page.dart';
import '../features/admin/areas_page.dart';
import '../features/admin/clientes_page.dart';
import '../features/admin/repartos_page.dart';
import '../features/admin/resumen_page.dart';
import '../features/admin/ruta_detalle_page.dart';
import '../features/admin/rutas_page.dart';
import '../features/admin/tiendas_page.dart';
import '../features/admin/usuarios_page.dart';
import '../features/auth/inicio_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/sesion.dart';
import '../features/cliente/cliente_inicio_page.dart';
import '../features/repartidor/repartidor_inicio_page.dart';
import '../shared/shell_panel.dart';
import 'permisos.dart';

abstract final class Rutas {
  static const inicio = '/';
  static const login = '/login';
}

final routerProvider = Provider<GoRouter>((ref) {
  final sesion = ValueNotifier<EstadoSesion>(ref.read(sesionProvider));
  ref.listen(sesionProvider, (_, nuevo) => sesion.value = nuevo);
  ref.onDispose(sesion.dispose);

  return GoRouter(
    initialLocation: Rutas.inicio,
    refreshListenable: sesion,
    redirect: (context, estado) => redireccion(sesion.value, estado.uri),
    routes: [
      GoRoute(path: Rutas.inicio, builder: (_, _) => const InicioPage()),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (_, estado, child) => AdminShell(ubicacion: estado.matchedLocation, child: child),
        routes: [
          _pagina(AreaApp.admin.ruta, (_) => const ResumenPage()),
          _pagina('/admin/repartos', (_) => const RepartosPage()),
          _pagina(
            '/admin/repartos/:id',
            (e) => RepartoDetallePage(repartoId: e.pathParameters['id']!),
          ),
          _pagina('/admin/usuarios', (_) => const UsuariosPage()),
          _pagina('/admin/clientes', (_) => const ClientesPage()),
          _pagina('/admin/rutas', (_) => const RutasPage()),
          _pagina('/admin/rutas/:id', (e) => RutaDetallePage(rutaId: e.pathParameters['id']!)),
          _pagina('/admin/tiendas', (_) => const TiendasPage()),
          _pagina('/admin/areas', (_) => const AreasPage()),
          _pagina('/admin/ajustes', (_) => const AjustesPage()),
        ],
      ),
      // Repartidor y cliente usan la misma estructura de panel que el admin.
      // Para añadirles una pantalla: una SeccionPanel en su lista y su ruta aquí.
      ShellRoute(
        builder: (_, estado, child) => ShellPanel(
          area: AreaApp.repartidor.titulo,
          secciones: seccionesRepartidor,
          ubicacion: estado.matchedLocation,
          conBarraSuperior: false,
          child: child,
        ),
        routes: [_pagina(AreaApp.repartidor.ruta, (_) => const RepartidorInicioPage())],
      ),
      ShellRoute(
        builder: (_, estado, child) => ShellPanel(
          area: AreaApp.cliente.titulo,
          secciones: seccionesCliente,
          ubicacion: estado.matchedLocation,
          child: child,
        ),
        routes: [_pagina(AreaApp.cliente.ruta, (_) => const ClienteInicioPage())],
      ),
    ],
  );
});

const seccionesRepartidor = [
  SeccionPanel('/repartidor', 'Mi reparto', Icons.local_shipping_outlined),
];

const seccionesCliente = [SeccionPanel('/cliente', 'Mis entregas', Icons.inventory_2_outlined)];

/// Página del panel sin animación de transición (se cambia desde el menú).
GoRoute _pagina(String ruta, Widget Function(GoRouterState estado) pagina) => GoRoute(
  path: ruta,
  pageBuilder: (_, estado) => NoTransitionPage(key: estado.pageKey, child: pagina(estado)),
);

/// Cada usuario solo puede estar en la zona que le dan sus permisos.
///
/// Mientras se carga el perfil (o en el login) se recuerda en `?desde=` la
/// página pedida, para volver a ella después: así recargar el navegador en
/// /admin/rutas no te devuelve al resumen.
@visibleForTesting
String? redireccion(EstadoSesion sesion, Uri uri) {
  final ubicacion = uri.path;
  final destino = uri.queryParameters['desde'];

  String conDestino(String base) {
    final pendiente =
        destino ?? (ubicacion == Rutas.inicio || ubicacion == Rutas.login ? null : uri.toString());
    return pendiente == null
        ? base
        : Uri(path: base, queryParameters: {'desde': pendiente}).toString();
  }

  switch (sesion) {
    case SesionCargando() || ErrorSesion():
      return ubicacion == Rutas.inicio ? null : conDestino(Rutas.inicio);
    case SinSesion():
      return ubicacion == Rutas.login ? null : conDestino(Rutas.login);
    case SesionIniciada(:final perfil):
      final ruta = perfil.area!.ruta;
      bool dentro(String camino) => camino == ruta || camino.startsWith('$ruta/');
      if (dentro(ubicacion)) return null;
      if (destino != null && dentro(Uri.parse(destino).path)) return destino;
      return ruta;
  }
}
