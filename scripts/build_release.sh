#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# RepuestosYa — Build de release (APK + AAB) con ofuscación Dart y símbolos.
#
# Requisitos:
#   - android/key.properties con la clave de SUBIDA (ver docs/FIRMA_Y_RELEASE.md).
#     El build FALLA si no existe (nunca se firma con la clave debug).
#   - `flutter` en el PATH (en este repo: cmd.exe /c "cd /d C:\RepuestosYa && ...")
#
# Genera:
#   - build/app/outputs/flutter-apk/app-release.apk
#   - build/app/outputs/bundle/release/app-release.aab
#   - build/simbolos/<version+build>/   (símbolos Dart, se suben a Sentry)
#
# Usa los DEFAULTS de producción de lib/config/app_config.dart
# (API_BASE_URL=https://repuestosya.onrender.com/api, APP_ENV=prod); solo se
# inyecta APP_VERSION para alinear la release de Sentry con pubspec.yaml.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "$0")/.."

# 1) Leer versión de pubspec.yaml (semver+build, ej. 1.0.0+1)
VERSION=$(grep -E '^version:' pubspec.yaml | head -n1 | awk '{print $2}')
if [[ -z "$VERSION" ]]; then
  echo "ERROR: no se pudo leer 'version:' de pubspec.yaml" >&2
  exit 1
fi
echo "==> Versión: $VERSION"

SYMBOLS_DIR="build/simbolos/$VERSION"
RELEASE="repuestosya@$VERSION"
echo "==> Release de Sentry: $RELEASE"
echo "==> Símbolos: $SYMBOLS_DIR"

# 2) Builds de release (ofuscación Dart + símbolos)
echo "==> flutter build apk --release ..."
flutter build apk --release \
  --obfuscate --split-debug-info="$SYMBOLS_DIR" \
  --dart-define=APP_VERSION="$VERSION"

echo "==> flutter build appbundle --release ..."
flutter build appbundle --release \
  --obfuscate --split-debug-info="$SYMBOLS_DIR" \
  --dart-define=APP_VERSION="$VERSION"

# 3) Símbolos y tamaños
echo
echo "==> Símbolos de ofuscación: $SYMBOLS_DIR"
echo "    Subirlos a Sentry con la release '$RELEASE' (ver docs/FIRMA_Y_RELEASE.md)."
echo
echo "==> Tamaños de artefactos:"
APK="build/app/outputs/flutter-apk/app-release.apk"
AAB="build/app/outputs/bundle/release/app-release.aab"
ls -lh "$APK" "$AAB"
echo
echo "==> Verificación de firma (debe mostrar la clave de SUBIDA, nunca debug):"
apksigner verify --print-certs "$APK" 2>/dev/null || \
  echo "apksigner no está en PATH; verificar con: apksigner verify --print-certs \"$APK\""
