#!/usr/bin/env sh
# Ejecuta la app. Por defecto en Chrome (no hay carpeta linux/ en el
# proyecto); pasa otro dispositivo como argumento: ./tool/run.sh <device-id>
# (ver `flutter devices`; para el móvil Android usa mejor ./tool/movil.sh).
set -e
cd "$(dirname "$0")/.."

# Flutter busca "google-chrome"; en esta máquina el binario es otro.
if [ -z "$CHROME_EXECUTABLE" ]; then
  for c in google-chrome-stable google-chrome chromium; do
    if command -v "$c" >/dev/null 2>&1; then
      CHROME_EXECUTABLE="$(command -v "$c")"
      export CHROME_EXECUTABLE
      break
    fi
  done
fi

exec flutter run -d "${1:-chrome}"
