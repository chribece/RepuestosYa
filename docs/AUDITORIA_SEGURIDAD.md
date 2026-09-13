# Auditoría de Red, Servicios Remotos, Persistencia y Seguridad — RepuestosYa

**Fecha de la auditoría:** 2026-09-13
**Última actualización:** 2026-09-13 (correcciones de UX/offline-first C1–C4)
**Alcance:** `lib/` (Flutter/Dart) · `backend/` (Node.js/Express) · contrato `API_DOCUMENTATION.md` · `docs/`
**Estado:** en curso — correcciones de severidad alta/media aplicadas (B1, B2, B3, B8); correcciones de UX/offline-first aplicadas (C1–C4); pendientes menores B4–B14.

---

## 1. Resumen Ejecutivo

El cliente móvil está sólido: capa de red centralizada (Singleton `ApiClient`), renovación de token
single-flight con anti-bucle, reintentos solo idempotentes (GET), patrón Outbox transaccional sobre
Drift (SQLite), offline-first, almacenamiento de tokens cifrado (`flutter_secure_storage`) y manejo
de errores traducido a dominio (`ApiException`) con cobertura de tests.

Las brechas que impedían el 100% eran de backend. **Se corrigieron**:

| ID | Brecha | Severidad | Estado |
|----|--------|-----------|--------|
| B1 | CORS con allowlist de desarrollo siempre activa (incluso en producción) | Alta | ✅ Corregido |
| B2 | Rate-limit único (100 req/15 min) mal dimensionado y sin límite específico para auth | Media | ✅ Corregido |
| B3 | Error handler podía filtrar `err.message` y stack en producción | Media | ✅ Corregido |
| B8 | `/auth/refresh` caía a la service-role key si faltaba la anon key (bypass de RLS) | Alta | ✅ Corregido |
| UX-1 | `CompleteProfilePage` (almacén) sin salida: botón atrás inerte (stack reemplazado) | UX | ✅ Corregido |
| C1 | Dashboard de almacén sin aviso ni recarga al recuperar la conexión | UX/Offline | ✅ Corregido |
| C2 | Aprobación de almacén desde el panel admin sin refresco automático en la app | UX/Offline | ✅ Corregido |
| C3 | Home del cliente sin aviso de reconexión y refresco frágil (carrera offline) | UX/Offline | ✅ Corregido |
| C4 | Solicitud offline desaparecía del Home; borrado remoto no se reflejaba en caché | UX/Offline | ✅ Corregido |

---

## 2. Metodología y Verificaciones Ejecutadas

| Verificación | Resultado |
|---|---|
| `flutter analyze` | ✅ No issues found (29.1 s) |
| `flutter test` | ✅ 9/9 passed |
| `node --check backend/server.js` | ✅ SYNTAX OK |
| `node --check backend/src/controllers/authController.js` | ✅ SYNTAX OK |
| Smoke test CORS (dev y prod, orígenes permitidos/bloqueados/sin origin) | ✅ 204/500 según allowlist |
| Smoke test rate-limit por capas (21× login + endpoints genéricos) | ✅ 429 solo en auth al superar tope |
| Smoke test error handler en prod (origin CORS no permitido) | ✅ `{"error":"Internal server error"}` sin stack |
| Smoke test `/auth/refresh` con y sin `SUPABASE_ANON_KEY` | ✅ 401 normal / 500 fail-closed |
| `git check-ignore backend/.env` + `git ls-files` | ✅ `.env` ignorado y no trackeado |
| Grep de secretos (`eyJ`, `sk-`, api keys) en `lib/` | ✅ Sin secretos reales (solo anon key pública de Supabase) |

---

## 3. Mapeo de API ↔ Modelos (contrato)

El cliente serializa manualmente (`fromJson`/`toJson`) con mapeo `snake_case → camelCase`
explícito y campos opcionales anulables (`?`). Tabla resumida:

