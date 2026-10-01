import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/ui.dart';
import '../auth/sesion.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';

class UsuariosPage extends ConsumerStatefulWidget {
  const UsuariosPage({super.key});

  @override
  ConsumerState<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends ConsumerState<UsuariosPage> {
  String _busqueda = '';
  String? _rol;

  void _refrescar() {
    ref.invalidate(usuariosProvider);
    ref.invalidate(resumenProvider);
  }

  Future<void> _editar([UsuarioAdmin? usuario]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _UsuarioDialogo(usuario: usuario),
    );
    if (guardado == true) _refrescar();
  }

  Future<void> _cambiarContrasena(UsuarioAdmin usuario) async {
    await showDialog<bool>(context: context, builder: (_) => _ContrasenaDialogo(usuario: usuario));
  }

  Future<void> _cambiarActivo(UsuarioAdmin u) async {
    final activar = !u.activo;
    if (!activar &&
        !await confirmar(
          context,
          titulo: 'Desactivar usuario',
          mensaje: '${u.nombreVisible} no podrá iniciar sesión y se cerrarán sus sesiones abiertas. '
              'Su historial se conserva y puedes reactivarlo cuando quieras.',
          accion: 'Desactivar',
          peligroso: true,
        )) {
      return;
    }
    if (!mounted) return;
    final ok = await ejecutar(
      context,
      () => ref.read(adminRepositoryProvider).actualizarUsuario(
        id: u.id,
        usuario: u.usuario,
        rol: u.rol,
        activo: activar,
        nombreCompleto: u.nombreCompleto,
        email: u.email,
        telefono: u.telefono,
        clienteId: u.clienteId,
      ),
      exito: activar ? 'Usuario activado' : 'Usuario desactivado',
    );
    if (ok) _refrescar();
  }

