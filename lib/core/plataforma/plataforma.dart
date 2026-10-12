// Funciones que dependen de la plataforma: en web usan el navegador y en
// Android/iOS las APIs nativas de Flutter.
export 'plataforma_nativa.dart' if (dart.library.js_interop) 'plataforma_web.dart';
