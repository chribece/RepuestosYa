# RepuestosYa — Firma y compilación de publicación

> Fecha: 2026-10-03 · Aplica a `com.repuestosya.app` (identificador definitivo).
> Regla de oro: **la clave de firma NUNCA se versiona ni se envía por chat/correo**.

---

## 1. Modelo de dos claves de Google Play (Play App Signing)

Google Play usa **dos claves** distintas:

| Clave | Quién la tiene | Para qué sirve | Si se pierde… |
|---|---|---|---|
| **Clave de subida (upload key)** | Tú (la creas con `keytool`) | Firma el APK/AAB que **subes** a Play Console. Es la que configura `android/key.properties`. | **Recuperable**: Play Console permite restablecerla (opción *Upload key reset*) verificando la identidad de la cuenta de desarrollador. La app y sus usuarios NO se pierden; solo cambia la clave que usas para subir. |
| **Clave de firma de la app (app signing key)** | **Google** (Play App Signing) | Google firma con ella lo que se distribuye a los dispositivos. Se genera automáticamente al activar App Signing (o se importa la que ya usabas). | **Prácticamente irrecuperable**: sin ella no se puede actualizar la app con la misma identidad. Google conserva una **copia de seguridad cifrada** que puedes solicitar con el proceso oficial; si no se recupera, la única salida es publicar una app NUEVA con otro `applicationId` (perderías instalaciones/valoraciones). |

Consecuencias prácticas:
- Puedes **respaldar y mantener segura solo la clave de subida**; la de firma la custodia Google.
- Activa **Play App Signing** desde el primer AAB que subas (si subes APK firmado con tu clave sin App Signing, la app queda "heredada" y la clave de firma la gestionas tú para siempre — evítalo si empiezas ahora).
- **NUNCA** compartas la clave de subida con nadie que no sea propietario de la cuenta.

---

## 2. Generar la clave de subida (upload key)

> **No se genera automáticamente**: la crea el dueño del proyecto, **fuera del repo**.
> RSA 2048 bits (o más), validez 10 000 días, alias `upload`.

**Bash (Linux/macOS/WSL):**
```bash
mkdir -p ~/keystores
keytool -genkeypair -v \
  -keystore ~/keystores/repuestosya-upload.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=RepuestosYa, OU=Mobile, O=RepuestosYa, L=Quito, S=Pichincha, C=EC"
```
Te pedirá dos contraseñas: la del almacén (keystore) y la de la clave (puedes pulsar Enter para que sea igual a la del almacén). **Anótalas en el gestor de contraseñas.**

**PowerShell (Windows):**
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\keystores" | Out-Null
keytool -genkeypair -v `
  -keystore "$env:USERPROFILE\keystores\repuestosya-upload.jks" `
  -alias upload `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -dname "CN=RepuestosYa, OU=Mobile, O=RepuestosYa, L=Quito, S=Pichincha, C=EC"
```

> Nota: con JDK 17+ el formato por defecto es PKCS12 aunque el archivo se llame `.jks`; Android lo acepta sin problema.

**Verificar que quedó bien:**
```bash
keytool -list -v -keystore ~/keystores/repuestosya-upload.jks -alias upload
```

---

## 3. Configurar el build (`android/key.properties`)

1. Copiar la plantilla (sin valores): `android/key.properties.example` → `android/key.properties`.
2. Completar con los datos de la clave de subida:

```properties
storePassword=<contraseña del almacén>
keyPassword=<contraseña de la clave (o la misma)>
keyAlias=upload
storeFile=C:/Users/<tu-usuario>/keystores/repuestosya-upload.jks
```

3. **Comportamiento del build** (`android/app/build.gradle.kts`):
   - `flutter build apk --release` / `appbundle` **FALLAN con mensaje claro** si falta `android/key.properties` — nunca se firma con la clave debug.
   - `release` tiene **`minifyEnabled` + `shrinkResources` (R8)** y `proguard-rules.pro` con las reglas defensivas de los plugins (Sentry, flutter_local_notifications, flutter_secure_storage, geolocator, image_picker, drift/sqlite3). El código Dart se ofusca aparte con `--obfuscate`.
   - `applicationId`, `versionCode` y `versionName` NO se tocan: vienen de `pubspec.yaml`.

---

## 4. Compilar y verificar (scripts de release)

```bash
# Desde la raíz del repo:
bash scripts/build_release.sh
# o en Windows:
powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
```

El script:
1. Lee la versión de `pubspec.yaml` (semver+build, ej. `1.0.0+1`).
2. Ejecuta:
   - `flutter build apk --release --obfuscate --split-debug-info=build/simbolos/<version+build> --dart-define=APP_VERSION=<version+build>`
   - `flutter build appbundle --release --obfuscate --split-debug-info=build/simbolos/<version+build> --dart-define=APP_VERSION=<version+build>`
3. Guarda los **símbolos de ofuscación** en `build/simbolos/<version+build>/` (carpeta identificada por versión).
4. Muestra los tamaños del APK y del AAB.