| Modelo (`lib/models/`) | Campos servidor (`snake_case`) | Notas |
|---|---|---|
| `Almacen` | `id, nombre_comercial, direccion_texto, latitude, longitude, verification_status, rejection_reason, estado_abierto` | lat/long numéricos anulables; `estado_abierto` booleano |
| `Cotizacion` | `id, solicitud_id, almacen_id, precio_venta, condicion_repuesto, tiempo_entrega_estimado, notas_adicionales, foto_evidencia_url, estado, created_at, almacenes` | `almacenes` embebido → `Almacen?` |
| `OrdenCompra` | `id, cliente_id, almacen_id, solicitud_id, cotizacion_id, detalles (JSONB), estado, created_at, updated_at, almacenes` | getters sobre JSONB para campos de cotización |
| `PartCategory` / `CatalogPart` | `id, nombre, slug, descripcion, activo, categoria_id, sinonimos` | `sinonimos` soporta array JSON y formato array de PostgreSQL `{a,b}` |
| `User` (`auth_service.dart`) | `id, email, nombre_completo, rol` | modelo local de sesión |

**Inventario de endpoints auditado:** 28 rutas en `backend/src/routes/index.js` verificadas
cruzadamente contra los servicios Flutter (Auth, Profile, Vehicles, Brands/Models, Catalog,
Addresses, Warehouses, Requests, Quotations, Orders, Admin).

**Observación de contrato (B13, pendiente):** `API_DOCUMENTATION.md` describe `GET /marcas` y
`GET /modelos`, pero el backend real expone `GET /brands` y `GET /models`; además coexisten tres
envoltorios de respuesta (`{exito, datos}`, arrays crudos, `{success, data}`).

---

## 4. Correcciones Aplicadas

### 4.1 B1 — CORS con switch por ambiente · `backend/server.js`

**Riesgo:** el bloque CORS activo aplicaba siempre la allowlist de desarrollo
(`localhost:3000/3002`, IP local) incluso en producción.

```js
const allowedOrigins = isProd
  ? (process.env.ALLOWED_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean)
  : ['http://localhost:3000', 'http://127.0.0.1:3000',
     'http://localhost:3002', 'http://127.0.0.1:3002',
     'http://192.168.100.2:3000', 'http://192.168.100.2:3002'];

app.use(cors({
  origin(origin, callback) {
    // Permite peticiones sin origin (curl, apps nativas)
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
}));
```

- En producción la allowlist se lee de `ALLOWED_ORIGINS` (lista separada por comas).
- Se creó `backend/.env.example` documentando `ALLOWED_ORIGINS` y el resto de variables.

**Verificación:** matriz dev/prod con `curl` — orígenes permitidos → `204 + Access-Control-Allow-Origin`;
no permitidos → bloqueados (sin header ACAO); peticiones sin origin (apps nativas) → permitidas.

### 4.2 B2 — Rate-limit por capas · `backend/server.js`

**Riesgo:** límite único de 100 req/15 min por IP: demasiado bajo para la app móvil y a la vez
demasiado alto para endpoints de credenciales (fuerza bruta).

```js
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,   // 15 minutos
  max: 20,                    // intentos de credenciales por IP por ventana
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Demasiados intentos. Intenta nuevamente en unos minutos.'
});
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/auth/refresh', authLimiter);

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,                   // peticiones por IP por ventana (uploads van directo a Supabase)
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', apiLimiter);
```

- Los limiters de auth se registran **antes** del genérico (el prefijo `/api/` también matchea
  `/api/auth/*`).
- El contador de 20 es **compartido** entre login/register/refresh (misma instancia del limiter):
  bloquea fuerza bruta de credenciales y adivinanza de refresh tokens.

**Verificación:** 21 POST a `/api/auth/login` → `401×18 → 429×3` (corte en el tope de 20);
`GET /api/requests` siguió respondiendo `401` (no `429`), confirmando contadores independientes.

### 4.3 B3 — Error handler sin fuga de detalles en producción · `backend/server.js`

