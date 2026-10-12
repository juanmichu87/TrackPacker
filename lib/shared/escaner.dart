import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/codigos.dart';
import '../core/formato.dart';
import '../core/plataforma/plataforma.dart';

/// Resultado de leer un código: contenido y formato (null si se escribió a mano
/// o el escáner no lo identifica).
class LecturaCodigo {
  const LecturaCodigo(this.contenido, this.formato);

  final String contenido;
  final String? formato;

  String get nombreFormato =>
      formato == null ? 'Desconocido' : formatosCodigo[formato] ?? formato!;
}

/// Abre el escáner a pantalla completa, lee un único código y lo devuelve.
/// `formatos` limita los formatos buscados (códigos de la BD); null = todos.
Future<LecturaCodigo?> leerCodigo(
  BuildContext context, {
  String titulo = 'Escanear código',
  List<String>? formatos,
}) => Navigator.of(context).push<LecturaCodigo>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _PantallaLecturaUnica(titulo: titulo, formatos: formatos),
  ),
);

class _PantallaLecturaUnica extends StatefulWidget {
  const _PantallaLecturaUnica({required this.titulo, this.formatos});

  final String titulo;
  final List<String>? formatos;

  @override
  State<_PantallaLecturaUnica> createState() => _PantallaLecturaUnicaState();
}

class _PantallaLecturaUnicaState extends State<_PantallaLecturaUnica> {
  bool _terminado = false;

  void _devolver(LecturaCodigo lectura) {
    if (_terminado) return;
    _terminado = true;
    vibrar();
    Navigator.of(context).pop(lectura);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: VistaEscaner(formatos: widget.formatos, alLeer: _devolver),
            ),
            LeerDeFoto(formatos: widget.formatos, alLeer: _devolver),
            EntradaManual(alEnviar: (texto) => _devolver(LecturaCodigo(texto, null))),
          ],
        ),
      ),
    );
  }
}

/// Cámara con recuadro de lectura, linterna, zoom y cambio de cámara.
/// Llama a `alLeer` con cada código nuevo; el mismo código no se repite hasta
/// pasados `pausaMismoCodigo` (la cámara lo ve muchas veces por segundo).
class VistaEscaner extends StatefulWidget {
  const VistaEscaner({
    super.key,
    required this.alLeer,
    this.formatos,
    this.pausaMismoCodigo = const Duration(seconds: 2),
  });

  final void Function(LecturaCodigo lectura) alLeer;
  final List<String>? formatos;
  final Duration pausaMismoCodigo;

  @override
  State<VistaEscaner> createState() => _VistaEscanerState();
}

class _VistaEscanerState extends State<VistaEscaner> {
  late final MobileScannerController _controlador = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: [
      for (final f in widget.formatos ?? formatosEscaner.keys) ?formatosEscaner[f],
    ],
    // Resolución alta: los códigos lineales largos (Code 39, 128) necesitan
    // muchos píxeles para distinguir barras finas.
    cameraResolution: const Size(1920, 1080),
  );

  String? _ultimo;
  DateTime _ultimoEn = DateTime(2000);
  bool _destello = false;
  Timer? _temporizadorDestello;
  double _zoom = 0;

  @override
  void dispose() {
    _temporizadorDestello?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    for (final codigo in captura.barcodes) {
      final valor = codigo.rawValue?.trim();
      if (valor == null || valor.isEmpty) continue;

      final ahora = DateTime.now();
      if (valor == _ultimo && ahora.difference(_ultimoEn) < widget.pausaMismoCodigo) continue;
      _ultimo = valor;
      _ultimoEn = ahora;

      setState(() => _destello = true);
      _temporizadorDestello?.cancel();
      _temporizadorDestello = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _destello = false);
      });

      widget.alLeer(LecturaCodigo(valor, formatoDesdeEscaner(codigo.format)));
      return;
    }
  }

  Future<void> _cambiarZoom(double valor) async {
    setState(() => _zoom = valor);
    try {
      await _controlador.setZoomScale(valor);
    } catch (_) {
      // Algunos navegadores no permiten zoom: se ignora.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!contextoSeguro) {
      return const _MensajeCamara(
        icono: Icons.lock_open,
        texto: 'El navegador no permite usar la cámara en esta dirección. '
            'Abre la app con https:// (o desde localhost).',
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controlador,
          fit: BoxFit.cover,
          onDetect: _alDetectar,
          errorBuilder: (context, error) => _ErrorCamara(error),
          placeholderBuilder: (context) => const _MensajeCamara(
            icono: Icons.photo_camera_outlined,
            texto: 'Abriendo la cámara…\nSi el navegador lo pide, permite el acceso.',
          ),
        ),
        IgnorePointer(child: CustomPaint(painter: _MarcoLectura(destello: _destello))),
        const Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Text(
            'Coloca el código completo dentro del recuadro, en horizontal',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              shadows: [Shadow(blurRadius: 4)],
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: _Controles(
            controlador: _controlador,
            zoom: _zoom,
            alCambiarZoom: _cambiarZoom,
          ),
        ),
      ],
    );
  }
}

/// Oscurece todo menos un recuadro horizontal (para códigos lineales).
class _MarcoLectura extends CustomPainter {
  const _MarcoLectura({required this.destello});

  final bool destello;

