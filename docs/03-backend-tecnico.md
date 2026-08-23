# Detalle Técnico del Backend - RepuestosYa

## 1. Arquitectura General del Backend

El backend de RepuestosYa está implementado como una **API REST** utilizando **Express.js** sobre **Node.js**, con **Supabase** como servicio de base de datos y autenticación.

### 1.1 Stack Tecnológico

- **Runtime**: Node.js 18.17+
- **Framework**: Express.js 4.18.2
- **Database**: PostgreSQL (vía Supabase)
- **Authentication**: JWT + Supabase Auth
- **Cache**: Redis (opcional, vía BullMQ)
- **File Upload**: Multer
- **Security**: Helmet.js, CORS, Rate Limiting

### 1.2 Estructura de Directorios

```
backend/
├── src/
│   ├── controllers/            # Controladores HTTP
│   │   ├── authController.js
│   │   ├── vehiculoController.js
│   │   ├── solicitudController.js
│   │   ├── cotizacionController.js
│   │   ├── adminController.js
│   │   ├── almacenController.js
│   │   ├── marcaController.js
│   │   ├── modeloController.js
│   │   ├── ordenController.js
│   │   ├── direccionController.js
│   │   ├── profileController.js
│   │   └── uploadController.js
│   ├── middleware/             # Middleware
│   │   ├── auth.js             # Autenticación JWT
│   │   └── timing.js           # Medición de tiempo
│   ├── routes/                 # Definición de rutas
│   │   └── index.js            # Router principal
│   ├── services/               # Servicios de negocio
│   │   ├── supabase.js         # Cliente Supabase
│   │   ├── cache.js            # Caché Redis
│   │   ├── ordenService.js
│   │   └── cotizacionService.js
│   ├── queues/                 # Colas de trabajos
│   │   └── notificaciones.queue.js
│   └── workers/                # Background workers
│       └── notificaciones.worker.js
├── migrations/                 # Migraciones SQL
│   ├── add_ordenes_compra_and_cotizacion_workflow.sql
│   ├── add_warehouse_fields.sql
│   ├── disable_email_verification.sql
│   ├── fix_profiles_foreign_key.sql
│   ├── fix_profiles_rls.sql
│   ├── fix_solicitudes_repuesto_rls.sql
│   ├── make_trigger_idempotent.sql
│   └── update_direcciones_entrega_structure.sql
├── scripts/                    # Scripts de utilidad
│   ├── apply_rls_fix.js
│   └── apply_rls_simple.js
├── server.js                   # Punto de entrada
├── package.json                # Dependencias
└── .env                        # Variables de entorno
```

## 2. Configuración del Servidor

### 2.1 Punto de Entrada (server.js)

```javascript
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const routes = require('./src/routes');
const timingMiddleware = require('./src/middleware/timing');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware de logging
app.use(morgan('dev'));

// Security middleware
app.use(helmet());

// CORS configuration
app.use(cors({
  origin: ['http://localhost:3002', 'http://127.0.0.1:3002', 'http://192.168.100.2:3002', 
           'http://localhost:3000', 'http://127.0.0.1:3000', 'http://192.168.100.2:3000'],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Body parser
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Custom logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Timing middleware
app.use(timingMiddleware);

// Routes
app.use('/api', routes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`API Base URL: http://localhost:${PORT}/api`);
});
```

### 2.2 Variables de Entorno

```env
# Configuración Supabase
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Configuración JWT
JWT_SECRET=your_jwt_secret
JWT_EXPIRES_IN=24h

# Configuración Servidor
PORT=3000
NODE_ENV=development

# Configuración Redis (opcional)
REDIS_HOST=localhost
REDIS_PORT=6379
```

## 3. Sistema de Rutas

### 3.1 Estructura de Rutas

Las rutas están organizadas por recurso funcional y protegidas por middleware de autenticación y autorización:

```javascript
// src/routes/index.js
const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');

// Importación de controladores
const authController = require('../controllers/authController');
const vehiculoController = require('../controllers/vehiculoController');
const catalogoController = require('../controllers/catalogoController');
const solicitudController = require('../controllers/solicitudController');
const cotizacionController = require('../controllers/cotizacionController');
const adminController = require('../controllers/adminController');

// Rutas públicas (autenticación)
router.post('/auth/register', authController.register);
router.post('/auth/login', authController.login);

// Rutas protegidas (requieren autenticación)
router.get('/vehicles', auth, vehiculoController.getVehiculos);
router.post('/vehicles', auth, vehiculoController.createVehiculo);

// Catálogo de repuestos
router.get('/catalog/part-categories', auth, catalogoController.getCategorias);
router.get('/catalog/parts', auth, catalogoController.getRepuestos);