**Riesgo:** `err.message` (p. ej. errores crudos de Supabase) y stack se enviaban al cliente en
cualquier ambiente.

```js
app.use((err, req, res, next) => {
  if (isProd) {
    return res.status(err.status || 500).json({ error: 'Internal server error' });
  }
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    stack: err.stack
  });
});
```

**Verificación:** en prod, CORS con origin no permitido → `500 {"error":"Internal server error"}`
sin mensaje interno ni stack (antes: `Not allowed by CORS` + stack trace).

### 4.4 B8 — `/auth/refresh` sin fallback a service-role key · `backend/src/controllers/authController.js`

**Riesgo:** si faltaba `SUPABASE_ANON_KEY`, el endpoint público operaba con la **service-role key**
(privilegios de administrador, bypass de RLS), elevando cualquier abuso de refresh tokens.

```js
// El refresh de sesión es una operación de cliente y SOLO debe usar la
// anon key. NUNCA se usa la service-role key aquí: un endpoint público
// operando con la service key tendría privilegios de administrador
// (bypass de RLS) y elevaría cualquier abuso de refresh tokens.
const supabaseAuthKey = process.env.SUPABASE_ANON_KEY;

if (!process.env.SUPABASE_URL || !supabaseAuthKey) {
  return res.status(500).json({
    message: 'Servicio de autenticación no configurado'
  });
}
```

- Sin anon key el endpoint **falla cerrado** (500) en lugar de degradar silenciosamente.
- La service-role key sigue usándose legítimamente en `backend/src/services/supabase.js`
  (acceso server-side a la DB, por diseño).
- `backend/.env.example` documenta el requisito.

**Verificación:** con `SUPABASE_ANON_KEY=""` → `500 "Servicio de autenticación no configurado"`;
con la anon key configurada y token inválido → `401 "Refresh token inválido o expirado"`.

### 4.5 UX-1 — Salida controlada desde `CompleteProfilePage` (almacén) · `lib/pages/complete_profile_page.dart`

**Problema:** los 4 puntos de entrada a `/complete-profile` usan `context.goNamed(...)` (reemplaza
el stack completo), por lo que `context.pop()` y el back del sistema no tenían a dónde volver.
Restaurar el back "a secas" habría creado bucles infinitos (login/dashboard/perfil redirigen de
nuevo aquí cuando el almacén no tiene perfil).

**Solución:** interceptar el retroceso con `PopScope(canPop: false, onPopInvokedWithResult: ...)`
y ofrecer la única salida coherente: **cerrar sesión con confirmación**.

```dart
return PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    _confirmarSalida();
  },
  child: Scaffold( ... ),
);
```

- El botón atrás del AppBar dispara `_confirmarSalida()` (diálogo "Salir del registro").
- Al confirmar: `AuthService().signOut()` → el router redirige a `/welcome` vía `authStateChanges`.
- Guards `_isSubmitting` / `_isConfirmingExit` evitan salida durante envío y diálogos duplicados.

**Verificación:** `flutter analyze` sin issues; `flutter test` 9/9.

### 4.6 C1 — Reconexión sin aviso ni recarga en el dashboard de almacén · `lib/pages/warehouse_dashboard.dart`

**Problema:** al desactivar el modo avión, el dashboard de almacén no recargaba el feed de
solicitudes ni avisaba (las solicitudes solo se cargaban en `initState`; el listado "sí cargaba"
porque fuerza un refresh al abrirse).

**Solución:** watcher de conectividad (`Connectivity().onConnectivityChanged`):

- **offline → online:** SnackBar "¡Has vuelto a tener conexión! Actualizando solicitudes..." +
  `_validateAndLoad()` (recarga perfil, solicitudes y cotizaciones en la misma pantalla).
- **online → offline:** SnackBar "Sin conexión. Se muestran los datos disponibles."
- `dispose()` cancela la suscripción.

**Verificación:** `flutter analyze` 0 issues; `flutter test` 9/9.

### 4.7 C2 — Aprobación de almacén sin refresco automático · `lib/pages/warehouse_dashboard.dart`

