'use strict';

const logger = require('../utils/logger');
const {
  NotificacionNotFoundError,
  listarNotificaciones,
  marcarLeida,
  marcarTodasLeidas,
  contarNoLeidas,
} = require('../services/notificacionService');

const parsePositiveInteger = (value) => {
  if (value === undefined) return null;
  if (!/^[1-9]\d*$/.test(String(value))) return NaN;
  return Number(value);
};

const getNotificaciones = async (req, res) => {
  const page = parsePositiveInteger(req.query.page) ?? 1;
  const limit = parsePositiveInteger(req.query.limit) ?? 20;

  const offset = (page - 1) * limit;
  if (
    !Number.isSafeInteger(page) ||
    !Number.isSafeInteger(limit) ||
    limit > 50 ||
    !Number.isSafeInteger(offset)
  ) {
    return res.status(400).json({
      error: 'page debe ser un entero positivo y limit debe estar entre 1 y 50.',
    });
  }

  try {
    const result = await listarNotificaciones({
      userId: req.user.id,
      page,
      limit,
    });
    return res.status(200).json(result);
  } catch (error) {
    logger.error('[notificaciones] Error listando notificaciones:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const getUnreadCount = async (req, res) => {
  try {
    const unreadCount = await contarNoLeidas({ userId: req.user.id });
    return res.status(200).json({ unreadCount });
  } catch (error) {
    logger.error('[notificaciones] Error contando no leídas:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const patchMarcarLeida = async (req, res) => {
  try {
    const notification = await marcarLeida({
      userId: req.user.id,
      id: req.params.id,
    });
    return res.status(200).json(notification);
  } catch (error) {
    if (error instanceof NotificacionNotFoundError) {
      return res.status(404).json({ error: error.message });
    }
    logger.error('[notificaciones] Error marcando como leída:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const patchMarcarTodasLeidas = async (req, res) => {
  try {
    const result = await marcarTodasLeidas({ userId: req.user.id });
    return res.status(200).json(result);
  } catch (error) {
    logger.error('[notificaciones] Error marcando todas como leídas:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = {
  getNotificaciones,
  getUnreadCount,
  patchMarcarLeida,
  patchMarcarTodasLeidas,
};
