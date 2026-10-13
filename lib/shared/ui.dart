import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errores.dart';
import '../core/tema.dart';
import 'responsive.dart';

/// Pantalla estrecha (móvil en vertical).
bool esMovil(BuildContext context) => context.esPantallaMovil;

/// Ventana emergente adaptable: en el móvil, panel inferior que se desliza;
/// en tablet y ordenador, ventana centrada con botón de cerrar, como en una
/// app de escritorio. El contenido es el mismo en los dos casos.
Future<T?> mostrarPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double anchoMaximo = 520,
}) {
  if (esMovil(context)) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (contexto) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20),
              child: builder(contexto),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(contexto),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Muestra carga, error (con reintentar) o los datos de un AsyncValue.
class VistaAsync<T> extends StatelessWidget {
  const VistaAsync({super.key, required this.valor, required this.datos, this.alReintentar});

  final AsyncValue<T> valor;
  final Widget Function(T datos) datos;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      data: datos,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(mensajeError(e), textAlign: TextAlign.center),
              if (alReintentar != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: alReintentar, child: const Text('Reintentar')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  final colores = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? colores.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Ejecuta una acción mostrando el error (si lo hay) o un mensaje de éxito.
/// Devuelve true si fue bien.
Future<bool> ejecutar(BuildContext context, Future<void> Function() accion, {String? exito}) async {
  try {
    await accion();
    if (exito != null && context.mounted) mostrarMensaje(context, exito);
    return true;
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, mensajeError(e), error: true);
    return false;
  }
}

/// Confirmación reforzada para borrados irreversibles: hay que escribir
/// `palabra` (p. ej. el nombre de usuario) para habilitar el botón.
Future<bool> confirmarEscribiendo(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String palabra,
  String accion = 'Eliminar definitivamente',
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _ConfirmacionEscrita(titulo: titulo, mensaje: mensaje, palabra: palabra, accion: accion),
  );
  return resultado ?? false;
}

class _ConfirmacionEscrita extends StatefulWidget {
  const _ConfirmacionEscrita({
    required this.titulo,
    required this.mensaje,
    required this.palabra,
    required this.accion,
  });

  final String titulo;
  final String mensaje;
  final String palabra;
  final String accion;

  @override
  State<_ConfirmacionEscrita> createState() => _ConfirmacionEscritaState();
}

class _ConfirmacionEscritaState extends State<_ConfirmacionEscrita> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final coincide = _texto.text.trim() == widget.palabra;
    return AlertDialog(
      icon: Icon(Icons.delete_forever, color: colores.error, size: 40),
      title: Text(widget.titulo),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.mensaje),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Para confirmar, escribe '),
                  TextSpan(
                    text: widget.palabra,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _texto,
              autofocus: true,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colores.error,
            foregroundColor: colores.onError,
          ),
          onPressed: coincide ? () => Navigator.pop(context, true) : null,
          child: Text(widget.accion),
        ),
      ],
    );
  }
}

/// Diálogo de confirmación. `peligroso` pinta el botón en rojo.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String accion = 'Confirmar',
  bool peligroso = false,
}) async {
  final colores = Theme.of(context).colorScheme;
  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: peligroso
              ? FilledButton.styleFrom(
                  backgroundColor: colores.error,
                  foregroundColor: colores.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(accion),
        ),
      ],
    ),
  );
  return resultado ?? false;
}

/// Diálogo con formulario: valida, ejecuta `alGuardar` y muestra el error
/// dentro del propio diálogo. Si va bien, se cierra devolviendo true y muestra
/// `exito` en la parte inferior de la pantalla.
class DialogoFormulario extends StatefulWidget {
  const DialogoFormulario({
    super.key,
    required this.titulo,
    required this.campos,
    required this.alGuardar,
    this.exito,
    this.textoGuardar = 'Guardar',
  });

  final String titulo;
  final List<Widget> campos;
  final Future<void> Function() alGuardar;
  final String? exito;
  final String textoGuardar;

  @override
  State<DialogoFormulario> createState() => _DialogoFormularioState();
}

