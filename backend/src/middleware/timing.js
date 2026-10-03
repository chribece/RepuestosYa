const logger = require('../utils/logger');

const timingMiddleware = (req, res, next) => {
  const startTime = process.hrtime.bigint();
  
  res.on('finish', () => {
    const endTime = process.hrtime.bigint();
    const durationNs = endTime - startTime;
    const durationMs = Number(durationNs) / 1_000_000; // Convertir nanosegundos a milisegundos
    
    // B4: solo se registra en desarrollo o con LOG_LEVEL=debug.
    logger.debug(`${req.method} ${req.url} -> ${res.statusCode} | ${durationMs.toFixed(1)}ms`);
  });
  
  next();
};

module.exports = timingMiddleware;
