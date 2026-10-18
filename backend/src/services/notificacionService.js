'use strict';

const logger = require('../utils/logger');

const CAMPOS_NOTIFICACION =
  'id, user_id, tipo, titulo, mensaje, payload, created_at, leido_en';
const CAMPOS_LISTA =
  'id, tipo, titulo, mensaje, payload, created_at, leido_en';
const LIMITE_POR_PAGINA = 50;

const obtenerSupabase = () => require('./supabase');

class NotificacionNotFoundError extends Error {
  constructor() {
    super('Notificación no encontrada');
    this.name = 'NotificacionNotFoundError';
  }
}

/**
 * Las notificaciones son secundarias al negocio: un fallo al guardarlas se
 * registra, pero nunca revierte ni propaga error a la operación que las origina.
 * `deps` solo permite inyectar dobles en los tests.
 */
async function crearNotificacion(
  { userId, tipo, titulo, mensaje = null, payload = {} },
  deps = {},
) {
  try {
    const db = deps.supabase || obtenerSupabase();
    const { data, error } = await db
      .from('notificaciones')
      .insert({
        user_id: userId,
        tipo,
        titulo,
        mensaje,
        payload: payload ?? {},
      })
      .select(CAMPOS_NOTIFICACION)
      .single();

    if (error) throw error;
    return data;
  } catch (error) {
    try {
      (deps.logger || logger).error(
        '[notificaciones] No se pudo guardar una notificación:',
        error,
      );
    } catch (_) {
      // Un fallo del logger tampoco debe afectar al flujo de negocio.
    }
    return null;
  }
}

async function listarNotificaciones(
  { userId, page = 1, limit = 20 },
  deps = {},
) {
  const db = deps.supabase || obtenerSupabase();
  const safePage = Math.max(1, Number.parseInt(page, 10) || 1);
  const safeLimit = Math.min(
    LIMITE_POR_PAGINA,
    Math.max(1, Number.parseInt(limit, 10) || 20),
  );
  const from = (safePage - 1) * safeLimit;

  const { data, error } = await db
    .from('notificaciones')
    .select(CAMPOS_LISTA)
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .order('id', { ascending: false })
    .range(from, from + safeLimit);

  if (error) throw error;
  const rows = data || [];

  return {
    items: rows.slice(0, safeLimit),
    hasMore: rows.length > safeLimit,
    page: safePage,
    limit: safeLimit,
  };
}

async function marcarLeida({ userId, id }, deps = {}) {
  const db = deps.supabase || obtenerSupabase();
  const { data, error } = await db
    .from('notificaciones')
    .update({ leido_en: new Date().toISOString() })
    .eq('id', id)
    .eq('user_id', userId)
    .is('leido_en', null)
    .select('id, leido_en')
    .maybeSingle();

  if (error) throw error;
  if (data) return data;

  // A second call is idempotent; distinguish an already-read row from a row
  // that is missing or owned by someone else.
  const { data: existente, error: lookupError } = await db
    .from('notificaciones')
    .select('id, leido_en')
    .eq('id', id)
    .eq('user_id', userId)
    .maybeSingle();

  if (lookupError) throw lookupError;
  if (!existente) throw new NotificacionNotFoundError();
  return existente;
}

async function marcarTodasLeidas({ userId }, deps = {}) {
  const db = deps.supabase || obtenerSupabase();
  const { data, error } = await db
    .from('notificaciones')
    .update({ leido_en: new Date().toISOString() })
    .eq('user_id', userId)
    .is('leido_en', null)
    .select('id');

  if (error) throw error;
  return { actualizadas: (data || []).length };
}

async function contarNoLeidas({ userId }, deps = {}) {
  const db = deps.supabase || obtenerSupabase();
  const { count, error } = await db
    .from('notificaciones')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .is('leido_en', null);

  if (error) throw error;
  return count || 0;
}

module.exports = {
  CAMPOS_NOTIFICACION,
  LIMITE_POR_PAGINA,
  NotificacionNotFoundError,
  crearNotificacion,
  listarNotificaciones,
  marcarLeida,
  marcarTodasLeidas,
  contarNoLeidas,
};
