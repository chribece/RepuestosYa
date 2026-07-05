# IMPLEMENTACIÓN API REST -
## Estándares CRUD para RepuestosYa (Node.js + Express)
## 1. ARQUITECTURA POR CAPAS OBLIGATORIA

Cada entidad debe seguir ESTRICTAMENTE esta estructura:src/ ├── controllers/ → Reciben HTTP, validan input, llaman servicios ├── services/ → Lógica de negocio, reglas de dominio ├── repositories/ → Acceso a datos (Supabase client) └── middleware/ → Auth, validaciones, manejo de errores

### Responsabilidades:
- **Controller**: 
  - Extraer datos de `req.body`, `req.params`, `req.query`
  - Validar datos de entrada (tipos, formatos, required)
  - Llamar al service correspondiente
  - Retornar respuesta HTTP con código adecuado
  
- **Service**:
  - Aplicar reglas de negocio
  - Verificar precondiciones
  - Coordinar múltiples operaciones
  - Llamar al repository
  
- **Repository**:
  - Ejecutar queries a Supabase
  - NO contiene lógica de negocio
  - Métodos: `findById`, `findAll`, `create`, `update`, `delete`

---

## 2. ESTÁNDARES DE ENDPOINTS RESTful

### Convenciones de Rutas:
```javascript
// ✅ CORRECTO - Sustantivos en plural
GET    /api/vehiculos
POST   /api/vehiculos
GET    /api/vehiculos/:id
PUT    /api/vehiculos/:id
DELETE /api/vehiculos/:id

// ✅ CORRECTO - Recursos anidados
GET    /api/solicitudes/:solicitudId/cotizaciones
POST   /api/solicitudes/:solicitudId/cotizaciones

// ❌ INCORRECTO - Verbos en la ruta
GET    /api/obtenerVehiculos
POST   /api/crearVehiculoMétodos HTTP por Operación:
Operación	Método	Endpoint	Código Éxito
Create	POST	/recursos	201 Created
Read (lista)	GET	/recursos	200 OK
Read (detalle)	GET	/recursos/:id	200 OK
Update (completo)	PUT	/recursos/:id	200 OK
Update (parcial)	PATCH	/recursos/:id	200 OK
Delete	DELETE	/recursos/:id	204 No Content
________________________________________
3. ESTRUCTURA ESTANDARIZADA DE RESPUESTAS JSON
Respuesta de Éxito:
// Create/Update/Read
{
  "exito": true,
  "datos": {
    "id": "uuid",
    "campo1": "valor1",
    "campo2": "valor2"
  },
  "mensaje": "Operación realizada correctamente"
}

// Read (lista con paginación)
{
  "exito": true,
  "datos": [ /* array de objetos */ ],
  "paginacion": {
    "paginaActual": 1,
    "totalPaginas": 10,
    "totalRegistros": 95,
    "limite": 10
  }
}
Respuesta de Error:
// Error de validación (400/422)
{
  "exito": false,
  "errores": [
    { "campo": "precio", "mensaje": "El precio debe ser mayor a 0" },
    { "campo": "email", "mensaje": "Formato de email inválido" }
  ],
  "mensaje": "Datos de entrada inválidos"
}

// Error de negocio (403/404/409)
{
  "exito": false,
  "errores": [],
  "mensaje": "No tiene permisos para modificar esta solicitud"
}

// Error del servidor (500)
{
  "exito": false,
  "errores": [],
  "mensaje": "Error interno del servidor"
}
4. VALIDACIONES OBLIGATORIAS
Tipos de Validación por Campo:
// Ejemplo: Validación para crear solicitud de repuesto
const validarSolicitud = (data) => {
  const errores = [];
  
  // 1. Obligatoriedad (Required)
  if (!data.pieza_nombre || data.pieza_nombre.trim() === '') {
    errores.push({ campo: 'pieza_nombre', mensaje: 'El nombre de la pieza es obligatorio' });
  }
  
  // 2. Tipo de dato
  if (data.precio && typeof data.precio !== 'number') {
    errores.push({ campo: 'precio', mensaje: 'El precio debe ser numérico' });
  }
  
  // 3. Longitud
  if (data.descripcion && data.descripcion.length > 500) {
    errores.push({ campo: 'descripcion', mensaje: 'La descripción no puede exceder 500 caracteres' });
  }
  
  // 4. Rango
  if (data.anio && (data.anio < 1900 || data.anio > new Date().getFullYear() + 1)) {
    errores.push({ campo: 'anio', mensaje: 'Año inválido' });
  }
  
  // 5. Formato (Email, URL, etc.)
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (data.email && !emailRegex.test(data.email)) {
    errores.push({ campo: 'email', mensaje: 'Formato de email inválido' });
  }
  
  // 6. Valores permitidos (Enums)
  const estadosValidos = ['en_proceso', 'completado', 'expirado'];
  if (data.estado && !estadosValidos.includes(data.estado)) {
    errores.push({ campo: 'estado', mensaje: 'Estado no válido' });
  }
  
  return errores;
};Validación en Controller:
// controllers/solicitudController.js
exports.crearSolicitud = async (req, res) => {
  try {
    // Paso 1: Validar datos de entrada
    const errores = validarSolicitud(req.body);
    if (errores.length > 0) {
      return res.status(422).json({
        exito: false,
        errores: errores,
        mensaje: 'Datos de entrada inválidos'
      });
    }
    
    // Paso 2: Agregar datos del usuario autenticado
    const solicitudData = {
      ...req.body,
      cliente_id: req.user.id // Viene del middleware de auth
    };
    
    // Paso 3: Llamar al service
    const solicitud = await solicitudService.crearSolicitud(solicitudData);
    
    // Paso 4: Retornar respuesta estandarizada
    return res.status(201).json({
      exito: true,
      datos: solicitud,
      mensaje: 'Solicitud creada correctamente'
    });
    
  } catch (error) {
    console.error('Error en crearSolicitud:', error);
    return res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error interno del servidor'
    });
  }
};
5. CÓDIGOS DE ESTADO HTTP - CUÁNDO USAR CADA UNO
Código	Significado	Cuándo usar en RepuestosYa
200 OK	Éxito	GET exitoso, PUT/PATCH exitoso
201 Created	Recurso creado	POST exitoso (crear vehículo, solicitud, cotización)
204 No Content	Éxito sin cuerpo	DELETE exitoso
400 Bad Request	Solicitud malformada	JSON inválido, tipo de dato incorrecto
401 Unauthorized	No autenticado	Token ausente o inválido
403 Forbidden	No autorizado	Cliente intenta ver/editar solicitud de otro cliente
404 Not Found	Recurso no existe	ID de vehículo/solicitud no encontrado
409 Conflict	Conflicto	Email ya registrado, VIN duplicado
422 Unprocessable Entity	Datos inválidos	Validación de campos falló (precio negativo, fecha inválida)
500 Internal Server Error	Error del servidor	Error inesperado en el código
________________________________________
6. REGLAS DE NEGOCIO ESPECÍFICAS - REPUESTOSYA
Implementar en la capa de SERVICE:
javascript
// services/cotizacionService.js

exports.crearCotizacion = async (cotizacionData) => {
  // Regla 1: Solo almacenes pueden cotizar
  const almacen = await almacenRepository.findById(cotizacionData.almacen_id);
  if (!almacen) {
    throw new Error('Almacén no encontrado');
  }
  
  // Regla 2: La solicitud debe estar en estado 'en_proceso'
  const solicitud = await solicitudRepository.findById(cotizacionData.solicitud_id);
  if (solicitud.estado !== 'en_proceso') {
    throw new Error('Solo se puede cotizar solicitudes activas');
  }
  
  // Regla 3: El almacén no puede cotizar dos veces la misma solicitud
  const cotizacionExistente = await cotizacionRepository.findBySolicitudYAlmacen(
    cotizacionData.solicitud_id,
    cotizacionData.almacen_id
  );
  if (cotizacionExistente) {
    throw new Error('Ya existe una cotización para esta solicitud');
  }
  
  // Regla 4: Precio debe ser positivo (validación de negocio)
  if (cotizacionData.precio_venta <= 0) {
    throw new Error('El precio debe ser mayor a 0');
  }
  
  // Regla 5: Calcular comisión automáticamente (5%)
  cotizacionData.comision_plataforma = cotizacionData.precio_venta * 0.05;
  
  // Crear cotización
  return await cotizacionRepository.create(cotizacionData);
};

exports.actualizarEstadoCotizacion = async (cotizacionId, nuevoEstado, usuarioId) => {
  const cotizacion = await cotizacionRepository.findById(cotizacionId);
  
  // Regla 6: Solo el cliente dueño puede aceptar/rechazar
  const solicitud = await solicitudRepository.findById(cotizacion.solicitud_id);
  if (solicitud.cliente_id !== usuarioId) {
    throw new Error('Solo el cliente propietario puede aceptar o rechazar cotizaciones');
  }
  
  // Regla 7: Al aceptar una cotización, cambiar estado de solicitud a 'completado'
  if (nuevoEstado === 'aceptada') {
    await solicitudRepository.update(solicitud.id, { estado: 'completado' });
  }
  
  return await cotizacionRepository.update(cotizacionId, { estado: nuevoEstado });
};
7. MANEJO DE ERRORES CENTRALIZADO
Middleware de Error Handling:
// middleware/errorHandler.js

exports.errorHandler = (err, req, res, next) => {
  console.error('Error:', err);
  
  // Error de validación (422)
  if (err.name === 'ValidationError') {
    return res.status(422).json({
      exito: false,
      errores: err.details || [],
      mensaje: 'Datos inválidos'
    });
  }
  
  // Error de autenticación (401)
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({
      exito: false,
      errores: [],
      mensaje: 'No autenticado'
    });
  }
  
  // Error de autorización (403)
  if (err.name === 'ForbiddenError') {
    return res.status(403).json({
      exito: false,
      errores: [],
      mensaje: err.message || 'No tiene permisos para realizar esta acción'
    });
  }
  
  // Error de recurso no encontrado (404)
  if (err.name === 'NotFoundError') {
    return res.status(404).json({
      exito: false,
      errores: [],
      mensaje: err.message || 'Recurso no encontrado'
    });
  }
  
  // Error de conflicto (409)
  if (err.name === 'ConflictError') {
    return res.status(409).json({
      exito: false,
      errores: [],
      mensaje: err.message || 'Conflicto en la operación'
    });
  }
  
  // Error genérico del servidor (500)
  return res.status(500).json({
    exito: false,
    errores: [],
    mensaje: 'Error interno del servidor'
  });
};
8. SEGURIDAD BÁSICA EN CRUD
Verificación de Propiedad:
// services/vehiculoService.js

exports.actualizarVehiculo = async (vehiculoId, datosActualizacion, usuarioId) => {
  // Verificar que el vehículo existe
  const vehiculo = await vehiculoRepository.findById(vehiculoId);
  if (!vehiculo) {
    const error = new Error('Vehículo no encontrado');
    error.name = 'NotFoundError';
    throw error;
  }
  
  // REGLA DE SEGURIDAD: Solo el propietario puede modificar
  if (vehiculo.cliente_id !== usuarioId) {
    const error = new Error('No tiene permisos para modificar este vehículo');
    error.name = 'ForbiddenError';
    throw error;
  }
  
  // Proceder con la actualización
  return await vehiculoRepository.update(vehiculoId, datosActualizacion);
};

exports.eliminarVehiculo = async (vehiculoId, usuarioId) => {
  const vehiculo = await vehiculoRepository.findById(vehiculoId);
  
  // Verificar propiedad
  if (!vehiculo || vehiculo.cliente_id !== usuarioId) {
    const error = new Error('No tiene permisos para eliminar este vehículo');
    error.name = 'ForbiddenError';
    throw error;
  }
  
  // Verificar si tiene solicitudes asociadas (integridad referencial)
  const solicitudesAsociadas = await solicitudRepository.findByVehiculo(vehiculoId);
  if (solicitudesAsociadas.length > 0) {
    const error = new Error('No se puede eliminar un vehículo con solicitudes asociadas');
    error.name = 'ConflictError';
    throw error;
  }
  
  return await vehiculoRepository.delete(vehiculoId);
};
9. EJEMPLO COMPLETO - CRUD DE VEHÍCULOS
Repository:
// repositories/vehiculoRepository.js
const { supabase } = require('../services/supabase');

exports.findAll = async (clienteId, { pagina = 1, limite = 10 }) => {
  const offset = (pagina - 1) * limite;
  
  const { data, count, error } = await supabase
    .from('vehiculos_cliente')
    .select(`
      *,
      modelos_vehiculo (
        id,
        nombre,
        marcas_vehiculo (id, nombre)
      )
    `, { count: 'exact' })
    .eq('cliente_id', clienteId)
    .range(offset, offset + limite - 1);
  
  if (error) throw error;
  
  return {
    data,
    paginacion: {
      paginaActual: parseInt(pagina),
      totalRegistros: count,
      totalPaginas: Math.ceil(count / limite),
      limite: parseInt(limite)
    }
  };
};

exports.findById = async (id) => {
  const { data, error } = await supabase
    .from('vehiculos_cliente')
    .select(`
      *,
      modelos_vehiculo (
        id,
        nombre,
        marcas_vehiculo (id, nombre)
      )
    `)
    .eq('id', id)
    .single();
  
  if (error) throw error;
  return data;
};

exports.create = async (data) => {
  const { data: nuevoVehiculo, error } = await supabase
    .from('vehiculos_cliente')
    .insert([data])
    .select()
    .single();
  
  if (error) throw error;
  return nuevoVehiculo;
};

exports.update = async (id, data) => {
  const { data: vehiculoActualizado, error } = await supabase
    .from('vehiculos_cliente')
    .update(data)
    .eq('id', id)
    .select()
    .single();
  
  if (error) throw error;
  return vehiculoActualizado;
};

exports.delete = async (id) => {
  const { error } = await supabase
    .from('vehiculos_cliente')
    .delete()
    .eq('id', id);
  
  if (error) throw error;
};
Service:
// services/vehiculoService.js
const vehiculoRepository = require('../repositories/vehiculoRepository');

exports.obtenerVehiculos = async (clienteId, opciones) => {
  return await vehiculoRepository.findAll(clienteId, opciones);
};

exports.obtenerVehiculoPorId = async (vehiculoId, clienteId) => {
  const vehiculo = await vehiculoRepository.findById(vehiculoId);
  
  if (!vehiculo) {
    const error = new Error('Vehículo no encontrado');
    error.name = 'NotFoundError';
    throw error;
  }
  
  // Verificar que pertenece al cliente
  if (vehiculo.cliente_id !== clienteId) {
    const error = new Error('No tiene permisos para ver este vehículo');
    error.name = 'ForbiddenError';
    throw error;
  }
  
  return vehiculo;
};

exports.crearVehiculo = async (vehiculoData) => {
  // Validar que el modelo existe
  const { data: modelo } = await supabase
    .from('modelos_vehiculo')
    .select('id')
    .eq('id', vehiculoData.modelo_id)
    .single();
  
  if (!modelo) {
    const error = new Error('Modelo de vehículo no válido');
    error.name = 'ValidationError';
    throw error;
  }
  
  // Validar VIN único si se proporciona
  if (vehiculoData.vin) {
    const { data: vinExistente } = await supabase
      .from('vehiculos_cliente')
      .select('id')
      .eq('vin', vehiculoData.vin)
      .eq('cliente_id', vehiculoData.cliente_id)
      .single();
    
    if (vinExistente) {
      const error = new Error('Ya existe un vehículo con este VIN');
      error.name = 'ConflictError';
      throw error;
    }
  }
  
  // Validar año
  const anioActual = new Date().getFullYear();
  if (vehiculoData.anio < 1900 || vehiculoData.anio > anioActual + 1) {
    const error = new Error('Año del vehículo inválido');
    error.name = 'ValidationError';
    throw error;
  }
  
  return await vehiculoRepository.create(vehiculoData);
};

exports.actualizarVehiculo = async (vehiculoId, datosActualizacion, clienteId) => {
  const vehiculo = await vehiculoRepository.findById(vehiculoId);
  
  if (!vehiculo) {
    const error = new Error('Vehículo no encontrado');
    error.name = 'NotFoundError';
    throw error;
  }
  
  if (vehiculo.cliente_id !== clienteId) {
    const error = new Error('No tiene permisos para modificar este vehículo');
    error.name = 'ForbiddenError';
    throw error;
  }
  
  // No permitir modificar el cliente_id
  delete datosActualizacion.cliente_id;
  
  return await vehiculoRepository.update(vehiculoId, datosActualizacion);
};

exports.eliminarVehiculo = async (vehiculoId, clienteId) => {
  const vehiculo = await vehiculoRepository.findById(vehiculoId);
  
  if (!vehiculo) {
    const error = new Error('Vehículo no encontrado');
    error.name = 'NotFoundError';
    throw error;
  }
  
  if (vehiculo.cliente_id !== clienteId) {
    const error = new Error('No tiene permisos para eliminar este vehículo');
    error.name = 'ForbiddenError';
    throw error;
  }
  
  return await vehiculoRepository.delete(vehiculoId);
};

Controller:
// controllers/vehiculoController.js
const vehiculoService = require('../services/vehiculoService');

exports.listarVehiculos = async (req, res) => {
  try {
    const clienteId = req.user.id;
    const { pagina = 1, limite = 10 } = req.query;
    
    const resultado = await vehiculoService.obtenerVehiculos(clienteId, {
      pagina: parseInt(pagina),
      limite: parseInt(limite)
    });
    
    return res.status(200).json({
      exito: true,
      datos: resultado.data,
      paginacion: resultado.paginacion
    });
    
  } catch (error) {
    console.error('Error al listar vehículos:', error);
    return res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error al obtener los vehículos'
    });
  }
};

exports.obtenerVehiculo = async (req, res) => {
  try {
    const { id } = req.params;
    const clienteId = req.user.id;
    
    const vehiculo = await vehiculoService.obtenerVehiculoPorId(id, clienteId);
    
    return res.status(200).json({
      exito: true,
      datos: vehiculo
    });
    
  } catch (error) {
    if (error.name === 'NotFoundError' || error.name === 'ForbiddenError') {
      return res.status(404).json({
        exito: false,
        errores: [],
        mensaje: error.message
      });
    }
    
    return res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error al obtener el vehículo'
    });
  }
};

exports.crearVehiculo = async (req, res) => {
  try {
    const { modelo_id, anio, vin } = req.body;
    
    // Validaciones básicas
    const errores = [];
    
    if (!modelo_id) {
      errores.push({ campo: 'modelo_id', mensaje: 'El modelo es obligatorio' });
    }
    
    if (!anio) {
      errores.push({ campo: 'anio', mensaje: 'El año es obligatorio' });
    }
    
    if (errores.length > 0) {
      return res.status(422).json({
        exito: false,
        errores: errores,
        mensaje: 'Datos de entrada inválidos'
      });
    }
    
    const vehiculoData = {
      modelo_id,
      anio: parseInt(anio),
      vin: vin || null,
      cliente_id: req.user.id
    };
    
    const nuevoVehiculo = await vehiculoService.crearVehiculo(vehiculoData);
    
    return res.status(201).json({
      exito: true,
      datos: nuevoVehiculo,
      mensaje: 'Vehículo registrado correctamente'
    });
    
  } catch (error) {
    if (error.name === 'ValidationError' || error.name === 'ConflictError') {
      return res.status(422).json({
        exito: false,
        errores: [],
        mensaje: error.message
      });
    }
    
    console.error('Error al crear vehículo:', error);
    return res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error al registrar el vehículo'
    });
  }
};

exports.actualizarVehiculo = async (req, res) => {
  try {
    const { id } = req.params;
    const { modelo_id, anio, vin } = req.body;
    const clienteId = req.user.id;
    
    const datosActualizacion = {};
    if (modelo_id) datosActualizacion.modelo_id = modelo_id;
    if (anio) datosActualizacion.anio = parseInt(anio);
    if (vin !== undefined) datosActualizacion.vin = vin;
    
    const vehiculoActualizado = await vehiculoService.actualizarVehiculo(
      id,
      datosActualizacion,
      clienteId
    );
    
    return res.status(200).json({
      exito: true,
      datos: vehiculoActualizado,
      mensaje: 'Vehículo actualizado correctamente'
    });
    
  } catch (error) {
    if (error.name === 'NotFoundError' || error.name === 'ForbiddenError') {
      return res.status(404).json({
        exito: false,
        errores: [],
        mensaje: error.message
      });
    }
    
    return res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error al actualizar el vehículo'
    });
  }
};

exports.eliminarVehiculo = async (req, res) => {
  try {
    const { id } = req.params;
    const clienteId = req.user.id;
    
    await vehiculoService.eliminarVehiculo(id, clienteId);
    
    return res.status(204).send();
    
  } catch (error) {
    if (error.name === 'NotFoundError' || error.name === 'ForbiddenError') {
      return res.status(404).json({
        exito: false,
        errores: [],
        mensaje: error.message
      });
    }
    
    if (error.name === 'ConflictError') {
      return res.status(409).json({
        exito: false,
        errores: [],
        mensaje: error.message
      });
    }
    
    return res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error al eliminar el vehículo'
    });
  }
};
10. CHECKLIST DE IMPLEMENTACIÓN POR ENDPOINT
Antes de dar por terminado un endpoint, verificar:
•	Ruta sigue convención RESTful (sustantivos en plural, sin verbos)
•	Método HTTP correcto (POST/GET/PUT/PATCH/DELETE)
•	Validación de datos de entrada (required, tipo, formato, longitud, rango)
•	Verificación de autenticación (middleware auth)
•	Verificación de autorización (propiedad del recurso)
•	Manejo de errores (try-catch con códigos HTTP adecuados)
•	Respuesta JSON estandarizada (exito, datos/errores, mensaje)
•	Código de estado correcto (200/201/204/400/401/403/404/422/500)
•	Reglas de negocio aplicadas (en service, no en controller)
•	No exponer datos sensibles (contraseñas, tokens internos)
•	Logs de errores (console.error en catch)
________________________________________
11. PRUEBAS CON POSTMAN/INSOMNIA
Para cada endpoint, probar:
Caso Exitoso:
Método: POST
URL: http://localhost:3000/api/vehiculos
Headers: 
  Content-Type: application/json
  Authorization: Bearer <token>
Body:
{
  "modelo_id": 1,
  "anio": 2020,
  "vin": "1HGBH41JXMN109186"
}

Esperado: 201 Created
{
  "exito": true,
  "datos": { ... },
  "mensaje": "Vehículo registrado correctamente"
}

Casos de Error:
1.	422 - Validación: Datos incompletos o inválidos
2.	401 - No autenticado: Sin token o token inválido
3.	403 - No autorizado: Intentar modificar recurso de otro usuario
4.	404 - No encontrado: ID inexistente
5.	409 - Conflicto: VIN duplicado
6.	500 - Server error: Simular error en BD
________________________________________
12. PRIORIDADES DE IMPLEMENTACIÓN - REPUESTOSYA
Fase 1 (Semana 6):
1.	✅ Auth (login/register) - Controlador + Service
2.	✅ Vehículos CRUD completo
3.	✅ Direcciones CRUD completo
4.	✅ Perfiles (GET/PUT)
Fase 2 (Semana 7):
5.	Solicitudes CRUD
6.	Cotizaciones CRUD
7.	Almacenes CRUD
Fase 3 (Optimización):
8.	Paginación en todos los listados
9.	Filtros avanzados
10.	Búsqueda geográfica (calcular_distancia)

