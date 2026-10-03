const Redis = require('ioredis');
const logger = require('../utils/logger');

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
const redis = new Redis(redisUrl);

// Sin listener, un error de conexión a Redis (p. ej. sin Redis en el plan
// free) lanza un 'error' no manejado y derriba el proceso. Aquí se captura
// y se degrada: el caché falla silenciosamente y la API sigue respondiendo.
redis.on('error', (err) => {
  logger.error('[cache] Redis connection error:', err.message);
});

/**
 * Intenta obtener valor de caché. Si no existe, ejecuta fetcher y guarda resultado.
 * @param {string} key - Clave de caché
 * @param {number} ttlSeconds - TTL en segundos
 * @param {Function} fetcher - Función asíncrona que retorna los datos a cachear
 * @returns {Promise<{data: any, fromCache: boolean}>}
 */
const getOrSet = async (key, ttlSeconds, fetcher) => {
  try {
    const cached = await redis.get(key);
    if (cached !== null) {
      return { data: JSON.parse(cached), fromCache: true };
    }
  } catch (error) {
    console.error('Cache get error:', error);
    // Si Redis falla, continuamos con fetcher
  }

  try {
    const data = await fetcher();
    
    try {
      await redis.set(key, JSON.stringify(data), 'EX', ttlSeconds);
    } catch (error) {
      console.error('Cache set error:', error);
      // Si falla el set, no bloqueamos la respuesta
    }

    return { data, fromCache: false };
  } catch (error) {
    throw error;
  }
};

/**
 * Invalida claves por patrón usando SCAN (no KEYS para evitar bloqueo)
 * @param {string} pattern - Patrón de claves a invalidar
 */
const invalidatePattern = async (pattern) => {
  try {
    let cursor = '0';
    do {
      const result = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = result[0];
      const keys = result[1];
      
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    } while (cursor !== '0');
  } catch (error) {
    console.error('Cache invalidation error:', error);
    // No bloqueamos si falla la invalidación
  }
};

module.exports = { getOrSet, invalidatePattern };
