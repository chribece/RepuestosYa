# RepuestosYa — Guía de despliegue (producción)

> Fecha: 2026-10-03 · Última revisión: 2026-10-03
>
> Esta guía cubre el despliegue público por HTTPS del backend (Render), el
> admin panel (Vercel) y la base de datos/Auth/Storage de producción
> (Supabase, proyecto separado del de desarrollo).

---

## 1. Resumen y URLs definitivas

| Componente | Proveedor | Plan | URL |
|---|---|---|---|
| Backend (Express) | Render | Free | `https://repuestosya.onrender.com` |
| Admin panel (Next.js) | Vercel | Hobby | `https://repuestos-ya-vert.vercel.app` |
| Base de datos / Auth / Storage | Supabase | Free | proyecto de **producción** separado del de desarrollo |

- `ALLOWED_ORIGINS` en Render: exactamente `https://repuestos-ya-vert.vercel.app`
  (sin barra final). La app móvil no usa CORS. Si se usan dominios de preview
  de Vercel (p. ej. `repuestos-ya-vert-<hash>-vercel.app`), añadirlos separados
  por comas solo si la app de preview necesita llamar a la API.
- Admin panel: variable `NEXT_PUBLIC_API_URL` en Vercel =
  `https://repuestosya.onrender.com` (el panel añade/normaliza el sufijo
  `/api` automáticamente; ver §5).
- Las imágenes van a Supabase Storage, nunca al disco efímero de Render.

---

## 2. Arquitectura

```
┌─────────────┐   HTTPS    ┌──────────────────────┐   HTTPS    ┌─────────────────┐
│ App Flutter │ ─────────▶ │ Backend Express      │ ─────────▶ │ Supabase (prod) │
│ (móvil)     │            │ repuestosya.onrender │ (service   │  BD / Auth /     │
└─────────────┘            │ .com  (Render free)  │   role)    │  Storage)        │
                           └──────────▲───────────┘            └─────────────────┘
                                      │ HTTPS (CORS)
                           ┌──────────┴───────────┐
                           │ Admin panel (Vercel) │
                           │ repuestos-ya-vert    │
                           │ .vercel.app          │
                           └──────────────────────┘
```

- El backend expone la API bajo `/api/*` y el endpoint público `GET /health`.
- El worker de notificaciones (BullMQ) se apoya en Redis; en Render free usar
  el Redis free del mismo proyecto.

---

## 3. Backend — preparación hecha en el repo (Parte 1)

| Cambio | Dónde | Detalle |
|---|---|---|
| `GET /health` | `backend/src/controllers/healthController.js` + `server.js` | Público, registrado **antes** de los rate limiters. Responde `200 {status, version, uptime, timestamp, db}` con ping barato a Supabase (`head` query); si la BD falla → `503 {db:"error"}`. Nunca expone `err.message`. |
| Validación de variables al arranque | `backend/src/config/env.js` | En `NODE_ENV=production`, si falta una variable obligatoria el proceso **termina** listando solo los nombres (nunca valores). |
| Error handler sin fuga (B3) | `server.js` | En producción responde `{"error":"Internal server error"}` (nunca `err.message` ni stack); el detalle se escribe solo en los logs del servidor (`logger.error` → stderr). |
| Logging de requests (B4) | `server.js`, `src/middleware/timing.js`, `src/utils/logger.js` | Requests (método, ruta, status, ms) solo si `NODE_ENV !== 'production'` o `LOG_LEVEL=debug`. Nunca se registran headers `Authorization`, bodies de login ni tokens. |
| `SUPABASE_ANON_KEY` obligatoria (B8) | `src/config/env.js`, `src/controllers/authController.js` | Sin anon key el proceso no arranca en prod; `/auth/refresh` es fail-closed (500) y **nunca** cae a la service-role key. |
| Trust proxy + HTTPS obligatorio | `server.js` | `app.set('trust proxy', 1)` para que el rate-limit vea la IP real detrás del proxy. En prod, `x-forwarded-proto !== 'https'` → GET/HEAD redirigen a https (301), el resto se rechaza con 403. |
| Redis a prueba de caídas | `src/services/cache.js`, `src/queues/notificaciones.queue.js`, worker | Listeners de error en las conexiones ioredis: un Redis caído degrada (caché/notificaciones) pero **no** tumba el proceso. |
| `engines` Node 20+ | `backend/package.json`, `backend/.nvmrc` | `"engines": {"node": ">=20.0.0"}`, `.nvmrc` con `20`. |
| Despliegue | `render.yaml` (raíz del repo) | Blueprint de Render (rootDir `backend`, healthCheckPath `/health`, secretos con `sync: false`). |
| Scripts de BD | `backend/scripts/apply_migrations.js`, `backend/scripts/verificar-migraciones.js` | Aplicar migraciones en orden explícito y verificar el esquema (solo lectura). Ver §6. |

