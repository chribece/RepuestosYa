# RepuestosYa — Ambientes, builds y versionado

> Fecha: 2026-10-03 · App Flutter lista para producción.

## 1. Ambientes y comandos exactos

Las variables se inyectan con `--dart-define` en cada build. Nombres reales
del proyecto: **`API_BASE_URL`**, **`APP_ENV`** (dev | staging | prod),
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `APP_VERSION`.

| Ambiente | APP_ENV | API_BASE_URL | Comando |
|---|---|---|---|
| **Desarrollo** (backend local en la LAN) | `dev` | `http://192.168.100.2:3000/api` | `flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://192.168.100.2:3000/api` |
| **Producción por defecto** (sin flags) | `prod` | `https://repuestosya.onrender.com/api` | `flutter run` o `flutter build apk --release` (defaults de `lib/config/app_config.dart`) |
| **Build release (Play Store)** | `prod` | `https://repuestosya.onrender.com/api` | `flutter build apk --release` |
| **Staging** (verificación Semana 15, Sentry) | `staging` | API real o staging | `flutter build apk --release --dart-define=APP_ENV=staging --dart-define=SENTRY_DSN=<dsn> --dart-define=APP_VERSION=1.0.0+1` |

Reglas de ambiente:

- `APP_ENV=prod` o `staging` **exigen HTTPS** en `API_BASE_URL` al arrancar
  (`AppConfig.assertValidConfiguration()` → `StateError` claro si no).
- Con `APP_ENV=prod` + build **release**, `AppConfig.overrideBaseUrl` es
  **inerte** (kReleaseMode): la app siempre apunta a producción. El override
  solo lo usa el integration_test en debug.
- El botón **"Provocar fallo de prueba (Sentry)"** (Mi Perfil) solo aparece
  en debug o cuando `APP_ENV != prod`; nunca en el build release de
  producción (dead-code elimination).

### Staging sin tocar producción (verificación Semana 15)

- Compilar con `APP_ENV=staging` y `SENTRY_DSN` (p. ej. un proyecto/DNS de
  Sentry dedicado a staging): los eventos llegan con `environment=staging`
  y el botón de fallo de prueba queda visible.
- El backend/Supabase son los mismos de producción (BD única, decisión
  documentada en `docs/DESPLIEGUE.md` §6); `APP_ENV` no cambia contra qué
  API se habla — eso lo controla `API_BASE_URL`. Para staging usar la API de
  producción (`https://repuestosya.onrender.com/api`) o un backend staging si
  existiera.

## 2. Versionado

- `pubspec.yaml`: `version: <semver>+<build>` (ej. `1.0.0+1`).
  - Android: `versionName` = semver, `versionCode` = build.
  - iOS: `CFBundleShortVersionString` = semver, `CFBundleVersion` = build.
- **Regla obligatoria: el número de build (+N) aumenta en CADA distribución**
  (Play Store/TestFlight). El semver solo cambia con cambios visibles para el
  usuario (feature/fix/breaking).
- **`SentryConfig.release`** se sincroniza con `pubspec.yaml` (default
  `repuestosya@1.0.0+1`) y se puede inyectar con
  `--dart-define=APP_VERSION=<semver>+<build>` en CI. Actualizarlo SIEMPRE
  junto con `pubspec.yaml` para poder ubicar símbolos de ofuscación.

### Historial de versiones

| Versión+Build | Fecha | Canal | Notas |
|---|---|---|---|
| 1.0.0+1 | 2026-10-03 | Producción | Primer build lista para producción (defaults: Render + Supabase). |

## 3. Tráfico cifrado y permisos (Android/iOS)

- Android: el manifest **main** no declara `android:usesCleartextTraffic`
  (ni debug/profile): no hay tráfico cleartext permitido en ningún build.
  El HTTP local de desarrollo funciona porque `dart:io` no consulta la
  política de cleartext de Android; el tráfico real es HTTPS.
- iOS: `Info.plist` no tiene `NSAppTransportSecurity` →
  `NSAllowsArbitraryLoads` ausente (ATS bloquea HTTP).
- Permisos declarados (manifest main): `INTERNET`, `POST_NOTIFICATIONS`,
  `VIBRATE`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `CAMERA`
  (feature `android.hardware.camera` opcional). Sin permisos sobrantes.

## 4. Nivel de API objetivo (Google Play)

Estado del proyecto (`android/app/build.gradle.kts`):

| Parámetro | Valor |
|---|---|
| `minSdk` | 24 (Android 7.0) — default de Flutter 3.44.1 |
| `targetSdk` | 37 |
| `compileSdk` | 37 |

Requisito oficial de Google Play consultado el **2026-10-03** en
https://developer.android.com/google/play/requirements/target-sdk:
**desde el 31 de agosto de 2026, las apps nuevas y las actualizaciones deben
apuntar a Android 16 (API level 36) o superior** (Wear OS/Automotive: API 35;
TV/XR: API 34).

→ `targetSdk 37 ≥ 36`: **CUMPLE** el requisito vigente (2026-10-03).

## 5. Verificaciones de release

```bash
dart format --set-exit-if-changed .
flutter analyze          # 0 issues
flutter test             # todo en verde
flutter build apk --release

# Manifest fusionado de release (sin cleartext):
#   build/app/intermediates/merged_manifests/release/AndroidManifest.xml
#   (grep usesCleartextTraffic → vacío)
# Permisos del APK (aapt):
#   <sdk>/build-tools/<v>/aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
# Paquete definitivo:
#   <sdk>/build-tools/<v>/aapt dump badging build/app/outputs/flutter-apk/app-release.apk
#   → package: name='com.repuestosya.app' ...
```

**Identificador único (definitivo):** `com.repuestosya.app`

- Android: `applicationId` y `namespace` en `android/app/build.gradle.kts`;
  `MainActivity.kt` en `android/app/src/main/kotlin/com/repuestosya/app/`.
- iOS: `PRODUCT_BUNDLE_IDENTIFIER = com.repuestosya.app` (Runner) y
  `com.repuestosya.app.RunnerTests` (tests) en `ios/Runner.xcodeproj/project.pbxproj`.
- macOS/Linux/Windows: `PRODUCT_BUNDLE_IDENTIFIER`/`APPLICATION_ID` iguales
  (`com.repuestosya.app`); CompanyName/Copyright → "RepuestosYa".
- OSM (flutter_map): `userAgentPackageName: 'com.repuestosya.app'`.

El keystore de firma de release es un TODO pendiente: actualmente se firma
con `signingConfigs.getByName("debug")` (ver `build.gradle.kts`), apto solo
para pruebas internas, NO para Play Store.
