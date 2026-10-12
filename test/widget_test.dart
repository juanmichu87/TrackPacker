import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:track_pack/core/errores.dart';
import 'package:track_pack/core/permisos.dart';
import 'package:track_pack/core/router.dart';
import 'package:track_pack/features/admin/admin_shell.dart';
import 'package:track_pack/features/auth/auth_repository.dart';
import 'package:track_pack/features/auth/perfil.dart';
import 'package:track_pack/features/auth/sesion.dart';

Perfil _perfil(Set<String> permisos) =>
    Perfil(id: '1', usuario: 'prueba', rol: 'x', permisos: permisos);

void main() {
  group('emailDeUsuario', () {
    test('compone el email interno a partir del usuario', () {
      expect(emailDeUsuario('  Repartidor1 ', dominio: 'ejemplo.test'), 'repartidor1@ejemplo.test');
    });

    test('respeta un email completo', () {
      expect(emailDeUsuario('Ana@Empresa.com'), 'ana@empresa.com');
    });
  });

  group('AreaApp.para', () {
    test('asigna la zona según los permisos', () {
      expect(AreaApp.para({Permisos.usuariosGestionar, Permisos.repartosOperar}), AreaApp.admin);
      expect(AreaApp.para({Permisos.repartosOperar}), AreaApp.repartidor);
      expect(AreaApp.para({Permisos.incidenciasCrear}), AreaApp.cliente);
      expect(AreaApp.para({}), isNull);
    });
  });

  group('redireccion', () {
    String? ir(EstadoSesion sesion, String url) => redireccion(sesion, Uri.parse(url));
    final admin = SesionIniciada(_perfil({Permisos.usuariosGestionar}));

    test('sin sesión siempre va al login', () {
      expect(ir(const SinSesion(), '/'), '/login');
      expect(ir(const SinSesion(), '/login'), isNull);
    });

    test('mientras carga espera en la pantalla de inicio', () {
      expect(ir(const SesionCargando(), '/login'), '/');
      expect(ir(const ErrorSesion('x'), '/'), isNull);
    });

    test('al recargar una página interna vuelve a ella tras cargar el perfil', () {
      final espera = ir(const SesionCargando(), '/admin/rutas/abc')!;
      expect(Uri.parse(espera).path, '/');
      expect(ir(const SesionCargando(), espera), isNull);
      expect(ir(admin, espera), '/admin/rutas/abc');
    });

    test('sin sesión recuerda la página para después del login', () {
      final login = ir(const SinSesion(), '/admin/tiendas')!;
      expect(Uri.parse(login).path, '/login');
      expect(ir(admin, login), '/admin/tiendas');
    });

    test('no deja volver a una página de otra zona', () {
      final repartidor = SesionIniciada(_perfil({Permisos.repartosOperar}));
      expect(ir(repartidor, '/login?desde=%2Fadmin%2Fusuarios'), '/repartidor');
    });

    test('cada usuario queda confinado en su zona', () {
      final repartidor = SesionIniciada(_perfil({Permisos.repartosOperar}));
      expect(ir(repartidor, '/login'), '/repartidor');
      expect(ir(repartidor, '/admin'), '/repartidor');
      expect(ir(repartidor, '/repartidor'), isNull);
      expect(ir(repartidor, '/repartidor/carga'), isNull);
      expect(ir(repartidor, '/repartidorx'), '/repartidor');
    });
  });

  group('indiceSeccion', () {
    test('marca la sección correcta del menú, también en páginas de detalle', () {
      int indice(String ruta) => seccionesAdmin.indexWhere((s) => s.ruta == ruta);
      expect(indiceSeccion('/admin'), indice('/admin'));
      expect(indiceSeccion('/admin/rutas'), indice('/admin/rutas'));
      expect(indiceSeccion('/admin/rutas/123'), indice('/admin/rutas'));
      expect(indiceSeccion('/admin/repartos/abc'), indice('/admin/repartos'));
    });
  });

  group('mensajeError', () {
    test('usa el mensaje de nuestras funciones SQL', () {
      expect(
        mensajeError(const PostgrestException(message: 'No puedes eliminar tu propio usuario', code: 'P0001')),
        'No puedes eliminar tu propio usuario',
      );
    });

    test('traduce restricciones conocidas', () {
      expect(
        mensajeError(const PostgrestException(
          message: 'new row violates check constraint "cliente_requerido"',
          code: '23514',
        )),
        contains('empresa asignada'),
      );
      expect(mensajeError(const PostgrestException(message: 'x', code: '23503')), contains('desactívalo'));
    });

    test('muestra errores de validación tal cual', () {
      expect(mensajeError(const ErrorValidacion('Falta algo')), 'Falta algo');
    });
  });
}
