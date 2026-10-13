import 'package:flutter/widgets.dart';

/// Tamaños de pantalla de la app. Es la ÚNICA fuente de puntos de corte: todas
/// las pantallas deciden su diseño con esto, para que se comporten igual y
/// las nuevas lo hereden sin repetir números.
enum TamanoPantalla {
  /// Móvil en vertical (< 600 px).
  movil,

  /// Tablet o móvil en horizontal (600–999 px).
  tablet,

  /// Ordenador (≥ 1000 px).
  escritorio;

  static const corteTablet = 600.0;
  static const corteEscritorio = 1000.0;

  static TamanoPantalla para(double ancho) => ancho >= corteEscritorio
      ? escritorio
      : ancho >= corteTablet
      ? tablet
      : movil;
}

extension PantallaContexto on BuildContext {
  TamanoPantalla get tamano => TamanoPantalla.para(MediaQuery.sizeOf(this).width);
  bool get esPantallaMovil => tamano == TamanoPantalla.movil;
  bool get esPantallaEscritorio => tamano == TamanoPantalla.escritorio;
}

/// Elige un valor según el tamaño. Si no se da el de tablet se usa el de
/// móvil, y si no se da el de escritorio, el de tablet.
T segunTamano<T>(BuildContext context, {required T movil, T? tablet, T? escritorio}) =>
    switch (context.tamano) {
      TamanoPantalla.movil => movil,
      TamanoPantalla.tablet => tablet ?? movil,
      TamanoPantalla.escritorio => escritorio ?? tablet ?? movil,
    };

/// Construye un diseño distinto según el tamaño de pantalla (mismas reglas de
/// respaldo que [segunTamano]).
class Responsivo extends StatelessWidget {
  const Responsivo({super.key, required this.movil, this.tablet, this.escritorio});

  final WidgetBuilder movil;
  final WidgetBuilder? tablet;
  final WidgetBuilder? escritorio;

  @override
  Widget build(BuildContext context) =>
      segunTamano(context, movil: movil, tablet: tablet, escritorio: escritorio)(context);
}

/// Limita el ancho del contenido y lo centra, para que en pantallas grandes
/// las líneas no se estiren de lado a lado.
class ContenidoCentrado extends StatelessWidget {
  const ContenidoCentrado({super.key, required this.child, this.anchoMaximo = 1280});

  final Widget child;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: anchoMaximo),
      child: child,
    ),
  );
}

/// Rejilla que reparte los elementos en tantas columnas como quepan con un
/// ancho mínimo por elemento (en el móvil, normalmente 1 o 2).
class RejillaAdaptable extends StatelessWidget {
  const RejillaAdaptable({
    super.key,
    required this.children,
    this.anchoMinimo = 260,
    this.maxColumnas = 6,
    this.separacion = 12,
  });

  final List<Widget> children;
  final double anchoMinimo;
  final int maxColumnas;
  final double separacion;

  /// Columnas que caben en un ancho dado (al menos 1).
  static int columnasPara(double ancho, double anchoMinimo, int maxColumnas, double separacion) =>
      ((ancho + separacion) / (anchoMinimo + separacion)).floor().clamp(1, maxColumnas);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final columnas = columnasPara(restricciones.maxWidth, anchoMinimo, maxColumnas, separacion);
        final anchoElemento = (restricciones.maxWidth - separacion * (columnas - 1)) / columnas;
        return Wrap(
          spacing: separacion,
          runSpacing: separacion,
          children: [for (final hijo in children) SizedBox(width: anchoElemento, child: hijo)],
        );
      },
    );
  }
}