// Rutas por rol (requieren rol específico)
router.get('/requests/active', auth, requireRole('almacen'), solicitudController.getSolicitudesActivas);
router.post('/quotations', auth, requireRole('almacen'), cotizacionController.createCotizacion);

// Rutas de administrador
router.get('/admin/metrics', auth, requireRole('admin'), adminController.getDashboardMetricsController);

module.exports = router;
```

### 3.2 Categorías de Rutas

#### **Rutas Públicas**
- `POST /api/auth/register` - Registro de usuarios
- `POST /api/auth/login` - Inicio de sesión
- `GET /api/brands` - Catálogo de marcas
- `GET /api/models` - Catálogo de modelos

#### **Rutas Protegidas (Autenticación)**
- `GET /api/vehicles` - Obtener vehículos del usuario
- `POST /api/vehicles` - Crear vehículo
- `GET /api/requests` - Obtener solicitudes del cliente
- `POST /api/requests` - Crear solicitud de repuesto

#### **Rutas por Rol**
- `GET /api/requests/active` - Solicitudes activas (solo almacenes)
- `POST /api/quotations` - Crear cotización (solo almacenes)
- `GET /api/admin/metrics` - Métricas del dashboard (solo admin)

## 4. Sistema de Autenticación y Autorización

### 4.1 Middleware de Autenticación

```javascript
// src/middleware/auth.js
const jwt = require('jsonwebtoken');

const auth = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    req.user = {
      id: decoded.id,
      email: decoded.email,
      rol: decoded.rol
    };
    
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    if (!roles.includes(req.user.rol)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    
    next();
  };
};

