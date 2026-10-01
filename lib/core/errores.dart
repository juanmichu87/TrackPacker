import 'package:supabase_flutter/supabase_flutter.dart';

/// Mensajes de las restricciones de la base de datos (nombre de la constraint).
const _restricciones = {
  'cliente_requerido': 'Los usuarios con rol cliente necesitan una empresa asignada.',
  'longitudes_coherentes': 'La longitud mínima no puede ser mayor que la máxima.',
  'fotos_antes_que_bultos': 'Las fotos no pueden guardarse más días que los bultos.',
  'tienda_unica_por_cliente': 'Ese cliente ya tiene una tienda con ese nombre.',
};

/// Error de validación con un mensaje ya preparado para el usuario.
class ErrorValidacion implements Exception {
  const ErrorValidacion(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Traduce cualquier error a un mensaje para el usuario.
String mensajeError(Object error) {
  if (error is ErrorValidacion) return error.mensaje;
  if (error is PostgrestException) {
    for (final MapEntry(:key, :value) in _restricciones.entries) {
      if (error.message.contains(key) || (error.details?.toString().contains(key) ?? false)) {
        return value;
      }
    }
    switch (error.code) {
      // Tabla, vista o función que no existe: falta aplicar una migración
      case 'PGRST202' || 'PGRST205' || '42P01' || '42883':
        return 'La base de datos no está actualizada: falta ejecutar la última migración '
            'de supabase/migrations en el SQL Editor de Supabase.';
      // Errores lanzados por nuestras funciones: el mensaje ya está en español
      case 'P0001' || 'P0002':
        return error.message;
      case '23505':
        return error.message.startsWith('El usuario')
            ? error.message
            : 'Ya existe un registro con ese nombre.';
      case '23503':
        return 'No se puede completar: está relacionado con otros datos. '
            'Si quieres retirarlo, desactívalo en su lugar.';
      case '23514' || '22P02':
        return 'Algún dato no tiene el formato correcto.';
      case '42501':
        return 'No tienes permiso para esta operación.';
    }
    return 'Error de la base de datos: ${error.message}';
  }
  if (error is AuthException) return 'Error de sesión: ${error.message}';
  return 'No se pudo conectar. Revisa la conexión e inténtalo de nuevo.';
}
