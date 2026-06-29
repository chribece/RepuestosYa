require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan'); 
const routes = require('./src/routes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware de logging (MORGAN) - muestra cada petición en consola
app.use(morgan('dev'));

// Security middleware
app.use(helmet());

// CORS configuration
/*app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? ['https://your-production-domain.com'] 
    : ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://192.168.10.232:3000'],
  credentials: true
}));*/

// CORS (abierto para desarrollo)
app.use(cors({
  origin: '*', // 👈 En desarrollo, permitir cualquier origen
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

//  Middleware de logging manual (por si morgan falla)
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

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

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// Escuchar en todas las interfaces (para que el teléfono pueda conectar)
app.listen(PORT, '0.0.0.0', () => {
  console.log(` Server running on port ${PORT}`);
  console.log(` Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(` API Base URL: http://localhost:${PORT}/api`);
  console.log(` Accesible desde la red local en: http://192.168.10.232:${PORT}/api`);
});