**Problema:** al aprobar un almacén pendiente desde el panel admin, la app quedaba en "En
Verificación" hasta salir/reloguear (no había suscripción realtime ni polling del estado).

**Solución:** watcher de aprobación por polling mientras el almacén no esté aprobado:

```dart
static const Duration _approvalPollInterval = Duration(seconds: 10);
_approvalTimer ??= Timer.periodic(_approvalPollInterval, (_) {
  if (mounted) _checkApprovalStatus();
});
```

- Cada tick consulta `GET /warehouse/my-warehouse` (con fallback a caché local offline).
- Al detectar la transición `pending → approved`: cancela el timer, muestra SnackBar
  "¡Tu almacén ha sido aprobado!...", carga el feed de solicitudes y cotizaciones y activa la
  suscripción realtime de nuevas solicitudes — sin navegar ni cerrar sesión.
- También cubre el caso `rejected` (banner "Almacén Rechazado" en ≤ 10 s).

**Decisión técnica:** se eligió **polling (10 s)** en lugar de realtime porque no existe migración
que confirme que `almacenes` esté en la publicación `supabase_realtime` ni una política RLS de
SELECT para el encargado (el MCP de Supabase no estaba disponible para verificarlo). El polling
usa el stack actual sin tocar la DB. **Mejora futura:** `ALTER PUBLICATION supabase_realtime ADD
TABLE public.almacenes;` + policy RLS `encargado_id = auth.uid()` habilitaría el mismo efecto en
tiempo real.

**Verificación:** `flutter analyze` 0 issues; `flutter test` 9/9.

### 4.8 C3 — Home del cliente: aviso de reconexión y refresco robusto · `lib/pages/home_page.dart` + `lib/providers/solicitudes_provider.dart`

**Problema:** el Home no avisaba al recuperar la red y su refresco era frágil: el listener del
provider llamaba `refreshFromServer()` que consulta `isOffline()` justo tras el evento de
reconexión (falso "offline") y abortaba sin reintento.

**Solución:**

1. `HomePage._initConnectivityWatcher()`: SnackBar "¡Has vuelto a tener conexión!..." +
   `refreshFromServer()` + `_cargarEstadisticas()` en la transición offline → online; SnackBar
   de "Sin conexión" en la inversa.
2. `SolicitudesProvider`:
   - **Delay de 400 ms** tras el evento de reconexión antes de refrescar (evita el falso
     negativo de `checkConnectivity()`).
   - **Guard `_isRefreshing`**: descarta refrescos concurrentes (listener + Home + listado).

**Verificación:** `flutter analyze` 0 issues; `flutter test` 9/9.

### 4.9 C4 — Solicitud offline que desaparecía del Home y borrado remoto no reflejado · `lib/services/solicitud_repository.dart`

**Problema 1 (desaparición):** el Home muestra `solicitudes.take(3)` y `watchTodas()` no tenía
`ORDER BY` → SQLite devolvía por rowid físico; el `INSERT OR REPLACE` reubica filas (rowid nuevo)
y la solicitud recién sincronizada quedaba fuera de las 3 primeras → "desaparecía". En "Ver todas"
aparecía porque muestra todas, y el refresh al entrar volvía a barajar los rowids.

**Problema 2 (borrado no reflejado):** tras cambiar a upsert puro para proteger la carrera
pull/push, la caché local nunca eliminaba filas borradas en Supabase (el borrado remoto no se
reflejaba en Home ni en el listado).

**Solución:**

1. **`watchTodas()` con orden determinista** (`updatedAt DESC, createdAt DESC`): la solicitud
   más reciente siempre cae dentro de las 3 primeras del Home.
2. **`reemplazarDesdeServidor()` = espejo con gracia temporal (30 s):**
   - Borra las filas sincronizadas que ya no existen en el snapshot (borrado remoto reflejado).
   - Gracia de 30 s: conserva filas sincronizadas con `updatedAt` reciente aunque falten en el
     snapshot (protege la carrera pull/push sin reintroducir el bug de desaparición).
   - UPSERT por id; las filas pendientes de outbox (`synced = false`) nunca se tocan.
