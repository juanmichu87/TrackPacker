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

flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_KEY="$SUPABASE_KEY" \
  --dart-define=AUTH_DOMINIO="$AUTH_DOMINIO"
