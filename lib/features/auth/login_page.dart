import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sesion.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  bool _ocultarContrasena = true;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .iniciarSesion(usuario: _usuario.text, contrasena: _contrasena.text);
      // El router redirige solo cuando se carga el perfil
    } on AuthException catch (e) {
      _mostrarError(
        e.code == 'invalid_credentials' || e.statusCode == '400'
            ? 'Usuario o contraseña incorrectos.'
            : 'No se pudo iniciar sesión (${e.message}).',
      );
    } catch (_) {
      _mostrarError('No se pudo conectar. Revisa la conexión e inténtalo de nuevo.');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Si tras entrar se rechaza el acceso, se vuelve aquí con un aviso
    ref.listen(sesionProvider, (_, nuevo) {
      if (nuevo is SinSesion && _enviando) setState(() => _enviando = false);
    });
    final sesion = ref.watch(sesionProvider);
    final aviso = _error ?? (sesion is SinSesion ? sesion.aviso : null);
    final tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formulario,
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: tema.colorScheme.primary),
                        const SizedBox(height: 8),
                        Text('TrackPack', textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usuario,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Introduce tu usuario' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contrasena,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _ocultarContrasena ? 'Mostrar contraseña' : 'Ocultar contraseña',
                              icon: Icon(_ocultarContrasena ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _ocultarContrasena = !_ocultarContrasena),
                            ),
                          ),
                          obscureText: _ocultarContrasena,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _entrar(),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Introduce tu contraseña' : null,
                        ),
                        if (aviso != null) ...[
                          const SizedBox(height: 16),
                          Text(aviso, style: TextStyle(color: tema.colorScheme.error)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _enviando ? null : _entrar,
                          child: _enviando
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Entrar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
