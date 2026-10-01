import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/ui.dart';
import 'datos/admin_repository.dart';
import 'datos/modelos.dart';

class AjustesPage extends ConsumerWidget {
  const AjustesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VistaAsync(
      valor: ref.watch(ajustesProvider),
      alReintentar: () => ref.invalidate(ajustesProvider),
      datos: (ajustes) => _FormularioAjustes(ajustes),
    );
  }
}

class _FormularioAjustes extends ConsumerStatefulWidget {
  const _FormularioAjustes(this.ajustes);

  final Ajustes ajustes;

  @override
  ConsumerState<_FormularioAjustes> createState() => _FormularioAjustesState();
}

class _FormularioAjustesState extends ConsumerState<_FormularioAjustes> {
  final _formulario = GlobalKey<FormState>();
  late final _fotos = TextEditingController(text: '${widget.ajustes.diasRetencionFotos}');
  late final _bultos = TextEditingController(text: '${widget.ajustes.diasRetencionBultos}');
  bool _guardando = false;

  @override
  void dispose() {
    _fotos.dispose();
    _bultos.dispose();
    super.dispose();
  }

  String? Function(String?) _rango(int min, int max) => (v) {
    final n = int.tryParse(v?.trim() ?? '');
    return n == null || n < min || n > max ? 'Entre $min y $max días' : null;
  };

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    final fotos = int.parse(_fotos.text.trim());
    final bultos = int.parse(_bultos.text.trim());
    if (fotos > bultos) {
      mostrarMensaje(context, 'Las fotos no pueden guardarse más días que los bultos.', error: true);
      return;
    }
    setState(() => _guardando = true);
    final ok = await ejecutar(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .guardarAjustes(diasFotos: fotos, diasBultos: bultos),
      exito: 'Ajustes guardados',
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) ref.invalidate(ajustesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conservación de datos', style: tema.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Cada noche se borran automáticamente los datos más antiguos que estos plazos '
                  'para ahorrar espacio. Lo borrado no se puede recuperar.',
                  style: tema.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _bultos,
                  decoration: const InputDecoration(
                    labelText: 'Días que se guardan los bultos y repartos',
                    suffixText: 'días',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _rango(7, 1825),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fotos,
                  decoration: const InputDecoration(
                    labelText: 'Días que se guardan las fotos de entrega',
                    suffixText: 'días',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _rango(1, 365),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
