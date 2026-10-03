require('dotenv').config();

const isProd = process.env.NODE_ENV === 'production';
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';

// B4: el logging de requests (método, ruta, status, ms) se activa SOLO en
// desarrollo o con LOG_LEVEL=debug. En producción por defecto no se registran
// requests; cuando se activa, Morgan nunca incluye headers, así que
// Authorization, cookies ni tokens no aparecen en los logs.
const requestLoggingEnabled = !isProd || LOG_LEVEL === 'debug';

// En producción se silencia console.* para impedir que controladores y
// servicios existentes filtren emails, IDs, perfiles o errores sensibles.
// El detalle de errores server-side se escribe vía logger
// (src/utils/logger.js), que va directo a stderr y no pasa por console.
if (isProd) {
  console.log = () => {};
  console.warn = () => {};
  console.error = () => {};
}

// Validación de variables obligatorias ANTES de cargar rutas/controladores:
// en producción, si falta alguna, el proceso termina con mensaje claro
// (sin imprimir valores).
require('./src/config/env');

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const logger = require('./src/utils/logger');
const routes = require('./src/routes');
const healthController = require('./src/controllers/healthController');
const timingMiddleware = require('./src/middleware/timing');

const app = express();
const PORT = process.env.PORT || 3000;

// Render (y cualquier proxy HTTPS) termina TLS y reenvía x-forwarded-*.
// Sin esto, express-rate-limit contaría todas las peticiones como si vinieran
// de la IP del proxy y el bloqueo por IP dejaría de funcionar.
app.set('trust proxy', 1);

// HTTPS obligatorio en producción (Render reenvía x-forwarded-proto).
// GET/HEAD se redirigen a https; el resto se rechaza con 403.
if (isProd) {
  app.use((req, res, next) => {
    if (req.headers['x-forwarded-proto'] !== 'https') {
      if (req.method === 'GET' || req.method === 'HEAD') {
        const host = req.headers.host || 'localhost';
        return res.redirect(301, `https://${host}${req.originalUrl}`);
      }
      return res.status(403).json({ error: 'HTTPS required' });
    }
    next();
  });
}

// B4: logging de requests condicional.
if (requestLoggingEnabled) {
  app.use(morgan(isProd ? ':method :url :status :response-time ms' : 'dev'));
}

// Security middleware
app.use(helmet());

// CORS configuration con switch por ambiente.
// En producción la allowlist se lee de ALLOWED_ORIGINS (lista separada por comas);
// en desarrollo se usa la allowlist local (admin panel en 3002, móvil en 3000).
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

// Health check público: se registra ANTES de los limitadores y no requiere token.
app.get('/health', healthController.check);

// Rate limiting por capas. Los endpoints de credenciales/token (login,
// register, refresh) llevan un límite estricto anti fuerza bruta y se
// registran ANTES del límite genérico, porque app.use('/api/', ...) también
// matchea /api/auth/* y, de registrarse primero, contaría esas peticiones
// contra el límite general.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // intentos de credenciales por IP por ventana
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Demasiados intentos. Intenta nuevamente en unos minutos.'
});
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/auth/refresh', authLimiter);

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300, // peticiones por IP por ventana (el upload de imágenes va directo a Supabase)
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', apiLimiter);

// Body parser
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Timing middleware (log vía logger.debug: solo dev o LOG_LEVEL=debug)
app.use(timingMiddleware);

// Routes
app.use('/api', routes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler. En producción nunca se expone el mensaje interno (p. ej.
// errores crudos de Supabase o de negocio): el detalle queda SOLO en los
// logs del servidor (B3). El stack no se envía al cliente en ningún ambiente
// de producción.
app.use((err, req, res, next) => {
  const status = err.status || err.statusCode || 500;
  if (isProd) {
    logger.error(
      `[error] ${req.method} ${req.originalUrl} -> ${status}\n`,
      err.stack || err.message || err
    );
    return res.status(status).json({ error: 'Internal server error' });
  }
  console.error(err.stack);
  res.status(status).json({
    error: err.message || 'Internal server error',
    stack: err.stack
  });
});

// Escuchar en todas las interfaces (para que el teléfono pueda conectar)
app.listen(PORT, '0.0.0.0', () => {
  if (!isProd) {
    console.log(` Server running on port ${PORT}`);
    console.log(` Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(` API Base URL: http://localhost:${PORT}/api`);
    console.log(` Accesible desde la red local en: http://192.168.100.2:${PORT}/api`);
  }
});
