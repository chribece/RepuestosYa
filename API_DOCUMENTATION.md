# Documentación de API - RepuestosYa
## Endpoints para Gestión de Vehículos (Marcas y Modelos)

---

## 1. GET /marcas
**Descripción:** Obtiene todas las marcas de vehículos disponibles en el catálogo.
**Autenticación:** No requerida (endpoint público)

### Solicitud Exitosa
```http
GET http://192.168.10.232:3000/api/marcas
```

**Respuesta (200 OK):**
```json
{
  "exito": true,
  "datos": [
    {
      "id": 1,
      "nombre": "Chevrolet"
    },
    {
      "id": 2,
      "nombre": "Ford"
    },
    {
      "id": 3,
      "nombre": "Toyota"
    },
    {
      "id": 4,
      "nombre": "Honda"
    },
    {
      "id": 5,
      "nombre": "Kia"
    }
  ]
}
```

---

## 2. GET /modelos?marcaId={id}
**Descripción:** Obtiene los modelos de vehículos filtrados por marca.
**Autenticación:** No requerida (endpoint público)
**Parámetros Query:**
- `marcaId` (requerido): ID numérico de la marca

### Solicitud Exitosa
```http
GET http://192.168.10.232:3000/api/modelos?marcaId=1
```

**Respuesta (200 OK):**
```json
{
  "exito": true,
  "datos": [
    {
      "id": 1,
      "nombre": "Aveo Family",
      "marca_id": 1
    },
    {
      "id": 2,
      "nombre": "Sail 1.5",
      "marca_id": 1
    },
    {
      "id": 3,
      "nombre": "Onix",
      "marca_id": 1
    }
  ]
}
```

### Error: marcaId no proporcionado
```http
GET http://192.168.10.232:3000/api/modelos
```

**Respuesta (400 Bad Request):**
```json
{
  "exito": false,
  "errores": [
    {
      "campo": "marcaId",
      "mensaje": "El parámetro marcaId es requerido"
    }
  ],
  "mensaje": "Datos de entrada inválidos"
}
```

### Error: marcaId no numérico
```http
GET http://192.168.10.232:3000/api/modelos?marcaId=abc
```

**Respuesta (400 Bad Request):**
```json
{
  "exito": false,
  "errores": [
    {
      "campo": "marcaId",
      "mensaje": "marcaId debe ser un número entero positivo"
    }
  ],
  "mensaje": "Datos de entrada inválidos"
}
```

### Error: Marca no encontrada
```http
GET http://192.168.10.232:3000/api/modelos?marcaId=999
```

**Respuesta (404 Not Found):**
```json
{
  "exito": false,
  "errores": [],
  "mensaje": "Marca no encontrada"
}
```

---

## 3. POST /vehiculos
**Descripción:** Crea un nuevo vehículo para el usuario autenticado.
**Autenticación:** Requerida (token JWT en header Authorization)
**Body:**
- `marcaId` (requerido): ID numérico de la marca
- `modeloId` (requerido): ID numérico del modelo
- `vin` (opcional): Código VIN del vehículo
- `anio` (opcional): Año del vehículo
- `patente` (opcional): Patente del vehículo

### Solicitud Exitosa
```http
POST http://192.168.10.232:3000/api/vehiculos
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "marcaId": 1,
  "modeloId": 1,
  "vin": "1HGBH41JXMN109186",
  "anio": "2020",
  "patente": "AA123BB"
}
```

**Respuesta (201 Created):**
```json
{
  "exito": true,
  "datos": {
    "id": "uuid-del-vehiculo",
    "cliente_id": "uuid-del-cliente",
    "modelo_id": 1,
    "vin": "1HGBH41JXMN109186",
    "anio": 2020,
    "patente": "AA123BB",
    "created_at": "2026-07-03T02:00:00.000Z",
    "modelos_vehiculo": {
      "id": 1,
      "nombre": "Aveo Family",
      "marca_id": 1,
      "marcas_vehiculo": {
        "id": 1,
        "nombre": "Chevrolet"
      }
    }
  },
  "mensaje": "Vehículo creado correctamente"
}
```

### Error: Campos faltantes
```http
POST http://192.168.10.232:3000/api/vehiculos
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "marcaId": 1
}
```

**Respuesta (400 Bad Request):**
```json
{
  "exito": false,
  "errores": [
    {
      "campo": "marcaId",
      "mensaje": "marcaId es requerido"
    },
    {
      "campo": "modeloId",
      "mensaje": "modeloId es requerido"
    }
  ],
  "mensaje": "Datos de entrada inválidos"
}
```

### Error: marcaId no numérico
```http
POST http://192.168.10.232:3000/api/vehiculos
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "marcaId": "Chevrolet",
  "modeloId": 1,
  "vin": "1HGBH41JXMN109186"
}
```

**Respuesta (400 Bad Request):**
```json
{
  "exito": false,
  "errores": [
    {
      "campo": "marcaId",
      "mensaje": "marcaId debe ser un número entero positivo"
    }
  ],
  "mensaje": "Datos de entrada inválidos"
}
```

