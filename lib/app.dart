import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/tema.dart';

class TrackPackApp extends ConsumerWidget {
  const TrackPackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TrackPack',
      debugShowCheckedModeBanner: false,
      // Siempre en claro: es lo que mejor se lee a pleno sol
      theme: temaTrackPack(),
      themeMode: ThemeMode.light,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Se muestra si se arranca sin --dart-define-from-file=.env.
class ConfigFaltanteApp extends StatelessWidget {
  const ConfigFaltanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaTrackPack(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Falta la configuración de Supabase.\n\n'
              'Copia .env.example como .env, rellena sus valores '
              'y arranca con:\n'
              'flutter run --dart-define-from-file=.env',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
