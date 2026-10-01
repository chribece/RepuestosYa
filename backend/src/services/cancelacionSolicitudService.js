/**
 * Cancelación lógica de solicitudes (Parte 4) — reglas de negocio
 * aisladas del transporte HTTP para poder probarlas con un supabase falso
 * (`node --test`, sin red ni Redis).
 *
 * Reglas:
 * 1. Solo el dueño de la solicitud puede cancelarla.
 * 2. Idempotencia: una solicitud ya cancelada responde 200 sin efectos.
 * 3. Solo se cancela desde estados activos/pendientes (aún sin responder).
 * 4. Regla dura: se rechaza si existe al menos una cotización de un almacén.
 * 5. Defensivo: se rechaza si ya existe una orden de compra generada.
 */

class NotFoundError extends Error {
  constructor(message) {
    super(message);
    this.name = 'NotFoundError';
  }
}

class ForbiddenError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ForbiddenError';
  }
}

class ConflictError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ConflictError';
  }
}

class BadRequestError extends Error {
  constructor(message) {
    super(message);
    this.name = 'BadRequestError';
  }
}

/** Estados desde los que una solicitud SÍ puede cancelarse (pendiente/activa). */
const ESTADOS_CANCELABLES = ['en_proceso'];

/**
 * @param {object} opciones
 * @param {object} opciones.supabase Cliente Supabase (inyectado; en tests, un doble).
 * @param {string} opciones.solicitudId UUID de la solicitud.
 * @param {string} opciones.clienteAutenticadoId ID del usuario autenticado.
 * @returns {Promise<{solicitud: object, yaCancelada: boolean}>}
 */
const cancelarSolicitud = async ({
  supabase,
  solicitudId,
  clienteAutenticadoId,
}) => {
  // 1. Existencia + dueño + estado actual.
  const { data: solicitud, error: solicitudError } = await supabase
    .from('solicitudes_repuesto')
    .select('id, cliente_id, estado')
    .eq('id', solicitudId)
    .maybeSingle();

  if (solicitudError || !solicitud) {
    throw new NotFoundError('Solicitud no encontrada');
  }

  if (solicitud.cliente_id !== clienteAutenticadoId) {
    throw new ForbiddenError(
      'No tienes permiso para cancelar esta solicitud'
    );
  }

  // 2. Idempotencia: ya cancelada → sin efectos, nunca rompe.
  if (solicitud.estado === 'cancelada') {
    return { solicitud, yaCancelada: true };
  }

  // 3. Estado no cancelable (p. ej. asignada/completado/cerrada).
  if (!ESTADOS_CANCELABLES.includes(solicitud.estado)) {
    throw new ConflictError(
      `La solicitud no se puede cancelar en su estado actual (${solicitud.estado})`
    );
  }

  // 4. Regla dura: rechazar si algún almacén ya respondió (cotización).
  const { count: cotizaciones, error: cotizacionesError } = await supabase
    .from('cotizaciones')
    .select('*', { count: 'exact', head: true })
    .eq('solicitud_id', solicitudId);

  if (cotizacionesError) {
    throw new BadRequestError(cotizacionesError.message);
  }

  if (cotizaciones > 0) {
    throw new ConflictError(
      'La solicitud ya fue respondida por un almacén y no se puede cancelar'
    );
  }

  // 5. Defensivo: con orden de compra generada tampoco es cancelable.
  const { count: ordenes, error: ordenesError } = await supabase
    .from('ordenes_compra')
    .select('*', { count: 'exact', head: true })
    .eq('solicitud_id', solicitudId);

  if (ordenesError) {
    throw new BadRequestError(ordenesError.message);
  }

  if (ordenes > 0) {
    throw new ConflictError(
      'La solicitud tiene una orden de compra generada y no se puede cancelar'
    );
  }

  // 6. Cancelación lógica (UPDATE de estado).
  const { data: actualizada, error: updateError } = await supabase
    .from('solicitudes_repuesto')
    .update({ estado: 'cancelada' })
    .eq('id', solicitudId)
    .select()
    .single();

  if (updateError || !actualizada) {
    throw new BadRequestError(
      updateError ? updateError.message : 'No se pudo cancelar la solicitud'
    );
  }

  return { solicitud: actualizada, yaCancelada: false };
};

module.exports = {
  cancelarSolicitud,
  ESTADOS_CANCELABLES,
  NotFoundError,
  ForbiddenError,
  ConflictError,
  BadRequestError,
};
