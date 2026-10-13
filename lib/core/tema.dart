import 'package:flutter/material.dart';

/// Paleta de TrackPack: fondo blanco, rojo vivo para botones y bordes activos
/// y texto negro. Siempre en modo claro: se usa de día y a pleno sol, donde el
/// texto negro sobre blanco es lo que mejor se lee.
abstract final class Paleta {
  static const rojo = Color(0xFFE10600);
  static const rojoOscuro = Color(0xFFA30400);
  static const rojoSuave = Color(0xFFFDE8E7);
  static const fondo = Color(0xFFF6F6F7);
  static const blanco = Color(0xFFFFFFFF);
  static const texto = Color(0xFF111111);
  static const textoSecundario = Color(0xFF4A4A4A);
  static const borde = Color(0xFFE0E0E0);

  /// Degradado suave de blancos para pantallas de entrada (login).
  static const degradado = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F1F3)],
  );
}

/// Colores de estado con contraste suficiente sobre blanco (≥ 4,5:1).
abstract final class ColoresEstado {
  static const correcto = Color(0xFF1B7F3B);
  static const informacion = Color(0xFF1F5FBF);
  static const aviso = Color(0xFFB45309);
  static const peligro = Color(0xFFB91C1C);
  static const neutro = Color(0xFF616161);
}

ThemeData temaTrackPack() {
  const esquema = ColorScheme(
    brightness: Brightness.light,
    primary: Paleta.rojo,
    onPrimary: Paleta.blanco,
    primaryContainer: Paleta.rojoSuave,
    onPrimaryContainer: Paleta.rojoOscuro,
    secondary: Paleta.rojoOscuro,
    onSecondary: Paleta.blanco,
    secondaryContainer: Paleta.rojoSuave,
    onSecondaryContainer: Paleta.rojoOscuro,
    tertiary: Paleta.texto,
    onTertiary: Paleta.blanco,
    error: ColoresEstado.peligro,
    onError: Paleta.blanco,
    errorContainer: Color(0xFFFDECEC),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Paleta.blanco,
    onSurface: Paleta.texto,
    onSurfaceVariant: Paleta.textoSecundario,
    surfaceContainerLowest: Paleta.blanco,
    surfaceContainerLow: Paleta.blanco,
    surfaceContainer: Paleta.blanco,
    surfaceContainerHigh: Color(0xFFF4F4F5),
    surfaceContainerHighest: Color(0xFFEDEDEF),
    outline: Color(0xFFBDBDBD),
    outlineVariant: Paleta.borde,
    shadow: Color(0x1F000000),
    inverseSurface: Paleta.texto,
    onInverseSurface: Paleta.blanco,
    inversePrimary: Color(0xFFFF8A80),
  );

  final base = ThemeData(colorScheme: esquema, useMaterial3: true);
  const bordeRedondeado = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  return base.copyWith(
    scaffoldBackgroundColor: Paleta.fondo,
    textTheme: base.textTheme.apply(bodyColor: Paleta.texto, displayColor: Paleta.texto),
    appBarTheme: const AppBarTheme(
      backgroundColor: Paleta.blanco,
      foregroundColor: Paleta.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: Paleta.rojo, width: 2)),
      titleTextStyle: TextStyle(color: Paleta.texto, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    cardTheme: const CardThemeData(
      color: Paleta.blanco,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Paleta.borde),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Paleta.rojo,
        foregroundColor: Paleta.blanco,
        shape: bordeRedondeado,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Paleta.rojo,
        side: const BorderSide(color: Paleta.rojo, width: 1.5),
        shape: bordeRedondeado,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Paleta.rojoOscuro),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Paleta.blanco,
      border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFBDBDBD))),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFBDBDBD))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Paleta.rojo, width: 2)),
      // Etiqueta en rojo solo en el campo activo (o con error); si no, gris
      // oscuro, para que un campo relleno no parezca un error.
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (estados) => TextStyle(
          color: estados.contains(WidgetState.error)
              ? ColoresEstado.peligro
              : estados.contains(WidgetState.focused)
              ? Paleta.rojo
              : Paleta.textoSecundario,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Paleta.blanco,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Paleta.rojo,
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected) ? Paleta.blanco : Paleta.texto,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => TextStyle(
          color: Paleta.texto,
          fontSize: 12,
          fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Paleta.blanco,
      indicatorColor: Paleta.rojo,
      selectedIconTheme: IconThemeData(color: Paleta.blanco),
      unselectedIconTheme: IconThemeData(color: Paleta.texto),
      selectedLabelTextStyle: TextStyle(color: Paleta.texto, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: TextStyle(color: Paleta.texto),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Paleta.rojo,
      unselectedLabelColor: Paleta.textoSecundario,
      indicatorColor: Paleta.rojo,
    ),
    listTileTheme: const ListTileThemeData(iconColor: Paleta.texto),
    dividerTheme: const DividerThemeData(color: Paleta.borde),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Paleta.texto,
      contentTextStyle: TextStyle(color: Paleta.blanco),
      actionTextColor: Color(0xFFFF8A80),
    ),
  );
}
