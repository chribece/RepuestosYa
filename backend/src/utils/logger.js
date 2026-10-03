'use strict';

// Logging centralizado del backend.
//
// Escribe directamente a process.stdout/stderr para sobrevivir al silenciado
// de console.* en producción (server.js) y para garantizar que el detalle de
// errores quede SOLO en los logs del servidor (hallazgo B3 de la auditoría),
// nunca en las respuestas HTTP.
//
// Reglas (hallazgo B4):
//   - Requests (método, ruta, status, ms): solo fuera de producción o con
//     LOG_LEVEL=debug. Nunca se registran headers de Authorization, bodies
//     de login ni tokens.
//   - debug: solo si NODE_ENV !== 'production' o LOG_LEVEL=debug.
//   - info : solo fuera de producción (en prod, uso consciente con debug).
//   - error: SIEMPRE a stderr (logs del servidor).

const isProd = process.env.NODE_ENV === 'production';
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const debugEnabled = !isProd || LOG_LEVEL === 'debug';

const toText = (value) => {
  if (typeof value === 'string') return value;
  if (value instanceof Error) return value.stack || value.message;
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
};

const write = (stream, args) => {
  stream.write(args.map(toText).join(' ') + '\n');
};

module.exports = {
  isProd,
  debugEnabled,
  debug: (...args) => {
    if (debugEnabled) write(process.stdout, args);
  },
  info: (...args) => {
    if (!isProd || debugEnabled) write(process.stdout, args);
  },
  error: (...args) => {
    write(process.stderr, args);
  },
};