class _DialogoFormularioState extends State<DialogoFormulario> {
  final _formulario = GlobalKey<FormState>();
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await widget.alGuardar();
      if (!mounted) return;
      Navigator.pop(context, true);
      if (widget.exito != null) {
        mensajero.showSnackBar(
          SnackBar(content: Text(widget.exito!), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final formulario = Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final campo in widget.campos)
            Padding(padding: const EdgeInsets.only(bottom: 16), child: campo),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colores.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(color: colores.onErrorContainer)),
            ),
        ],
      ),
    );
    final botonGuardar = FilledButton(
      onPressed: _guardando ? null : _guardar,
      child: _guardando
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(widget.textoGuardar),
    );

    // En el móvil, a pantalla completa: más sitio y el teclado no tapa los campos
    if (esMovil(context)) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Cancelar',
              icon: const Icon(Icons.close),
              onPressed: _guardando ? null : () => Navigator.pop(context, false),
            ),
            title: Text(widget.titulo),
            actions: [Padding(padding: const EdgeInsets.only(right: 12), child: botonGuardar)],
          ),
          body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: formulario),
        ),
      );
    }

    return AlertDialog(
      title: Text(widget.titulo),
      scrollable: true,
      content: SizedBox(width: 480, child: formulario),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        botonGuardar,
      ],
    );
  }
}

/// Validador de campo obligatorio.
String? obligatorio(String? valor) =>
    (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

/// null si el texto está vacío.
String? textoONulo(String texto) => texto.trim().isEmpty ? null : texto.trim();

/// Cabecera de las páginas de lista: buscador, filtros y botón de alta.
class BarraLista extends StatelessWidget {
  const BarraLista({
    super.key,
    required this.alBuscar,
    this.pista = 'Buscar',
    this.filtros = const [],
    this.textoNuevo,
    this.alNuevo,
  });

  final ValueChanged<String> alBuscar;
  final String pista;
  final List<Widget> filtros;
  final String? textoNuevo;
  final VoidCallback? alNuevo;

  @override
  Widget build(BuildContext context) {
    final buscador = TextField(
      decoration: InputDecoration(
        hintText: pista,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
      ),
      onChanged: alBuscar,
    );

    // Móvil: buscador a todo el ancho con el botón de alta al lado y los
    // filtros debajo, desplazables en horizontal.
    if (esMovil(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: buscador),
                if (alNuevo != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: textoNuevo ?? 'Nuevo',
                    onPressed: alNuevo,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ],
            ),
            if (filtros.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    for (final f in filtros)
                      Padding(padding: const EdgeInsets.only(right: 12), child: f),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 320, child: buscador),
          ...filtros,
          if (alNuevo != null)
            FilledButton.icon(
              onPressed: alNuevo,
              icon: const Icon(Icons.add),
              label: Text(textoNuevo ?? 'Nuevo'),
            ),
        ],
      ),
    );
  }
}

/// Mensaje centrado para listas vacías.
class ListaVacia extends StatelessWidget {
  const ListaVacia(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(texto, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
    ),
  );
}

/// Etiqueta de color para estados.
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Text(
      texto,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class EtiquetaActivo extends StatelessWidget {
  const EtiquetaActivo(this.activo, {super.key});

  final bool activo;

  /// En el móvil solo se marca lo inactivo (lo normal es estar activo), para
  /// dejar más sitio al nombre en las filas.
  @override
  Widget build(BuildContext context) {
    if (!activo) return const Etiqueta('Inactivo', color: ColoresEstado.neutro);
    if (esMovil(context)) return const SizedBox.shrink();
    return const Etiqueta('Activo', color: ColoresEstado.correcto);
  }
}

/// Opción de un menú contextual (tres puntos) de una fila.
class OpcionMenu {
  const OpcionMenu(this.texto, this.icono, this.accion, {this.peligrosa = false});

  final String texto;
  final IconData icono;
  final VoidCallback accion;
  final bool peligrosa;
}

class MenuFila extends StatelessWidget {
  const MenuFila(this.opciones, {super.key});

  final List<OpcionMenu> opciones;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<int>(
      tooltip: 'Acciones',
      onSelected: (i) => opciones[i].accion(),
      itemBuilder: (_) => [
        for (final (i, o) in opciones.indexed)
          PopupMenuItem(
            value: i,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(o.icono, color: o.peligrosa ? error : null),
              title: Text(o.texto, style: o.peligrosa ? TextStyle(color: error) : null),
            ),
          ),
      ],
    );
  }
}
