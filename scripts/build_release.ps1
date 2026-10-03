# ─────────────────────────────────────────────────────────────────────────────
# RepuestosYa — Build de release (APK + AAB) con ofuscación Dart y símbolos.
#
# Requisitos:
#   - android/key.properties con la clave de SUBIDA (ver docs/FIRMA_Y_RELEASE.md).
#     El build FALLA si no existe (nunca se firma con la clave debug).
#   - `flutter` en el PATH.
#
# Genera:
#   - build/app/outputs/flutter-apk/app-release.apk
#   - build/app/outputs/bundle/release/app-release.aab
#   - build/simbolos/<version+build>/   (símbolos Dart, se suben a Sentry)
#
# Uso (desde la raíz del repo o cualquier directorio):
#   powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
#
# Usa los DEFAULTS de producción de lib/config/app_config.dart
# (API_BASE_URL=https://repuestosya.onrender.com/api, APP_ENV=prod); solo se
# inyecta APP_VERSION para alinear la release de Sentry con pubspec.yaml.
# ─────────────────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')

# 1) Leer versión de pubspec.yaml (semver+build, ej. 1.0.0+1)
$match = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $match) { throw "No se pudo leer 'version:' de pubspec.yaml" }
$version = $match.Matches[0].Groups[1].Value
Write-Host "==> Versión: $version"

$symbolsDir = "build/simbolos/$version"
$release = "repuestosya@$version"
Write-Host "==> Release de Sentry: $release"
Write-Host "==> Símbolos: $symbolsDir"

# 2) Builds de release (ofuscación Dart + símbolos)
Write-Host "==> flutter build apk --release ..."
flutter build apk --release --obfuscate --split-debug-info=$symbolsDir --dart-define=APP_VERSION=$version
if ($LASTEXITCODE -ne 0) { throw 'flutter build apk falló' }

Write-Host "==> flutter build appbundle --release ..."
flutter build appbundle --release --obfuscate --split-debug-info=$symbolsDir --dart-define=APP_VERSION=$version
if ($LASTEXITCODE -ne 0) { throw 'flutter build appbundle falló' }

# 3) Símbolos y tamaños
Write-Host ""
Write-Host "==> Símbolos de ofuscación: $symbolsDir"
Write-Host "    Subirlos a Sentry con la release '$release' (ver docs/FIRMA_Y_RELEASE.md)."
Write-Host ""
Write-Host "==> Tamaños de artefactos:"
$apk = 'build/app/outputs/flutter-apk/app-release.apk'
$aab = 'build/app/outputs/bundle/release/app-release.aab'
Get-Item $apk, $aab | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}, LastWriteTime | Format-Table

Write-Host "==> Verificación de firma (debe mostrar la clave de SUBIDA, nunca debug):"
try {
    apksigner verify --print-certs $apk
} catch {
    Write-Host 'apksigner no está en PATH; verificar con: apksigner verify --print-certs "<ruta-al-apk>"'
}
