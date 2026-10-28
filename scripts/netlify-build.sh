#!/usr/bin/env bash
# Compila la web en Netlify (se ejecuta en cada push a main).
# Las claves no están en el repositorio: se configuran en Netlify →
# Site configuration → Environment variables.
set -euo pipefail

# Misma versión de Flutter que en desarrollo
FLUTTER_VERSION="3.47.5"

for variable in SUPABASE_URL SUPABASE_KEY AUTH_DOMINIO; do
  if [ -z "${!variable:-}" ]; then
    echo "ERROR: falta la variable de entorno $variable en Netlify" \
         "(Site configuration → Environment variables)." >&2
    exit 1
  fi
done

if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"

flutter config --no-analytics > /dev/null
flutter --version

# --wasm: Chrome y Edge (Android y PC) usan WebAssembly, que arranca unas 3
# veces más rápido; Safari y Firefox siguen con JavaScript (se elige solo).
flutter build web --release --wasm \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_KEY="$SUPABASE_KEY" \
  --dart-define=AUTH_DOMINIO="$AUTH_DOMINIO"

# Prepara la conexión con Supabase mientras se descarga la app (ahorra el
# tiempo de abrir la conexión segura en la primera consulta).
sed -i "s#</head>#<link rel=\"preconnect\" href=\"$SUPABASE_URL\" crossorigin></head>#" build/web/index.html
if ! grep -q 'rel="preconnect"' build/web/index.html; then
  echo "ERROR: no se pudo añadir el preconnect a index.html" >&2
  exit 1
fi
echo "preconnect añadido a index.html"