module.exports = { auth, requireRole };
```

### 4.2 Flujo de Autenticación

1. **Registro**: Usuario se registra en Supabase Auth
2. **Login**: Credenciales validadas, JWT generado
3. **Protected Request**: Token enviado en header `Authorization: Bearer <token>`
4. **Middleware**: Token validado, usuario extraído
5. **Controller**: Usuario disponible en `req.user`

### 4.3 Controlador de Autenticación

```javascript
// src/controllers/authController.js
const supabase = require('../services/supabase');
const jwt = require('jsonwebtoken');

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // 1. Autenticar con Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (authError) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    // 2. Obtener perfil de usuario
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, email, nombre_completo, rol')
      .eq('id', authData.user.id)
      .single();

    if (profileError || !profile) {
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    // 3. Generar JWT
    const token = jwt.sign(
      {
        id: profile.id,
        email: profile.email,
        rol: profile.rol
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    res.json({
      success: true,
      token,
      user: {
        id: profile.id,
        email: profile.email,
        nombre_completo: profile.nombre_completo,
        rol: profile.rol
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};
```

## 5. Servicios de Negocio

### 5.1 Servicio Supabase

```javascript
// src/services/supabase.js
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    },
    global: {
      headers: {
        'Connection': 'keep-alive'
      }
    }
  }
);

module.exports = supabase;
```

### 5.2 Servicio de Caché

```javascript
// src/services/cache.js
const Redis = require('ioredis');

let redisClient;

if (process.env.REDIS_HOST) {
  redisClient = new Redis({
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT || 6379,
  });
}

const getOrSet = async (key, ttl, callback) => {
  if (!redisClient) {
    // Si Redis no está configurado, ejecutar callback directamente
    const data = await callback();
    return { data, fromCache: false };
  }

  try {
    const cachedData = await redisClient.get(key);
    if (cachedData) {
      return { data: JSON.parse(cachedData), fromCache: true };
    }

    const data = await callback();
    await redisClient.setex(key, ttl, JSON.stringify(data));
    return { data, fromCache: false };
  } catch (error) {
    console.error('Cache error:', error);
    const data = await callback();
    return { data, fromCache: false };
  }
};

const invalidatePattern = async (pattern) => {
  if (!redisClient) return;

  try {
    const keys = await redisClient.keys(pattern);
    if (keys.length > 0) {
      await redisClient.del(...keys);
    }
  } catch (error) {
    console.error('Cache invalidation error:', error);
  }
};

module.exports = { getOrSet, invalidatePattern };
```

### 5.3 Servicio de Cotizaciones

```javascript
// src/services/cotizacionService.js
const supabase = require('./supabase');

class CotizacionService {
  static async calcularComision(precioVenta) {
    return precioVenta * 0.05; // 5% de comisión
  }

  static async verificarDisponibilidad(almacenId, piezaNombre) {
    const { data, error } = await supabase
      .from('inventario')
      .select('*')
      .eq('almacen_id', almacenId)
      .eq('pieza_nombre', piezaNombre)
      .gt('cantidad', 0)
      .single();

    return { disponible: !!data, error };
  }

  static async procesarCotizacion(cotizacionData) {
    const comision = await this.calcularComision(cotizacionData.precio_venta);
    
    const { data, error } = await supabase
      .from('cotizaciones')
      .insert({
        ...cotizacionData,
        comision_plataforma: comision
      })
      .select()
      .single();

    return { data, error };
  }
}

module.exports = CotizacionService;
```

## 6. Controladores Principales

### 6.1 Controlador de Solicitudes

```javascript
// src/controllers/solicitudController.js
const supabase = require('../services/supabase');
const { getOrSet, invalidatePattern } = require('../services/cache');

const getSolicitudesActivas = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;

    // Obtener ID del almacén del usuario
    const { data: almacen } = await supabase
      .from('almacenes')
      .select('id')
      .eq('encargado_id', req.user.id)
      .single();

    // Cache key específica por almacén
    const cacheKey = `solicitudes:activas:almacen:${almacen.id}:page:${page}`;

    const { data: solicitudes, fromCache } = await getOrSet(
      cacheKey,
      10, // 10 segundos TTL
      async () => {
        // Obtener solicitudes activas con eager loading
        const { data, error } = await supabase
          .from('solicitudes_repuesto')
          .select(`*, profiles(nombre_completo, email),
            vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*))),
            cotizaciones(count)`)
          .eq('estado', 'en_proceso')
          .order('created_at', { ascending: false });

        if (error) throw new Error(error.message);

        // Filtrar solicitudes que ya tienen cotización de este almacén
        const solicitudesSinCotizar = await Promise.all(
          (data || []).map(async (solicitud) => {
            const { data: cotizacionesExistentes } = await supabase
              .from('cotizaciones')
              .select('id')
              .eq('solicitud_id', solicitud.id)
              .eq('almacen_id', almacen.id);
            
            const tieneCotizacion = cotizacionesExistentes && cotizacionesExistentes.length > 0;
            return tieneCotizacion ? null : solicitud;
          })
        );

        return solicitudesSinCotizar.filter(s => s !== null);
      }
    );

    res.setHeader('X-Cache', fromCache ? 'HIT' : 'MISS');
    res.json(solicitudes);
  } catch (error) {
    console.error('Get solicitudes activas error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const createSolicitud = async (req, res) => {
  try {
    const { vehiculo_id, pieza_nombre, descripcion, foto_url, vin_busqueda, direccion_entrega_id, es_urgente } = req.body;

    if (!pieza_nombre) {
      return res.status(400).json({ error: 'pieza_nombre is required' });
    }

    const data = {
      cliente_id: req.user.id,
      pieza_nombre,
      estado: 'en_proceso'
    };

    // Campos opcionales
    if (vehiculo_id) data.vehiculo_id = vehiculo_id;
    if (descripcion) data.descripcion = descripcion;
    if (foto_url) data.foto_url = foto_url;
    if (vin_busqueda) data.vin_busqueda = vin_busqueda;
    if (direccion_entrega_id) data.direccion_entrega_id = direccion_entrega_id;
    if (es_urgente) data.es_urgente = es_urgente;

    const { data: solicitud, error } = await supabase
      .from('solicitudes_repuesto')
      .insert(data)
      .select('*, vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))')
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Invalidar caché de solicitudes activas
    await invalidatePattern('solicitudes:activas:*');

    res.status(201).json(solicitud);
  } catch (error) {
    console.error('Create solicitud error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { getSolicitudesActivas, createSolicitud };
```

### 6.2 Controlador de Vehículos

```javascript
// src/controllers/vehiculoController.js
const supabase = require('../services/supabase');

const createVehiculo = async (req, res) => {
  try {
    const { marcaId, modeloId, vin, anio, patente } = req.body;
    const clienteId = req.user.id;

    // Validación de datos
    if (!marcaId || !modeloId) {
      return res.status(400).json({
        success: false,
        errors: [
          { campo: 'marcaId', mensaje: 'marcaId es requerido' },
          { campo: 'modeloId', mensaje: 'modeloId es requerido' }
        ],
        mensaje: 'Datos de entrada inválidos'
      });
    }

    // Verificar que la marca existe
    const { data: marca, error: marcaError } = await supabase
      .from('marcas_vehiculo')
      .select('*')
      .eq('id', marcaId)
      .single();

    if (marcaError || !marca) {
      return res.status(404).json({
        success: false,
        mensaje: 'Marca no encontrada'
      });
    }

    // Verificar que el modelo existe y pertenece a la marca
    const { data: modelo, error: modeloError } = await supabase
      .from('modelos_vehiculo')
      .select('*')
      .eq('id', modeloId)
      .eq('marca_id', marcaId)
      .single();

    if (modeloError || !modelo) {
      return res.status(404).json({
        success: false,
        mensaje: 'Modelo no encontrado o no pertenece a la marca seleccionada'
      });
    }

    // Inserción con relaciones
    const { data: vehiculo, error } = await supabase
      .from('vehiculos_cliente')
      .insert({
        cliente_id: clienteId,
        modelo_id: modeloId,
        vin,
        anio: parseInt(anio),
        patente
      })
      .select(`
        *,
        modelos_vehiculo (
          id,
          nombre,
          marca_id,
          marcas_vehiculo (
            id,
            nombre
          )
        )
      `)
      .single();

    if (error) {
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }

    res.status(201).json({
      success: true,
      data: vehiculo,
      message: 'Vehículo creado correctamente'
    });

  } catch (error) {
    console.error('Error creating vehicle:', error);
    res.status(500).json({
      success: false,
      error: 'Error interno del servidor'
    });
  }
};

module.exports = { createVehiculo };
```

## 7. Sistema de Migraciones

### 7.1 Estructura de Migraciones

Las migraciones SQL se utilizan para modificar el esquema de la base de datos de manera controlada:

```sql
-- migrations/add_warehouse_fields.sql
-- Añadir campos adicionales a la tabla almacenes

ALTER TABLE public.almacenes 
ADD COLUMN IF NOT EXISTS rating NUMERIC(3, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS total_reviews INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS horario_apertura TEXT,
ADD COLUMN IF NOT EXISTS horario_cierre TEXT;

-- Crear índices para mejorar rendimiento
CREATE INDEX IF NOT EXISTS idx_almacenes_rating ON public.almacenes(rating DESC);
CREATE INDEX IF NOT EXISTS idx_almacenes_estado ON public.almacenes(estado_abierto, verificado);
```

### 7.2 Ejecución de Migraciones

```bash
# Aplicar migración a través de Supabase Dashboard
# o usando Supabase CLI
supabase db push
```

## 8. Sistema de Colas y Workers

### 8.1 Cola de Notificaciones

```javascript
// src/queues/notificaciones.queue.js
const { Queue } = require('bullmq');
const redisConfig = {
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
};

const notificationQueue = new Queue('notifications', {
  connection: redisConfig,
});

module.exports = notificationQueue;
```

### 8.2 Worker de Notificaciones

```javascript
// src/workers/notificaciones.worker.js
const { Worker } = require('bullmq');
const redisConfig = {
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
};

const notificationWorker = new Worker(
  'notifications',
  async (job) => {
    const { type, recipient, message } = job.data;
    
    // Lógica de envío de notificaciones
    console.log(`Sending ${type} notification to ${recipient}: ${message}`);
    
    // Integración con servicio de notificaciones
    // (email, SMS, push notifications, etc.)
    
    return { success: true };
  },
  {
    connection: redisConfig,
  }
);

notificationWorker.on('completed', (job) => {
  console.log(`Notification ${job.id} completed`);
});

notificationWorker.on('failed', (job, err) => {
  console.error(`Notification ${job.id} failed:`, err.message);
});
```

## 9. Estrategias de Carga de Datos

### 9.1 Eager Loading vs Lazy Loading

```javascript
// EAGER loading: Datos siempre necesarios
const solicitudes = await supabase
  .from('solicitudes_repuesto')
  .select(`
    *,
    vehiculos_cliente(
      *,
      modelos_vehiculo(
        *,
        marcas_vehiculo(*)
      )
    )
  `);

// LAZY loading: Datos bajo demanda
const solicitudes = await supabase
  .from('solicitudes_repuesto')
  .select('*, cotizaciones(count)'); // Solo conteo, no datos completos
```

### 9.2 Estrategia de Paginación

```javascript
const page = parseInt(req.query.page) || 1;
const limit = parseInt(req.query.limit) || 10;
const from = (page - 1) * limit;
const to = from + limit - 1;

const { data } = await supabase
  .from('solicitudes_repuesto')
  .select('*')
  .range(from, to)
  .order('created_at', { ascending: false });
```

## 10. Manejo de Errores

### 10.1 Tipos de Errores

```javascript
// Errores de validación (400)
if (!pieza_nombre) {
  return res.status(400).json({ 
    success: false,
    errors: [
      { campo: 'pieza_nombre', mensaje: 'pieza_nombre es requerido' }
    ],
    mensaje: 'Datos de entrada inválidos'
  });
}

// Errores de autenticación (401)
if (!token) {
  return res.status(401).json({ error: 'No token provided' });
}

// Errores de autorización (403)
if (!roles.includes(req.user.rol)) {
  return res.status(403).json({ error: 'Insufficient permissions' });
}

// Errores de no encontrado (404)
if (!profile) {
  return res.status(404).json({ error: 'Perfil no encontrado' });
}

// Errores del servidor (500)
res.status(500).json({ error: 'Error interno del servidor' });
```

### 10.2 Logging de Errores

```javascript
// Logging detallado en desarrollo
if (process.env.NODE_ENV === 'development') {
  console.error('Error details:', JSON.stringify(error, null, 2));
}

// Logging estructurado en producción
console.error(`[${new Date().toISOString()}] ERROR: ${error.message}`);
console.error(`Stack: ${error.stack}`);
```

## 11. Seguridad

### 11.1 Headers de Seguridad

```javascript
app.use(helmet());
// Agrega headers como:
// X-Content-Type-Options: nosniff
// X-Frame-Options: DENY
// X-XSS-Protection: 1; mode=block
// Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### 11.2 Rate Limiting

```javascript
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 100, // 100 solicitudes por ventana
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
```

### 11.3 Validación de Inputs

```javascript
// Validación de tipos
if (typeof marcaId !== 'number' || marcaId <= 0) {
  return res.status(400).json({
    success: false,
    errors: [
      { campo: 'marcaId', mensaje: 'marcaId debe ser un número entero positivo' }
    ]
  });
}

// Validación de longitud
if (pieza_nombre.length > 200) {
  return res.status(400).json({
    success: false,
    errors: [
      { campo: 'pieza_nombre', mensaje: 'pieza_nombre no puede exceder 200 caracteres' }
    ]
  });
}
```

## 12. Monitoreo y Performance

### 12.1 Middleware de Timing

```javascript
// src/middleware/timing.js
const timingMiddleware = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.url} - ${duration}ms`);
    
    // Alerta si la respuesta es muy lenta
    if (duration > 1000) {
      console.warn(`Slow request detected: ${req.method} ${req.url} took ${duration}ms`);
    }
  });
  
  next();
};

module.exports = timingMiddleware;
```

### 12.2 Métricas de Performance

- **Response Time**: Tiempo de respuesta de endpoints
- **Cache Hit Rate**: Porcentaje de aciertos de caché
- **Database Query Time**: Tiempo de consultas a base de datos
- **Error Rate**: Tasa de errores por endpoint

## 13. Escalabilidad del Backend

### 13.1 Escalabilidad Horizontal

- **Load Balancing**: Múltiples instancias del servidor Express
- **Session-less Design**: JWT permite escalar sin preocuparse por sesiones
- **Database Connection Pooling**: Supabase maneja conexiones eficientemente

### 13.2 Escalabilidad Vertical

- **Caching**: Redis reduce carga en base de datos
- **Background Workers**: Procesamiento asíncrono de tareas pesadas
- **Database Indexing**: Índices optimizados en consultas frecuentes

## 14. Testing

### 14.1 Estrategia de Testing

```javascript
// tests/controllers/authController.test.js
const request = require('supertest');
const app = require('../server');

describe('Auth Controller', () => {
  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'password123'
        });
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('token');
      expect(response.body.user).toHaveProperty('rol');
    });
  });
});
```

## 15. Despliegue

### 15.1 Entornos de Despliegue

- **Development**: `NODE_ENV=development`
- **Staging**: `NODE_ENV=staging`
- **Production**: `NODE_ENV=production`

### 15.2 Proceso de Despliegue

```bash
# Instalar dependencias
npm install --production

# Variables de entorno configuradas
# Ejecutar servidor
npm start
```

### 15.3 Consideraciones de Producción

- **HTTPS**: Certificado SSL/TLS
- **Environment Variables**: Secrets gestionados de forma segura
- **Database Backups**: Backups automáticos de Supabase
- **Monitoring**: Monitoreo de uptime y performance
- **Logging**: Logs centralizados y analíticos

## 16. Consideraciones para Mantenimiento

### 16.1 Depuración

- **Logging detallado** en desarrollo
- **Error tracking** con herramientas como Sentry
- **Database query logs** para optimización

### 16.2 Actualizaciones

- **Versionado de API** para cambios breaking
- **Migraciones controladas** de base de datos
- **Testing exhaustivo** antes de despliegue

### 16.3 Documentación

- **API Documentation** actualizada ( Swagger/OpenAPI)
- **Changelog** de cambios importantes
- **Comentarios en código** para lógica compleja