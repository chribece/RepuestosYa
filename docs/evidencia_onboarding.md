# Evidencia funcional del onboarding

## Alcance

El onboarding guía al cliente nuevo por el registro de un vehículo y la creación
de su primera solicitud. El redirect global consulta `OnboardingProvider` cuando
termina la carga y evita redirecciones mientras `isLoadingVehicle` o
`isLoadingRequest` están activos.

## Casos de recorrido

| Caso | Resultado esperado | Evidencia / estado |
|---|---|---|
| Cliente nuevo sin vehículo ni solicitud | Al terminar la carga, entra a `/onboarding` en lugar de `/home`. | Validado por la lógica de `AppRouter` y `OnboardingProvider`. No se ejecutó login real contra backend en esta sesión. |
| `/onboarding` → `/profile/vehicles` | La pantalla de vehículos se abre sin volver a `/onboarding` en bucle. | Validado por la exclusión de `/profile/vehicles` en el redirect. No se ejecutó navegación manual en dispositivo en esta sesión. |
| `/onboarding` → `/request/create` | El formulario de solicitud se abre sin volver a `/onboarding` en bucle. | Validado por la exclusión de `/request/create` en el redirect. No se ejecutó navegación manual en dispositivo en esta sesión. |
| Botón «Omitir» | Ejecuta `skip()`, navega a `/home` y `onboarding_skipped` conserva la decisión después de volver a iniciar sesión. | Validado por `OnboardingProvider.skip()`, `SharedPreferences` y la condición `isSkipped`. No se ejecutó re-login real en esta sesión. |
| Cliente con vehículo y solicitud | `isComplete` es verdadero y entra directamente a `/home`. | Validado por la condición `isComplete` del redirect. No se ejecutó login real contra backend en esta sesión. |
| Usuario almacén | Entra a `/dashboard`; si intenta `/onboarding`, la protección por rol lo devuelve a `/dashboard`. | Validado por la protección de rol de `AppRouter`. No se ejecutó login real de almacén en esta sesión. |

## Verificación estática

- `dart format lib/`: correcto.
- `dart format --output=none --set-exit-if-changed lib/`: correcto, sin archivos sin formatear.
- `flutter analyze`: `No issues found!`.

La validación funcional con credenciales reales queda pendiente de ejecutarse en
un entorno con backend disponible y usuarios de prueba de ambos roles.
