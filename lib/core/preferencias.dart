import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacén local del dispositivo (localStorage en la web). Se abre en `main`
/// antes de arrancar la app; null en las pruebas o si no está disponible.
final preferenciasProvider = Provider<SharedPreferences?>((ref) => null);