  static Rect recuadro(Size tamano) {
    final ancho = tamano.width * 0.9;
    final alto = (tamano.height * 0.3).clamp(120.0, 260.0);
    return Rect.fromCenter(center: tamano.center(Offset.zero), width: ancho, height: alto);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final hueco = RRect.fromRectAndRadius(recuadro(size), const Radius.circular(12));
    final mascara = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(hueco)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mascara, Paint()..color = Colors.black54);
    canvas.drawRRect(
      hueco,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = destello ? 6 : 3
        ..color = destello ? Colors.greenAccent : Colors.white,
    );
  }

  @override
  bool shouldRepaint(_MarcoLectura anterior) => anterior.destello != destello;
}

class _Controles extends StatelessWidget {
  const _Controles({required this.controlador, required this.zoom, required this.alCambiarZoom});

  final MobileScannerController controlador;
  final double zoom;
  final ValueChanged<double> alCambiarZoom;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controlador,
      builder: (context, estado, _) {
        if (!estado.isRunning) return const SizedBox.shrink();
        final linterna = estado.torchState;
        return Row(
          children: [
            if (linterna != TorchState.unavailable)
              IconButton.filledTonal(
                tooltip: 'Linterna',
                icon: Icon(linterna == TorchState.on ? Icons.flash_on : Icons.flash_off),
                onPressed: controlador.toggleTorch,
              ),
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.zoom_out, color: Colors.white),
                  Expanded(child: Slider(value: zoom, onChanged: alCambiarZoom)),
                  const Icon(Icons.zoom_in, color: Colors.white),
                ],
              ),
            ),
            if ((estado.availableCameras ?? 2) > 1)
              IconButton.filledTonal(
                tooltip: 'Cambiar de cámara',
                icon: const Icon(Icons.cameraswitch_outlined),
                onPressed: controlador.switchCamera,
              ),
          ],
        );
      },
    );
  }
}

/// Botones para leer el código desde una foto: la cámara del móvil enfoca y
/// usa toda su resolución, así que lee códigos que en vídeo cuestan.
class LeerDeFoto extends StatefulWidget {
  const LeerDeFoto({super.key, required this.alLeer, this.formatos});

  final void Function(LecturaCodigo lectura) alLeer;
  final List<String>? formatos;

  @override
  State<LeerDeFoto> createState() => _LeerDeFotoState();
}

class _LeerDeFotoState extends State<LeerDeFoto> {
  bool _analizando = false;

  Future<void> _leer(ImageSource origen) async {
    final mensajero = ScaffoldMessenger.of(context);
    void avisar(String texto) => mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));

    final XFile? foto;
    try {
      foto = await ImagePicker().pickImage(source: origen, maxWidth: 2400, imageQuality: 95);
    } catch (_) {
      avisar('No se pudo abrir la cámara o la galería.');
      return;
    }
    if (foto == null || !mounted) return;

    setState(() => _analizando = true);
    try {
      final codigos = await leerCodigosDeFoto(foto, formatos: widget.formatos);
      if (!mounted) return;
      if (codigos.isEmpty) {
        vibrar(larga: true);
        avisar('No se encontró ningún código en la foto. Haz la foto más cerca, '
            'enfocada y con el código entero.');
        return;
      }
      final elegido = codigos.length == 1 ? codigos.first : await _elegir(codigos);
      if (elegido != null) widget.alLeer(LecturaCodigo(elegido.contenido, elegido.formato));
    } catch (e) {
      avisar(e is StateError ? e.message : 'No se pudo analizar la foto.');
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  /// Si la foto tiene varios códigos (p. ej. una etiqueta con dos), se elige uno.
  Future<({String contenido, String? formato})?> _elegir(
    List<({String contenido, String? formato})> codigos,
  ) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (hoja) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('La foto tiene varios códigos. ¿Cuál es el del bulto?')),
          for (final c in codigos)
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(c.contenido),
              subtitle: Text(c.formato == null ? 'Formato desconocido' : formatosCodigo[c.formato] ?? c.formato!),
              onTap: () => Navigator.pop(hoja, c),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: _analizando
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Analizando la foto…'),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _leer(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Hacer foto'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _leer(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Elegir imagen'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Campo para escribir el código a mano o con un lector de pistola (que
/// funciona como un teclado: escribe el código y pulsa Intro).
class EntradaManual extends StatefulWidget {
  const EntradaManual({super.key, required this.alEnviar});

  final ValueChanged<String> alEnviar;

  @override
  State<EntradaManual> createState() => _EntradaManualState();
}

class _EntradaManualState extends State<EntradaManual> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _enviar() {
    final valor = _texto.text.trim();
    if (valor.isEmpty) return;
    _texto.clear();
    widget.alEnviar(valor);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _texto,
                decoration: const InputDecoration(
                  hintText: 'O escribe el código',
                  prefixIcon: Icon(Icons.keyboard_outlined),
                  isDense: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _enviar(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _enviar, child: const Text('Usar')),
          ],
        ),
      ),
    );
  }
}

class _ErrorCamara extends StatelessWidget {
  const _ErrorCamara(this.error);

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final texto = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'No hay permiso para usar la cámara.\nActívalo en los ajustes del navegador '
            '(icono del candado junto a la dirección) y vuelve a abrir el escáner.',
      MobileScannerErrorCode.unsupported =>
        'Este dispositivo o navegador no permite usar la cámara.',
      _ => 'No se pudo abrir la cámara.',
    };
    final detalle = error.errorDetails?.message;
    return _MensajeCamara(
      icono: Icons.no_photography_outlined,
      texto: detalle == null ? texto : '$texto\n\nDetalle: $detalle',
    );
  }
}

class _MensajeCamara extends StatelessWidget {
  const _MensajeCamara({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    ),
  );
}
