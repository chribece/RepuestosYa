# ── RepuestosYa — Reglas ProGuard/R8 (release con minifyEnabled) ────────────
#
# El código DART no pasa por R8: se compila AOT a libapp.so y se ofusca con
# `flutter build --obfuscate` (los símbolos van a build/simbolos/ y se suben a
# Sentry). R8 solo procesa el bytecode Java/Kotlin (embedder + plugins).
#
# La mayoría de los plugins distribuyen sus propias consumer-rules (se aplican
# automáticamente desde sus AAR). Estas reglas son la red de seguridad para
# los que usan reflexión o nombres de paquete internos.

# Sentry Android SDK (reflexión/parsing de eventos; si cambia sus reglas, esta
# es una red de seguridad).
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# flutter_local_notifications (alarm manager / receivers por reflexión).
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# flutter_secure_storage (Keystore de Android / cifrado).
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# geolocator (métodos de ubicación vía method channel).
-keep class com.baseflow.geolocator.** { *; }

# image_picker.
-keep class io.flutter.plugins.imagepicker.** { *; }

# drift / sqlite3_flutter_libs (driver nativo; defensivo).
-keep class nl.xxlllq2.** { *; }
-dontwarn nl.xxlllq2.**

# mantenimiento general: no eliminar clases referenciadas por el registrador
# de plugins de Flutter (io.flutter.plugins.GeneratedPluginRegistrant ya se
# conserva por el propio template; regla defensiva).
-keep class io.flutter.plugins.** { *; }
