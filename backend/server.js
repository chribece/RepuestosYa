require('dotenv').config();

const isProd = process.env.NODE_ENV === 'production';

// En producción se desactiva console.* para impedir que controladores y
// servicios existentes filtren emails, IDs, perfiles o errores sensibles.
// Morgan conserva únicamente método, ruta y status HTTP.
if (isProd) {
  console.log = () => {};
  console.warn = () => {};
  console.error = () => {};
}

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan'); 
const routes = require('./src/routes');
const timingMiddleware = require('./src/middleware/timing');

const app = express();
const PORT = process.env.PORT || 3000;

// En producción solo se conservan método, ruta y estado HTTP.
app.use(morgan(isProd ? ':method :url :status' : 'dev'));

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

// Middleware de logging manual solo para desarrollo.
app.use((req, res, next) => {
  if (!isProd) {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  }
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

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler. En producción nunca se expone el mensaje interno (p. ej.
// errores crudos de Supabase o de negocio); el detalle queda solo para
// desarrollo. El stack no se envía al cliente en ningún ambiente de producción.
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

// Escuchar en todas las interfaces (para que el teléfono pueda conectar)
app.listen(PORT, '0.0.0.0', () => {
  if (!isProd) {
    console.log(` Server running on port ${PORT}`);
    console.log(` Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(` API Base URL: http://localhost:${PORT}/api`);
    console.log(` Accesible desde la red local en: http://192.168.100.2:${PORT}/api`);
  }
});