  Future<void> _eliminar(UsuarioAdmin u) async {
    if (!await confirmar(
      context,
      titulo: 'Eliminar usuario',
      mensaje: 'Se eliminará "${u.usuario}" definitivamente. Si tiene repartos o incidencias '
          'registrados no se podrá eliminar; en ese caso, desactívalo.',
      accion: 'Eliminar',
      peligroso: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await ejecutar(
      context,
      () => ref.read(adminRepositoryProvider).eliminarUsuario(u.id),
      exito: 'Usuario eliminado',
    );
    if (ok) _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).value ?? const <Rol>[];
    final nombresRol = {for (final r in roles) r.codigo: r.nombre};
    final sesion = ref.watch(sesionProvider);
    final miId = sesion is SesionIniciada ? sesion.perfil.id : null;

    return Column(
      children: [
        BarraLista(
          pista: 'Buscar por usuario, nombre o email',
          alBuscar: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
          filtros: [
            DropdownButton<String?>(
              value: _rol,
              hint: const Text('Todos los roles'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos los roles')),
                for (final r in roles) DropdownMenuItem(value: r.codigo, child: Text(r.nombre)),
              ],
              onChanged: (v) => setState(() => _rol = v),
            ),
          ],
          textoNuevo: 'Nuevo usuario',
          alNuevo: () => _editar(),
        ),
        Expanded(
          child: VistaAsync(
            valor: ref.watch(usuariosProvider),
            alReintentar: _refrescar,
            datos: (usuarios) {
              final filtrados = usuarios.where((u) {
                if (_rol != null && u.rol != _rol) return false;
                if (_busqueda.isEmpty) return true;
                return [u.usuario, u.nombreCompleto, u.email, u.clienteNombre]
                    .any((c) => c?.toLowerCase().contains(_busqueda) ?? false);
              }).toList();
              if (filtrados.isEmpty) return const ListaVacia('No hay usuarios que mostrar.');

              return ListView.separated(
                itemCount: filtrados.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = filtrados[i];
                  final esYo = u.id == miId;
                  final detalles = [
                    '@${u.usuario}',
                    nombresRol[u.rol] ?? u.rol,
                    ?u.clienteNombre,
                    ?u.email,
                    ?u.telefono,
                  ];
                  return ListTile(
                    leading: CircleAvatar(child: Icon(_iconoRol(u.rol))),
                    title: Text(esYo ? '${u.nombreVisible} (tú)' : u.nombreVisible),
                    subtitle: Text(detalles.join(' · ')),
                    onTap: () => _editar(u),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EtiquetaActivo(u.activo),
                        MenuFila([
                          OpcionMenu('Editar', Icons.edit_outlined, () => _editar(u)),
                          OpcionMenu('Cambiar contraseña', Icons.password, () => _cambiarContrasena(u)),
                          if (!esYo)
                            OpcionMenu(
                              u.activo ? 'Desactivar' : 'Activar',
                              u.activo ? Icons.block : Icons.check_circle_outline,
                              () => _cambiarActivo(u),
                            ),
                          if (!esYo)
                            OpcionMenu('Eliminar', Icons.delete_outline, () => _eliminar(u),
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

IconData _iconoRol(String rol) => switch (rol) {
  'admin' => Icons.admin_panel_settings_outlined,
  'repartidor' => Icons.local_shipping_outlined,
  'cliente' => Icons.storefront_outlined,
  _ => Icons.person_outline,
};

class _UsuarioDialogo extends ConsumerStatefulWidget {
  const _UsuarioDialogo({this.usuario});

  final UsuarioAdmin? usuario;

  @override
  ConsumerState<_UsuarioDialogo> createState() => _UsuarioDialogoState();
}

class _UsuarioDialogoState extends ConsumerState<_UsuarioDialogo> {
  late final _usuario = TextEditingController(text: widget.usuario?.usuario);
  late final _contrasena = TextEditingController();
  late final _nombre = TextEditingController(text: widget.usuario?.nombreCompleto);
  late final _email = TextEditingController(text: widget.usuario?.email);
  late final _telefono = TextEditingController(text: widget.usuario?.telefono);
  late String? _rol = widget.usuario?.rol;
  late String? _clienteId = widget.usuario?.clienteId;
  late bool _activo = widget.usuario?.activo ?? true;

  bool get _esNuevo => widget.usuario == null;

  @override
  void dispose() {
    for (final c in [_usuario, _contrasena, _nombre, _email, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() {
    final repo = ref.read(adminRepositoryProvider);
    final clienteId = _rol == 'cliente' ? _clienteId : null;
    return _esNuevo
          ? repo.crearUsuario(
              usuario: _usuario.text,
              contrasena: _contrasena.text,
              rol: _rol!,
              nombreCompleto: textoONulo(_nombre.text),
              email: textoONulo(_email.text),
              telefono: textoONulo(_telefono.text),
              clienteId: clienteId,
            )
          : repo.actualizarUsuario(
              id: widget.usuario!.id,
              usuario: _usuario.text,
              rol: _rol!,
              activo: _activo,
              nombreCompleto: textoONulo(_nombre.text),
              email: textoONulo(_email.text),
              telefono: textoONulo(_telefono.text),
              clienteId: clienteId,
            );
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).value ?? const <Rol>[];
    final clientes = ref.watch(clientesProvider).value ?? const <Cliente>[];

    return DialogoFormulario(
      titulo: _esNuevo ? 'Nuevo usuario' : 'Editar usuario',
      alGuardar: _guardar,
      exito: _esNuevo ? 'Usuario creado' : 'Usuario actualizado',
      campos: [
        TextFormField(
          controller: _usuario,
          decoration: const InputDecoration(
            labelText: 'Usuario (para iniciar sesión)',
            helperText: 'Minúsculas, números, punto, guion o guion bajo',
          ),
          autocorrect: false,
          validator: (v) {
            final t = v?.trim().toLowerCase() ?? '';
            return RegExp(r'^[a-z0-9._-]{3,32}$').hasMatch(t)
                ? null
                : 'Entre 3 y 32 caracteres: minúsculas, números, punto, guion o guion bajo';
          },
        ),
        if (_esNuevo)
          TextFormField(
            controller: _contrasena,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            obscureText: true,
            validator: (v) => (v?.length ?? 0) < 8 ? 'Mínimo 8 caracteres' : null,
          ),
        TextFormField(
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _rol,
          decoration: const InputDecoration(labelText: 'Rol'),
          items: [
            for (final r in roles) DropdownMenuItem(value: r.codigo, child: Text(r.nombre)),
          ],
          onChanged: (v) => setState(() => _rol = v),
          validator: (v) => v == null ? 'Elige un rol' : null,
        ),
        if (_rol == 'cliente')
          DropdownButtonFormField<String>(
            initialValue: _clienteId,
            decoration: const InputDecoration(labelText: 'Empresa cliente'),
            items: [
              for (final c in clientes) DropdownMenuItem(value: c.id, child: Text(c.nombre)),
            ],
            onChanged: (v) => setState(() => _clienteId = v),
            validator: (v) => v == null ? 'Elige la empresa' : null,
          ),
        TextFormField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Correo de contacto (opcional)'),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final t = v?.trim() ?? '';
            return t.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                ? null
                : 'Correo no válido';
          },
        ),
        TextFormField(
          controller: _telefono,
          decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
          keyboardType: TextInputType.phone,
        ),
        if (!_esNuevo)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo'),
            subtitle: const Text('Si se desactiva, no podrá iniciar sesión'),
            value: _activo,
            onChanged: (v) => setState(() => _activo = v),
          ),
      ],
    );
  }
}

class _ContrasenaDialogo extends ConsumerStatefulWidget {
  const _ContrasenaDialogo({required this.usuario});

  final UsuarioAdmin usuario;

  @override
  ConsumerState<_ContrasenaDialogo> createState() => _ContrasenaDialogoState();
}

class _ContrasenaDialogoState extends ConsumerState<_ContrasenaDialogo> {
  final _contrasena = TextEditingController();
  final _repetir = TextEditingController();

  @override
  void dispose() {
    _contrasena.dispose();
    _repetir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: 'Contraseña de ${widget.usuario.nombreVisible}',
      textoGuardar: 'Cambiar',
      alGuardar: () =>
          ref.read(adminRepositoryProvider).cambiarContrasena(widget.usuario.id, _contrasena.text),
      exito: 'Contraseña cambiada. Se han cerrado sus sesiones abiertas.',
      campos: [
        TextFormField(
          controller: _contrasena,
          decoration: const InputDecoration(labelText: 'Nueva contraseña'),
          obscureText: true,
          validator: (v) => (v?.length ?? 0) < 8 ? 'Mínimo 8 caracteres' : null,
        ),
        TextFormField(
          controller: _repetir,
          decoration: const InputDecoration(labelText: 'Repetir contraseña'),
          obscureText: true,
          validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden' : null,
        ),
      ],
    );
  }
}
