'use strict';

// Validación de variables de entorno al arranque (Parte 1 — producción).
//
// En NODE_ENV=production el proceso TERMINA si falta alguna variable
// obligatoria, con un mensaje claro que lista SOLO los nombres (nunca los
// valores). Esto evita arrancar en un estado inseguro o degradado (p. ej.
// sin SUPABASE_ANON_KEY, hallazgo B8: /auth/refresh no debe caer a la
// service-role key).
//
// Debe requerirse ANTES de cargar rutas/controladores (supabase.js lanza si
// faltan SUPABASE_URL/SERVICE_ROLE_KEY): la validación previa produce un
// mensaje mucho más claro y lista TODAS las variables faltantes de una vez.

const REQUIRED_PRODUCTION = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'SUPABASE_ANON_KEY', // B8: obligatoria en prod; /auth/refresh es fail-closed sin ella
  'JWT_SECRET',
  'JWT_EXPIRES_IN', // sin expiración, los JWTs serían válidos indefinidamente
  'ALLOWED_ORIGINS', // CORS de producción: vacío = ningún origen permitido
  'REDIS_URL', // caché + cola de notificaciones (BullMQ); sin Redis la API degrada
];

const isProd = process.env.NODE_ENV === 'production';
const missing = REQUIRED_PRODUCTION.filter((name) => !process.env[name]);

if (isProd && missing.length > 0) {
  process.stderr.write(
    '[env] ERROR: faltan variables de entorno obligatorias en producción: ' +
      missing.join(', ') +
      '\n' +
      '[env] Configúralas en el panel del proveedor (Render -> Environment) o revisa ' +
      'backend/.env.example. El proceso se detiene para no arrancar en un estado inseguro.\n'
  );
  process.exit(1);
}

if (!isProd && missing.length > 0) {
  console.warn(
    `[env] AVISO (solo desarrollo): faltan variables que en producción son obligatorias: ${missing.join(', ')}`
  );
}

module.exports = { REQUIRED_PRODUCTION, isProd };
