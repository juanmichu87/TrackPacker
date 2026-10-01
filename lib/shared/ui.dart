import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errores.dart';

/// Muestra carga, error (con reintentar) o los datos de un AsyncValue.
class VistaAsync<T> extends StatelessWidget {
  const VistaAsync({
    super.key,
    required this.valor,
    required this.datos,
    this.alReintentar,
  });

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
              ? FilledButton.styleFrom(backgroundColor: colores.error, foregroundColor: colores.onError)
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
    return AlertDialog(
      title: Text(widget.titulo),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.textoGuardar),
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              decoration: InputDecoration(
                hintText: pista,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: alBuscar,
            ),
          ),
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
    child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class EtiquetaActivo extends StatelessWidget {
  const EtiquetaActivo(this.activo, {super.key});

  final bool activo;

  @override
  Widget build(BuildContext context) => activo
      ? const Etiqueta('Activo', color: Colors.green)
      : const Etiqueta('Inactivo', color: Colors.grey);
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