### Error: Marca no encontrada
```http
POST http://192.168.10.232:3000/api/vehiculos
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "marcaId": 999,
  "modeloId": 1,
  "vin": "1HGBH41JXMN109186"
}
```

**Respuesta (404 Not Found):**
```json
{
  "exito": false,
  "errores": [],
  "mensaje": "Marca no encontrada"
}
```

### Error: Modelo no encontrado
```http
POST http://192.168.10.232:3000/api/vehiculos
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "marcaId": 1,
  "modeloId": 999,
  "vin": "1HGBH41JXMN109186"
}
```

**Respuesta (404 Not Found):**
```json
{
  "exito": false,
  "errores": [],
  "mensaje": "Modelo no encontrado"
}
```

### Error: Modelo no pertenece a la marca (Inconsistencia)
```http
POST http://192.168.10.232:3000/api/vehiculos
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "marcaId": 1,
  "modeloId": 5,
  "vin": "1HGBH41JXMN109186"
}
```
*(Donde el modelo 5 pertenece a la marca 2, no a la marca 1)*

**Respuesta (422 Unprocessable Entity):**
```json
{
  "exito": false,
  "errores": [
    {
      "campo": "modeloId",
      "mensaje": "El modelo no pertenece a la marca seleccionada"
    }
  ],
  "mensaje": "Inconsistencia de datos: el modelo no corresponde a la marca"
}
```

---

## Instrucciones para probar en Postman/Insomnia

### 1. Configurar el entorno
- **Base URL:** `http://192.168.10.232:3000/api`
- **Content-Type:** `application/json`

### 2. Probar GET /marcas
1. Crear nueva solicitud GET
2. URL: `{{baseUrl}}/marcas`
3. No requiere headers especiales
4. Enviar y verificar que devuelve la lista de marcas

### 3. Probar GET /modelos
1. Crear nueva solicitud GET
2. URL: `{{baseUrl}}/modelos?marcaId=1`
3. No requiere headers especiales
4. Cambiar `marcaId` para probar diferentes marcas
5. Probar con `marcaId=999` para ver error 404
6. Probar sin parámetro para ver error 400

### 4. Probar POST /vehículos
1. Crear nueva solicitud POST
2. URL: `{{baseUrl}}/vehiculos`
3. Headers:
   - `Authorization: Bearer <tu_token_jwt>`
   - `Content-Type: application/json`
4. Body (raw JSON):
```json
{
  "marcaId": 1,
  "modeloId": 1,
  "vin": "1HGBH41JXMN109186",
  "anio": "2020",
  "patente": "AA123BB"
}
```
5. Probar variaciones:
   - Sin `modeloId` → Error 400
   - Con `marcaId: "texto"` → Error 400
   - Con `marcaId: 999` → Error 404
   - Con `modeloId` de otra marca → Error 422

### 5. Obtener Token JWT (si no tienes uno)
1. POST a `{{baseUrl}}/auth/login`
2. Body:
```json
{
  "email": "tu@email.com",
  "password": "tu_password"
}
```
3. Copiar el `token` de la respuesta
4. Usarlo en el header Authorization para las solicitudes protegidas

---

## Flujo de Integración Recomendado

### En la aplicación móvil Flutter:

1. **Al cargar el formulario de vehículo:**
   - Llamar a `GET /marcas` para poblar el primer dropdown
   - Mostrar indicador de carga mientras se obtienen las marcas

2. **Cuando el usuario selecciona una marca:**
   - Llamar a `GET /modelos?marcaId={id_seleccionado}`
   - Limpiar el dropdown de modelos
   - Mostrar indicador de carga mientras se obtienen los modelos
   - Poblar el segundo dropdown con los modelos recibidos
   - Deshabilitar el dropdown de modelos hasta que se seleccione una marca

3. **Al enviar el formulario:**
   - Validar que ambos dropdowns tengan selección
   - Enviar `marcaId` y `modeloId` como números (no strings)
   - Manejar errores según el código HTTP:
     - 400: Mostrar errores de validación específicos
     - 404: Mostrar "Marca o modelo no encontrado"
     - 422: Mostrar "El modelo no corresponde a la marca"
     - 500: Mostrar "Error del servidor, intenta nuevamente"

---

## Estructura de Respuestas Estandarizada

### Éxito
```json
{
  "exito": true,
  "datos": { ... } | [ ... ],
  "mensaje": "Mensaje descriptivo opcional"
}
```

### Error
```json
{
  "exito": false,
  "errores": [
    { "campo": "nombre_campo", "mensaje": "Descripción del error" }
  ],
  "mensaje": "Mensaje general del error"
}
```

---

## Códigos de Estado HTTP Utilizados

| Código | Significado | Cuándo se usa |
|--------|-------------|---------------|
| 200 | OK | GET exitoso |
| 201 | Created | POST exitoso (crear vehículo) |
| 204 | No Content | DELETE exitoso |
| 400 | Bad Request | Datos inválidos, tipo incorrecto |
| 401 | Unauthorized | Token ausente o inválido |
| 403 | Forbidden | Sin permisos |
| 404 | Not Found | Recurso no existe |
| 422 | Unprocessable Entity | Validación de negocio falló |
| 500 | Internal Server Error | Error inesperado |