---

## 4. Despliegue del backend en Render

### 4.1 Opción A — Blueprint (recomendado)

1. Subir el repo con `render.yaml` a GitHub.
2. En Render → **New → Blueprint**, seleccionar el repo.
3. Render crea el servicio `repuestosya-backend` (rootDir `backend`, plan free).
4. En **Environment**, cargar los secretos (ver §4.3).
5. Primer deploy y verificar: `curl https://repuestosya.onrender.com/health`.

### 4.2 Opción B — Web Service manual

- Root directory: `backend`
- Runtime: Node
- Build command: `npm ci --omit=dev`
- Start command: `npm start`
- Health Check Path: `/health` (Render marcará el servicio como *degraded*
  si no responde 200)
- Plan: Free
- Luego cargar las variables de §4.3.

### 4.3 Variables de entorno en Render

| Variable | Valor | Notas |
|---|---|---|
| `NODE_ENV` | `production` | Obligatoria; activa validación, HTTPS y silenciado de `console.*`. |
| `NODE_VERSION` | `20` | Node 20+ (también hay `backend/.nvmrc`). |
| `ALLOWED_ORIGINS` | `https://repuestos-ya-vert.vercel.app` | Exacto, sin barra final. |
| `JWT_EXPIRES_IN` | `8h` | Requerida (sin expiración los JWT serían válidos para siempre). |
| `SUPABASE_URL` | (secreto) | URL del proyecto Supabase de **producción**. |
| `SUPABASE_SERVICE_ROLE_KEY` | (secreto) | Solo server-side; nunca en el cliente. |
| `SUPABASE_ANON_KEY` | (secreto) | Requerida por `/auth/refresh`. |
| `JWT_SECRET` | (secreto) | Generar: `openssl rand -hex 64`. |
| `REDIS_URL` | (secreto) | Redis del proyecto (free) — ver §4.4. |
| `PORT` | (auto) | Render la inyecta; el código usa `process.env.PORT \|\| 3000`. |

El backend escucha en `0.0.0.0` (todas las interfaces) y en `process.env.PORT`.

### 4.4 Redis

`REDIS_URL` es **obligatoria en producción**: la caché
(`src/services/cache.js`) y la cola de notificaciones BullMQ
(`src/queues/notificaciones.queue.js` + worker) la necesitan. En Render:

1. **New → Redis** (plan free, 256 MB).
2. Copiar la URL interna (`redis://...` con password) y pegarla en
   `REDIS_URL` del servicio web.
3. Opcionalmente desplegar el worker como servicio separado
   (`npm run worker`) si se quiere procesar notificaciones.

> Nota: si no se configura Redis, el proceso **no arranca en producción**
> (validación de variables). Esto es deliberado: mejor fallar claro que
> arrancar con caché/cola rotas.

---

## 5. Admin panel en Vercel

1. Importar `admin-panel/` en Vercel (framework: Next.js; build:
   `npm run build`).
2. En **Project → Settings → Environment Variables**, añadir:

   | Variable | Valor |
   |---|---|
   | `NEXT_PUBLIC_API_URL` | `https://repuestosya.onrender.com` |

   > El código (`src/lib/api.ts`) normaliza la base: si no termina en `/api`,
   > se lo añade. Por eso vale con o sin sufijo. En producción **nunca** hay
   > fallback a `localhost` (si falta la variable, la URL queda relativa y el
   > fallo es visible).
3. Revisado: `next.config.js` no contiene `localhost` ni URLs de API (solo
   el patrón de imágenes de Supabase Storage). No hay `http://` hardcodeado
   en el panel.
4. `ALLOWED_ORIGINS` del backend ya incluye el dominio de Vercel, así que el
   CORS del panel funciona directo.

