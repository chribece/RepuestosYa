'use strict';

const supabase = require('../services/supabase');
const { version } = require('../../package.json');

// GET /health — sin autenticación y registrado ANTES de los rate limiters.
//
// Comprueba con un ping barato a Supabase (head query: no trae filas ni hace
// count) y expone únicamente "ok" | "error" en el campo db. Nunca se envía
// err.message ni datos internos al cliente: el detalle queda en los logs del
// servidor (hallazgo B3).
const PING_TIMEOUT_MS = 3000;

const check = async (_req, res) => {
  let db = 'ok';
  let timer;

  try {
    const ping = supabase.from('profiles').select('id', { head: true }).limit(1);
    const timeout = new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('health ping timeout')), PING_TIMEOUT_MS);
    });
    const { error } = await Promise.race([ping, timeout]);
    if (error) db = 'error';
  } catch {
    db = 'error';
  } finally {
    clearTimeout(timer);
  }

  const body = {
    status: db === 'ok' ? 'ok' : 'error',
    version,
    uptime: Math.round(process.uptime()),
    timestamp: new Date().toISOString(),
    db,
  };
  res.status(db === 'ok' ? 200 : 503).json(body);
};

module.exports = { check };