3. Se reemplazaron los `debugPrint` de este archivo por `AppLogger` (B9 parcial).

**Verificación:** `flutter analyze` 0 issues (proyecto completo); `flutter test` 9/9.

---

## 5. Brechas Pendientes

| ID | Brecha | Área | Prioridad |
|----|--------|------|-----------|
| B4 | Falta interceptor de logging de requests (solo debug, sin `Authorization`) | Observabilidad | Media |
| B5 | Adoptar `json_serializable` para `Almacen` y `Cotizacion` (build_runner ya disponible para drift) | Calidad | Media |
| B6 | Unificar envoltorio de respuesta (`{exito,datos}` / array crudo / `{success,data}`) en `ApiClient.getList` | Contrato | Media |
| B7 | `AuthService().init()` sin `unawaited` explícito en `main.dart` | Robustez | Baja |
| B9 | Parcial: `debugPrint` → `AppLogger` en `solicitud_repository.dart` ✅; pendiente `create_quotation_page.dart` (duplica subida a Supabase → extraer a `UploadService`) y `warehouse_dashboard.dart` (instancia servicios directo) | Arquitectura | Baja |
| B10 | Idempotencia de Outbox: enviar `client_id` como `Idempotency-Key` en `POST /requests` y deduplicar en backend | Resiliencia | Baja |
| B11 | Parseo estricto de `estado_abierto` (`== true` en lugar de `?? true`) | Robustez | Baja |
| B13 | Alinear `API_DOCUMENTATION.md` (`/marcas` → `/brands`, `/modelos` → `/models`) y envoltorios | Contrato | Informativa |
| B14 | Deduplicar SnackBar 403 (múltiples 403 concurrentes encolan varios) | UX | Baja |
| B12 | Migración a `dio`: **no recomendada** hoy — mantener `http` + wrapper; migrar solo si se exige `CancelToken` o `onSendProgress` | Decisión | — |
| C5 | Realtime de `almacenes` (publicación `supabase_realtime` + RLS SELECT) para reemplazar el polling de aprobación | UX/Offline | Media (futura) |

---

## 6. Procedimiento de Prueba de Flujo Completo (expiración de token)

### Escenario A — Renovación automática (401 → refresh → reintento exitoso)
1. En `backend/.env`, temporalmente `JWT_EXPIRES_IN=10s`. Reiniciar el backend.
2. Login (`POST /auth/login` → token de 10 s). Esperar 11 s y disparar un GET autenticado.
3. **Esperado:** en DevTools/Network salen 2 llamadas — `401` → `POST /auth/refresh` → la
   petición original se re-ejecuta con `200`. La sesión **no** se cierra.

### Escenario B — Cierre de sesión (401 + refresh fallido)
1. Login normal; revocar el refresh token (Supabase Auth Admin) o borrarlo del almacén seguro.
2. Esperar la expiración del JWT y disparar un GET autenticado.
3. **Esperado:** 401 → refresh 401 → `clearLocalSession()` → redirect a `/welcome?from=...` →
   `UserRoleProvider` en `unknown` → tablas Drift limpiadas.

### Escenario C — 403 sin cierre de sesión
1. Login como `cliente` y navegar a `/dashboard` (o `GET /requests/active` con token de cliente).
2. **Esperado:** SnackBar "No tienes permisos para realizar esta acción." y el usuario
   permanece autenticado (el router además bloquea el cruce de roles).

### Escenario D — 422 mapeado a campos
1. En `POST /requests`, enviar `vehiculo_id` inexistente.
2. **Esperado:** `ApiErrorHandler.mapValidationErrors` ubica el error bajo el campo del formulario
   (formato `errors/field`).