---

## 6. Base de datos (Supabase)

> **Decisión de producción (2026-10-03):** el despliegue usa la **misma base de
> datos Supabase del desarrollo** (`vpgnasrlgdgkxpggorxl`) — ya contiene todas
> las tablas, datos, usuarios y el bucket `Repuestosya`. **No** se creó un
> proyecto separado ni se aplicaron migraciones (el esquema ya está al 100 %).
> Las credenciales (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`,
> `SUPABASE_ANON_KEY`) en Render apuntan a ese mismo proyecto.
>
> La sección 6.1–6.4 queda como **procedimiento de referencia** si en el
> futuro se decide separar la BD de producción de la de desarrollo.

> **No** conectar el backend de producción al proyecto Supabase de desarrollo.
> Crear un proyecto nuevo para producción; las credenciales (`SUPABASE_URL`,
> `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`) van en Render (§4.3).

### 6.1 Crear el proyecto

1. En Supabase Dashboard → **New project** (organización de producción).
2. Anotar: `Project URL` (→ `SUPABASE_URL`), `anon public` key (→
   `SUPABASE_ANON_KEY`), `service_role` key (→ `SUPABASE_SERVICE_ROLE_KEY`).
3. **Auth → Providers → Email**: decidir si se exige confirmación de email.
   El repo incluye `disable_email_verification.sql` (lo que usa el proyecto
   dev); en producción se **recomienda mantener la verificación activada**
   y no aplicar esa migración.
4. **Storage**: crear el bucket `Repuestosya` (público para lectura; las
   políticas de escritura se aplican con la migración
   `20260918_storage_policies_repuestosya.sql`).

### 6.2 Esquema base (prerequisito)

El repo contiene solo las migraciones **incrementales**; el esquema base
(tablas `profiles`, `vehiculos`, `almacenes`, `solicitudes_repuesto`,
`cotizaciones`, enums `user_role`, `solicitud_status`, `cotizacion_status`,
etc.) se creó manualmente en el proyecto de desarrollo y **no está en el
repo**. Para producción:

- **Opción recomendada:** exportar el esquema del proyecto dev (Supabase →
  SQL Editor → *New query* → ver el DDL generado, o
  `supabase db dump --schema public` con la CLI) y ejecutarlo en el proyecto
  de producción **antes** de las migraciones.
- Alternativa: reconstruir el esquema a mano siguiendo la documentación de
  tablas del proyecto (`docs/03-backend-tecnico.md` y
  `API_DOCUMENTATION.md`).

Verificar después con `scripts/verificar-migraciones.js`.

### 6.3 Aplicar las migraciones (orden exacto)

**Prerequisito:** crear una vez la función `exec_sql` (la usan los scripts y
`scripts/run_migration.js`):

```sql
CREATE OR REPLACE FUNCTION public.exec_sql(sql text)
RETURNS void AS $$
BEGIN
  EXECUTE sql;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Opción A — script del repo** (requiere las keys del proyecto destino en el
entorno/`.env`):

```bash
cd backend
node scripts/apply_migrations.js        # todas, en orden
node scripts/verificar-migraciones.js   # verificación solo lectura
```

**Opción B — Supabase SQL Editor / MCP**, aplicando cada archivo en este
orden (el orden es explícito por dependencias; p. ej.
`20260919_fix_fk_direccion_entrega.sql` debe ir **después** de
`update_direcciones_entrega_structure.sql`, que hace `DROP TABLE ... CASCADE`):

| # | Archivo (`backend/migrations/`) | Qué hace |
|---|---|---|
| 1 | `update_user_trigger.sql` | Trigger `handle_new_user` que crea `profiles` con rol desde metadata. |
| 2 | `make_trigger_idempotent.sql` | Reemplaza el trigger: no falla si el perfil ya existe (estado final). |
| 3 | `fix_profiles_foreign_key.sql` | Quita la FK inválida `profiles_id_fkey` si existe. |
| 4 | `fix_profiles_rls.sql` | Políticas RLS de `profiles` (service_role + usuario propio). |
| 5 | `add_warehouse_fields.sql` | Columnas `ruc`, `representante_legal`, `telefono`, `email` + checks en `almacenes`. |
| 6 | `update_direcciones_entrega_structure.sql` | **DROP CASCADE** y recrea `direcciones_entrega` (estructura por calles) + RLS. |
| 7 | `add_ordenes_compra_and_cotizacion_workflow.sql` | Estados de cotización/solicitud, tabla `ordenes_compra`, RPC `aceptar_cotizacion`. |
| 8 | `add_part_catalog_and_normalization.sql` | Catálogo: `categorias_repuestos`, `repuestos_catalogo` + RLS. |
| 9 | `fix_solicitudes_repuesto_rls.sql` | Políticas RLS de `solicitudes_repuesto` (dueño + almacenes ven activas). |
| 10 | `disable_email_verification.sql` | **Opcional** (solo dev): auto-confirma emails. En producción recomendado NO aplicarla. |
| 11 | `20260918_idempotency_keys.sql` | `idempotency_key` en `solicitudes_repuesto` (reintentos seguros). |
| 12 | `20260918_storage_policies_repuestosya.sql` | Políticas del bucket Storage `Repuestosya` (escritura solo del dueño del path). |
| 13 | `20260919_fix_fk_direccion_entrega.sql` | Recrea la FK `solicitudes_repuesto.direccion_entrega_id` (rota por el DROP del paso 6). |
| 14 | `20260919_ubicacion_obligatoria.sql` | Coordenadas en `direcciones_entrega`/`solicitudes_repuesto` + `distancia_km`/`tiempo_despacho` en `cotizaciones`. |
| 15 | `20260929_add_solicitud_status_cancelada.sql` | Valor `cancelada` en enum `solicitud_status` (PATCH /requests/:id/status). |

### 6.4 Verificación posterior

```bash
cd backend
node scripts/verificar-migraciones.js
```

Comprueba (solo lectura) tablas base y columnas clave de las migraciones.
Además:

```sql
-- En el SQL editor del proyecto de PRODUCCIÓN:
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' ORDER BY table_name;
```

Esperado: `almacenes`, `categorias_repuestos`, `cotizaciones`,
`direcciones_entrega`, `ordenes_compra`, `profiles`, `repuestos_catalogo`,
`solicitudes_repuesto`, `vehiculos` (y las auxiliares del catálogo).

**RLS:** verificar en *Database → Policies* que las tablas tienen RLS
habilitado (los archivos 4, 6, 8, 9 y 12 crean las políticas; la policy
"service role can do anything" es la que usa el backend con la service key).

---

## 7. Plan gratuito: qué garantiza y qué no

> Datos verificados en la documentación oficial del proveedor el **2026-10-03**:
> - Render — [Free tier docs](https://render.com/docs/free)
> - Supabase — [Free project pausing](https://supabase.com/docs/guides/platform/free-project-pausing)
>
> `VERIFICAR EN DOCUMENTACIÓN OFICIAL DEL PROVEEDOR (2026-10-03)` antes de
> tomar decisiones de capacidad; los planes gratuitos cambian con frecuencia.

### Render (Free)

- **HTTPS gestionado:** sí, certificado automático y renovación incluida
  (acceso vía `https://repuestosya.onrender.com`).
- **Suspensión por inactividad:** el servicio se duerme a los **15 minutos**
  sin tráfico entrante (peticiones HTTP o mensajes WebSocket).
- **Reactivación:** el primer request tras dormirse tarda en responder
  ~50–60 s (la doc oficial dice "about one minute"); el navegador muestra una
  página de carga mientras despierta.
- **Horas de cómputo:** 750 h/mes; los servicios dormidos no consumen horas.
- **No garantiza:** SLA de disponibilidad, cero latencia en el primer request
  tras el sueño, ni persistencia de disco (el filesystem es efímero: por eso
  las imágenes van a Supabase Storage).

### Supabase (Free)

- **Pausa por inactividad:** el proyecto se pausa tras **7 días** de baja
  actividad (pocas consultas a la BD en la semana). Se envía un email de
  aviso ~1 semana antes.
- **Evitar la pausa:** unas pocas peticiones a la BD al día bastan (el
  `GET /health` del backend hace ping a Supabase en cada chequeo, lo que
  ayuda a mantener actividad).
- **Restauración:** un proyecto pausado se restaura desde el Dashboard
  (hasta 1 año después de la pausa).
- **Límites free:** 2 proyectos activos por organización, cuotas de base de
  datos y storage limitadas (ver *Fair Use Policy*).

### Consecuencia operativa

- El primer `curl https://repuestosya.onrender.com/health` de la mañana puede
  tardar ~1 min. Los clientes (app móvil) deben tener timeout de conexión
  acorde y reintentar.
- Si la BD de producción se pausa, el `/health` responderá `503 {"db":"error"}`
  y la API fallará hasta reactivar el proyecto en el Dashboard.

---

## 8. ¿Por qué no se usa un túnel?

No se usa túnel (ngrok/cloudflared/localtunnel) para producción porque:

1. **URL inestable**: los túneles gratuitos cambian de dominio o expiran
   (sesiones temporales), y la app móvil y el admin panel necesitan una URL
   fija configurable.
2. **HTTPS no gestionado**: el certificado depende del proveedor del túnel;
   Render/Vercel gestionan TLS de extremo a extremo con renovación automática.
3. **Sin reactivación automática**: el túnel depende de que la máquina local
   esté encendida; un servicio en Render está disponible aunque nadie tenga el
   portátil abierto.
4. **Capa extra de latencia/fragilidad**: un túnel añade un hop intermedio y
   un punto de fallo más.

Los túneles quedan como herramienta de **desarrollo** (p. ej. probar la app
móvil contra un backend local expuesto temporalmente), nunca para producción.

---

## 9. HTTPS y CORS (backend)

- HTTPS lo termina Render; el backend lo **exige**: en producción, si
  `x-forwarded-proto !== 'https'`, GET/HEAD se redirigen a `https` (301) y el
  resto se rechaza con `403 {"error":"HTTPS required"}`.
- `app.set('trust proxy', 1)` hace que el rate-limit y `req.ip` vean la IP
  real del cliente detrás del proxy de Render.
- CORS en producción solo permite `ALLOWED_ORIGINS`
  (`https://repuestos-ya-vert.vercel.app`). La app móvil no envía `Origin`
  y no se ve afectada.

---

## 10. Verificación post-despliegue

```bash
# Salud (público, sin token). Esperar ~1 min si el servicio estaba dormido.
curl -i https://repuestosya.onrender.com/health
# Esperado: HTTP 200 {"status":"ok","version":"1.0.0","uptime":...,"timestamp":...,"db":"ok"}

# HTTPS obligatorio: contra http:// debe redirigir (301) o rechazar (403).
curl -i http://repuestosya.onrender.com/health

# API con CORS del admin panel.
curl -i -H "Origin: https://repuestos-ya-vert.vercel.app" \
  https://repuestosya.onrender.com/api/brands

# 404 genérico para rutas inexistentes (los logs del Render ya mostraban "GET / 404").
curl -i https://repuestosya.onrender.com/
```

Y con la colección de `docs/api/` (§11) contra `https://repuestosya.onrender.com`:
registro, login, refresh, GET protegido (200/401), 403 de almacén no aprobado
y 422 de validación.

---

## 11. Colección de pruebas de API

- `docs/api/repuestosya.http` — archivo para REST Client (VS Code/JetBrains),
  con variable `{{baseUrl}}`.
- `docs/api/repuestosya.postman_collection.json` — colección Postman v2.1 con
  la misma variable `{{baseUrl}}` y extracción automática del token en login.

Cubre: `/health`, register, login, refresh, GET protegido (200 con token y
401 sin token), 403 de almacén no aprobado (`WAREHOUSE_NOT_APPROVED`) y 422
de validación.

---

## 12. Operación diaria

- **Logs**: Render → servicio → *Logs*. En producción solo salen errores
  (stderr) salvo que se active `LOG_LEVEL=debug`; nunca aparecen headers
  `Authorization`, bodies de login ni tokens (B4).
- **Reinicio manual**: Render → *Manual Deploy* → *Clear build cache & deploy*.
- **Migraciones futuras**: añadir el `.sql` a `backend/migrations/`,
  registrarlo en el `ORDEN` de `scripts/apply_migrations.js` y aplicar con el
  script (o vía SQL editor) contra el proyecto de **producción**.
- **Secretos**: rotarlos (p. ej. `JWT_SECRET`) actualizándolos en Render;
  `render.yaml` los marca `sync: false` para que nunca viajen en el repo.
