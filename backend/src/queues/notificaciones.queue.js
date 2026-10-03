const { Queue } = require('bullmq');
const Redis = require('ioredis');
const logger = require('../utils/logger');

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

const connection = new Redis(redisUrl, {
  maxRetriesPerRequest: null
});

// Sin listener, un error de conexión a Redis derriba el proceso (evento
// 'error' no manejado). Se captura: los jobs de notificación fallan, pero la
// API sigue operativa.
connection.on('error', (err) => {
  logger.error('[queue] Redis connection error:', err.message);
});

const notificacionesQueue = new Queue('notificaciones', {
  connection
});

module.exports = notificacionesQueue;
