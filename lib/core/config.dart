/// Configuración que se inyecta al compilar:
///   flutter run --dart-define-from-file=.env
/// Ver .env.example. Las claves nunca se escriben en el código.
abstract final class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Clave pública del proyecto (publishable `sb_publishable_…` o la anon key
  /// antigua). Nunca la service_role.
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  /// Dominio del email interno de Supabase Auth: el usuario `repartidor1` inicia
  /// sesión como `repartidor1@<AUTH_DOMINIO>`. Debe coincidir con el usado al
  /// crear los usuarios en la base de datos.
  static const dominioUsuarios = String.fromEnvironment('AUTH_DOMINIO');

  /// Versión de la base de datos que necesita esta versión de la app (la
  /// última migración de supabase/migrations). Súbela con cada migración.
  static const versionEsquema = 10;

  static bool get completa =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty && dominioUsuarios.isNotEmpty;
}
