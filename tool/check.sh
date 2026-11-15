#!/usr/bin/env sh
# Verificación completa: análisis estático + toda la suite de tests.
# Uso: ./tool/check.sh
set -e
cd "$(dirname "$0")/.."
flutter analyze
flutter test
