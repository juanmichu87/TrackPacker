import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // URLs limpias en la web: /login en vez de /#/login
  usePathUrlStrategy();

  if (!Config.completa) {
    runApp(const ConfigFaltanteApp());
    return;
  }

  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  runApp(
    ProviderScope(
      // Sin reintentos automáticos: si algo falla se muestra el error una vez
      // con el botón «Reintentar», en vez de quedarse consultando sin parar.
      retry: (_, _) => null,
      child: const TrackPackApp(),
    ),
  );
}