> Usa los defaults de producción de `app_config.dart` (`API_BASE_URL=https://repuestosya.onrender.com/api`, `APP_ENV=prod`); solo inyecta `APP_VERSION`.

**Verificar la firma (clave de SUBIDA, nunca debug):**
```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# El certificado debe mostrar tu DN (p. ej. CN=RepuestosYa) y un SHA-256 que
# coincida con:
keytool -list -v -keystore ~/keystores/repuestosya-upload.jks -alias upload
# (el SHA-256 de la clave debug de Android es conocido y NO debe aparecer)
```
El APK debug firmado con la clave genérica de Android se identifica por su
certificado `CN=Android Debug` (y el SHA-256 `61:ED:37:7E:85:D3:86:A8:DF:EE:6B:86:4B:D8:5B:0B:FA:A5:AF:81:82:65:17:87:00:7B:63:15:51:D9:3C:22`).

---

## 5. APK vs AAB — ¿cuál para qué?

| Formato | Canal | Uso |
|---|---|---|
| **AAB** (`app-release.aab`) | **Google Play** | Formato obligatorio para Play (Play App Signing aplica la firma de Google). Único que permite **App Bundle** (entrega dinámica por dispositivo). |
| **APK** (`app-release.apk`) | Sideload / pruebas / otras tiendas | Instalación directa en dispositivos, testing manual, Amazon Appstore u otras tiendas que exigen APK. Firmado con la **clave de subida**. |

Regla: a Play se sube el **AAB**; el APK es para pruebas y distribución fuera de Play.

---

## 6. Símbolos de ofuscación y Sentry

El build con `--obfuscate` hace **ilegibles las trazas de Dart** (nombres como
`a.b.c`) salvo que subas los símbolos de ESA versión a Sentry. **Sin los
símbolos de una versión, sus errores no se pueden leer**: hay que conservar
uno por cada versión distribuida (la carpeta `build/simbolos/<version+build>/`
es ese respaldo local).

**Subida con `sentry-cli`** (token en variable de ambiente, **nunca en el repo**):
```bash
# 1) Token: Settings -> Auth Tokens (scope: project:releases, project:write)
export SENTRY_AUTH_TOKEN=<token>   # variable de ambiente o CI secret

# 2) Símbolos Dart de la versión (release EXACTA repuestosya@<version+build>):
sentry-cli debug-files upload -o <org> -p <proyecto> --include-sources \
  build/simbolos/1.0.0+1

# 3) Mapping de R8 (bytecode nativo), opcional pero recomendado:
sentry-cli debug-files upload -o <org> -p <proyecto> \
  build/app/outputs/mapping/release/mapping.txt

# 4) Asociar la release (para agrupar eventos):
sentry-cli releases new -p <proyecto> repuestosya@1.0.0+1
sentry-cli releases set-commits --ignore-missing repuestosya@1.0.0+1 --auto
sentry-cli releases finalize repuestosya@1.0.0+1
```

> La app ya reporta `release = repuestosya@<version+build>` en cada evento
> (`APP_VERSION` se inyecta en el build; default en `SentryConfig.release`).
> Alternativa al CLI: `sentry_dart_plugin` configurado en `pubspec.yaml`
> (`upload_debug_symbols: true`, `split_debug_info`), que automatiza el paso 2
> en cada build — requiere token igualmente en el entorno.

---

## 7. Respaldos (checklist obligatorio)

- [ ] Copia del `.jks` en **al menos 2 lugares fuera del equipo**: gestor de contraseñas con adjuntos (1Password/Bitwarden) **y** almacenamiento cifrado separado (USB en caja fuerte / carpeta cifrada).
- [ ] Contraseñas (`storePassword` y `keyPassword`) en el gestor; si son iguales, registrar ambas como entradas independientes.
- [ ] Prueba de restauración del respaldo: `keytool -list -v -keystore <copia>` debe listar el alias `upload`.
- [ ] `android/key.properties` **no** se versiona (`.gitignore`); `key.properties.example` es la plantilla vacía.
- [ ] NUNCA enviar el `.jks` ni las contraseñas por chat/correo no cifrado.

---

## 8. Flujo de publicación (resumen)

1. `bash scripts/build_release.sh` (o `.ps1`) → APK + AAB + `build/simbolos/<v+b>/`.
2. `apksigner verify --print-certs <apk>` → confirmar clave de SUBIDA (no debug).
3. Play Console → App Signing (activar) → subir el **AAB** → release (canal interno/producción).
4. Subir símbolos a Sentry con la release `repuestosya@<version+build>` (§6).
5. Registrar la versión en la tabla de historial (§9).

---

## 9. Historial de versiones

| Versión+build | Fecha | Canal | Símbolos (build/simbolos/) | Release Sentry |
|---|---|---|---|---|
| 1.0.0+1 | (pendiente de firma) | Producción (Play) | `1.0.0+1/` | `repuestosya@1.0.0+1` |