### Escenario E — Offline → reconexión (imagen + solicitud)
1. Modo avión; crear solicitud con foto. Verificar: outbox `PENDING`, imagen persistida en disco.
2. Desactivar modo avión. **Esperado:** `SyncEngine` procesa la cola (backoff exponencial si
   falla), sube la imagen a Supabase Storage, completa `POST /requests`, elimina el archivo local
   y marca la fila `synced` con el ID real.

---

## 7. Registro de Decisiones de IA / Seguridad

| Herramienta IA | Consulta / tarea realizada | Resultado utilizado | Modificación aplicada | Verificación de seguridad / técnica |
|---|---|---|---|---|
| Devin (CLI) | Auditoría de la capa de red, servicios remotos, persistencia y seguridad (cliente + backend) contra el contrato de API | Inventario de 28 endpoints, mapeo modelo↔contrato, análisis de `ApiClient`, Outbox/SyncEngine y `server.js` | Informe inicial (docs §1–6) | `flutter analyze` 0 issues; `flutter test` 9/9; grep de secretos; `git check-ignore` |
| Devin (CLI) | Aplicación de corrección B1 — CORS por ambiente | Allowlist de prod vía `ALLOWED_ORIGINS` | `backend/server.js` + creación `backend/.env.example` | `node --check` OK; smoke test dev/prod con `curl` (204/500, sin origin permitido) |
| Devin (CLI) | Aplicación de corrección B2 — rate-limit por capas | `authLimiter` (20/15 min, compartido login/register/refresh) + `apiLimiter` (300/15 min) | `backend/server.js` | `node --check` OK; 21× login → 429 en el tope; genérico intacto (401) |
| Devin (CLI) | Aplicación de corrección B3 — error handler sin fuga en prod | Respuesta genérica `{"error":"Internal server error"}` en prod; detalle solo en dev | `backend/server.js` | `node --check` OK; smoke test prod sin stack ni mensaje interno |
| Devin (CLI) | Aplicación de corrección B8 — refresh sin fallback a service-role key | Endpoint fail-closed sin `SUPABASE_ANON_KEY` | `backend/src/controllers/authController.js` + `.env.example` | `node --check` OK; 500 fail-closed sin anon key; 401 normal con anon key |
| Devin (CLI) | Corrección UX-1 — salida desde `CompleteProfilePage` | `PopScope` + diálogo de cierre de sesión | `lib/pages/complete_profile_page.dart` | `flutter analyze` 0 issues; `flutter test` 9/9; `dart format` |
| Devin (CLI) | Corrección C1 — reconexión sin aviso/recarga en dashboard de almacén | Watcher de conectividad (SnackBar + `_validateAndLoad`) | `lib/pages/warehouse_dashboard.dart` | `flutter analyze` 0 issues; `flutter test` 9/9; `dart format` |
| Devin (CLI) | Corrección C2 — aprobación de almacén sin refresco automático | Polling de estado de aprobación (10 s) + activación del feed | `lib/pages/warehouse_dashboard.dart` | `flutter analyze` 0 issues; `flutter test` 9/9 |
| Devin (CLI) | Corrección C3 — Home sin aviso de reconexión y refresco frágil | Watcher de conectividad en `HomePage`; delay 400 ms + guard `_isRefreshing` en `SolicitudesProvider` | `lib/pages/home_page.dart` + `lib/providers/solicitudes_provider.dart` | `flutter analyze` 0 issues; `flutter test` 9/9 |
| Devin (CLI) | Corrección C4 — solicitud offline desaparecía del Home y borrado remoto no reflejado | `ORDER BY` determinista en `watchTodas()`; espejo con gracia (30 s) en `reemplazarDesdeServidor()`; `debugPrint` → `AppLogger` | `lib/services/solicitud_repository.dart` | `flutter analyze` 0 issues (proyecto completo); `flutter test` 9/9 |

---

**Documento generado el:** 2026-09-13
**Última actualización:** 2026-09-13 — correcciones C1–C4 (UX/offline-first)
**Próxima revisión sugerida:** tras aplicar B4–B14 o ante cambios en el contrato de API.
