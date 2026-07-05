# WORKFLOW: MIGRACIÓN DE SUPABASE A API PROPIA (NODE.JS + EXPRESS)
## Instrucciones para el Asistente de IA (Modo Ejecución)

**IMPORTANTE:** 
- NO generes todo el código de una sola vez. 
- Ejecuta este workflow en **ESTRICTO ORDEN CRONOLÓGICO**. 
- En cada paso, **espera mi confirmación** o solicitud de archivos antes de continuar al siguiente.
- Si necesitas ver un archivo específico de Flutter (ej. `auth_service.dart`), **dímelo explícitamente** y espera a que te lo proporcione.

---

## CONTEXTO DEL PROYECTO (Leer antes de empezar)
- **App:** "RepuestosYa" (Marketplace de repuestos automotrices).
- **Estado:** 40% completado. El frontend (Flutter) usa actualmente `supabase_flutter` para leer/escribir directamente en Supabase.
- **Objetivo:** Eliminar `supabase_flutter` del frontend. Crear un backend intermedio (Node.js/Express) que exponga una API REST. El frontend consumirá únicamente esta API.
- **Base de datos:** El esquema SQL ya está ejecutado en Supabase. Las tablas, enums y funciones están activas.

---

## PASO 1: CONSTRUCCIÓN DEL BACKEND (GENERAR CÓDIGO AHORA MISMO)
Debes generar la estructura completa del servidor Node.js con los siguientes archivos. **Pégalos en la respuesta para que los copie.**

### 1.1. Estructura de carpetas a crear en `/backend`
backend/
├── .env
├── package.json
├── server.js
└── src/
├── services/
│ └── supabase.js
├── middleware/
│ └── auth.js
├── controllers/
│ ├── authController.js
│ ├── profileController.js
│ ├── vehiculoController.js
│ ├── direccionController.js
│ ├── solicitudController.js
│ └── cotizacionController.js
└── routes/
└── index.js

text

### 1.2. Especificaciones de los controladores (Lo que debe hacer cada uno)
- **authController.js**: 
  - `POST /auth/register` → Crea usuario en Supabase Auth y devuelve JWT.
  - `POST /auth/login` → Autentica con Supabase, consulta el rol en `profiles`, firma JWT.
- **profileController.js**: 
  - `GET /profile` → Devuelve datos de `profiles` según `req.user.id`.
  - `PUT /profile` → Actualiza `nombre_completo`, `telefono`, `avatar_url`.
- **vehiculoController.js**: 
  - CRUD completo (`GET /vehiculos`, `POST /vehiculos`, `PUT /vehiculos/:id`, `DELETE /vehiculos/:id`). 
  - Siempre filtrar por `cliente_id = req.user.id`.
- **direccionController.js**: 
  - CRUD completo, filtrando por `cliente_id = req.user.id`.
- **solicitudController.js**: 
  - `POST /solicitudes` (crea con `cliente_id = req.user.id`).
  - `GET /solicitudes` (mis solicitudes).
  - `GET /solicitudes/activas` (solo para rol `almacen`, devuelve todas en `estado = 'en_proceso'`).
- **cotizacionController.js**: 
  - `POST /cotizaciones` (solo almacenes, verifica que la solicitud esté activa).
  - `GET /cotizaciones/mis-cotizaciones` (para almacenes).
  - `PUT /cotizaciones/:id/estado` (solo el cliente dueño puede aceptar/rechazar; al aceptar, cambia solicitud a `completado`).

### 1.3. Requisitos técnicos del Backend
- Usar `jsonwebtoken` con `JWT_SECRET` del `.env`.
- Usar `@supabase/supabase-js` con la **`SUPABASE_SERVICE_ROLE_KEY`** (para saltar RLS).
- Validar en cada endpoint que el `req.user` exista (middleware de autenticación).
- Validar propiedad de los recursos (ej. si el ID del vehículo no pertenece al usuario, retornar 403).

---

## PASO 2: ESPERAR ARCHIVOS DE FLUTTER PARA REFACTORIZAR
**Acción de la IA:** Una vez que hayas generado el código del Backend, **detente** y dime:
> "Backend generado. Por favor, proporcióname los siguientes archivos de tu proyecto Flutter para continuar con la refactorización: `pubspec.yaml`, `lib/services/auth_service.dart`, `lib/repositories/vehiculo_repository.dart` y `lib/main.dart` (o el archivo donde inicializas Supabase)."

**Regla de oro para la refactorización:** 
- No tocar la UI (Widgets).
- Mantener exactamente los mismos nombres de métodos y tipos de retorno en los repositorios.
- Reemplazar `supabase.from(...)` por `ApiClient.get/post/put/delete`.

---

## PASO 3: REFACTORIZACIÓN PROGRESIVA (MÓDULO POR MÓDULO)
La IA debe procesar los archivos en este orden estricto, esperando confirmación tras cada uno:

### 3.1. Crear `ApiClient` (`lib/services/api_client.dart`)
- Métodos: `get`, `post`, `put`, `delete`.
- Manejar token en memoria y `SharedPreferences`.
- Agregar `Authorization: Bearer <token>` a todas las peticiones.

### 3.2. Refactorizar `AuthService`
- Antes: Usaba `supabase.auth.signInWithPassword()`.
- Ahora: Usa `ApiClient.post('/auth/login', body: {...})`.
- Guardar el token y devolver el objeto `User`.

### 3.3. Refactorizar `ProfileRepository`
- Reemplazar consultas directas a `profiles` por `ApiClient.get('/profile')`.

### 3.4. Refactorizar `VehiculoRepository`
- Reemplazar todas las llamadas a `supabase.from('vehiculos_cliente')` por `ApiClient`.

### 3.5. Refactorizar `DireccionRepository`
- Similar a vehículos.

### 3.6. Refactorizar `SolicitudRepository` y `CotizacionRepository`
- Aplicar la misma lógica, asegurando que los filtros de estado y roles se manejan en el backend (no en el frontend).

### 3.7. Actualizar `main.dart` (Inicialización)
- Eliminar `Supabase.initialize()`.
- Reemplazar la verificación de sesión (`supabase.auth.currentSession`) por la lectura del token desde `SharedPreferences`.

---

## PASO 4: LIMPIEZA FINAL (Al finalizar todo)
**Acción de la IA:** Cuando todos los repositorios estén migrados, dime:
> "Todos los módulos han sido migrados. Ahora puedes ejecutar `flutter pub remove supabase_flutter` y eliminar las variables de entorno de Supabase en tu frontend."

---

## REGLAS ESTRICTAS PARA LA IA DURANTE EL WORKFLOW

1. **Prohibido tocar Widgets:** Ni un solo `Scaffold`, `Text` o `Container`.
2. **Prohibido cambiar nombres:** Si el repositorio tiene `guardarVehiculo()`, debe llamarse igual en la nueva versión.
3. **Prohibido usar `supabase` en el frontend después del paso 3:** Si ves una línea que lo mencione, sugiere eliminarla.
4. **Autorización en el Backend:** No confiar en RLS. El backend debe verificar manualmente que `req.user.id` coincida con el `cliente_id` o `encargado_id` de cada registro.
5. **Pausas obligatorias:** Después de generar el Backend (Paso 1), debes esperar a que te pase los archivos de Flutter. Después de cada refactorización (Pasos 3.1 a 3.7), debes esperar mi confirmación para continuar.

---

**INICIA EL WORKFLOW AHORA:**
Comienza generando el código completo del Backend (Paso 1). No olvides incluir el `package.json` y el contenido de todos los controladores.