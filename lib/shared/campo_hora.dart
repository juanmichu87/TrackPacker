import 'package:flutter/material.dart';

import '../core/salidas.dart';

/// Campo de hora (24 h) para escritorio: se escribe («7», «730», «7:30») o se
/// elige de una lista con sugerencias cada 15 minutos que se filtra al escribir.
class CampoHora extends StatefulWidget {
  const CampoHora({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
    this.icono = Icons.schedule,
  });

  final String etiqueta;

  /// Minutos desde medianoche.
  final int? valor;
  final ValueChanged<int> alCambiar;
  final IconData icono;

  @override
  State<CampoHora> createState() => _CampoHoraState();
}

class _CampoHoraState extends State<CampoHora> {
  static final _cadaCuartoDeHora = [for (var m = 0; m < 24 * 60; m += 15) m];

  late final _texto = TextEditingController(
    text: widget.valor == null ? '' : horaDeMinutos(widget.valor!),
  );
  late final _foco = FocusNode()..addListener(_alCambiarFoco);

  @override
  void dispose() {
    _foco
      ..removeListener(_alCambiarFoco)
      ..dispose();
    _texto.dispose();
    super.dispose();
  }

  /// Al salir del campo, la hora escrita se muestra normalizada (730 → 07:30).
  void _alCambiarFoco() {
    if (_foco.hasFocus) return;
    final minutos = parsearHora(_texto.text);
    if (minutos != null) _texto.text = horaDeMinutos(minutos);
  }

  Iterable<int> _sugerencias(TextEditingValue valor) {
    final digitos = valor.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return _cadaCuartoDeHora;
    final coinciden = _cadaCuartoDeHora.where((m) {
      final conCero = horaDeMinutos(m).replaceAll(':', ''); // 0730
      final sinCero = conCero.startsWith('0') ? conCero.substring(1) : conCero; // 730
      return conCero.startsWith(digitos) || sinCero.startsWith(digitos);
    }).toList();
    // Una hora exacta que no está en la lista (p. ej. 07:10) se ofrece la primera
    final exacta = parsearHora(valor.text);
    if (exacta != null && !coinciden.contains(exacta)) coinciden.insert(0, exacta);
    return coinciden;
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<int>(
      textEditingController: _texto,
      focusNode: _foco,
      optionsBuilder: _sugerencias,
      displayStringForOption: horaDeMinutos,
      onSelected: widget.alCambiar,
      fieldViewBuilder: (context, controlador, foco, alEnviar) => TextFormField(
        controller: controlador,
        focusNode: foco,
        decoration: InputDecoration(
          labelText: widget.etiqueta,
          hintText: 'HH:MM',
          prefixIcon: Icon(widget.icono),
          helperText: 'Escribe la hora o elígela',
        ),
        keyboardType: TextInputType.datetime,
        onChanged: (texto) {
          final minutos = parsearHora(texto);
          if (minutos != null) widget.alCambiar(minutos);
        },
        onFieldSubmitted: (_) => alEnviar(),
        validator: (texto) =>
            parsearHora(texto ?? '') == null ? 'Hora no válida (HH:MM, 24 h)' : null,
      ),
      optionsViewBuilder: (context, alElegir, opciones) {
        final resaltada = AutocompleteHighlightedOption.of(context);
        final lista = opciones.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 160),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: lista.length,
                itemBuilder: (context, i) => ListTile(
                  dense: true,
                  selected: i == resaltada,
                  title: Text(
                    horaDeMinutos(lista[i]),
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  onTap: () => alElegir(lista[i]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
