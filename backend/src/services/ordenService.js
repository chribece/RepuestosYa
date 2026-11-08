const supabase = require('./supabase');

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

class BadRequestError extends Error {
  constructor(message) {
    super(message);
    this.name = 'BadRequestError';
  }
}

class ConflictError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ConflictError';
  }
}

const getOrdenDetalle = async (ordenId, clienteAutenticadoId) => {
  try {
    // Validar que la orden existe y pertenece al cliente autenticado
    const { data: orden, error: ordenError } = await supabase
      .from('ordenes_compra')
      .select(`
        id,
        cliente_id,
        almacen_id,
        solicitud_id,
        cotizacion_id,
        detalles,
        estado,
        created_at,
        updated_at,
        almacenes (
          nombre_comercial,
          direccion_texto
        ),
        calificaciones_orden (
          estrellas,
          comentario
        )
      `)
      .eq('id', ordenId)
      .single();

    if (ordenError || !orden) {
      throw new NotFoundError('Orden de compra no encontrada');
    }

    // Verificar que el cliente autenticado es el dueño de la orden
    if (orden.cliente_id !== clienteAutenticadoId) {
      throw new ForbiddenError('No tienes permiso para ver esta orden de compra');
    }

    return orden;
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError || error instanceof BadRequestError) {
      throw error;
    }
    console.error('Error en getOrdenDetalle:', error);
    throw new Error('Error interno del servidor al obtener el detalle de la orden');
  }
};

const getOrdenDetalleParaAlmacen = async (ordenId, almacenAutenticadoId) => {
  try {
    // Validar que la orden existe y pertenece al almacén autenticado
    const { data: orden, error: ordenError } = await supabase
      .from('ordenes_compra')
      .select(`
        id,
        cliente_id,
        almacen_id,
        solicitud_id,
        cotizacion_id,
        detalles,
        estado,
        created_at,
        updated_at,
        almacenes (
          nombre_comercial,
          direccion_texto
        ),
        solicitudes_repuesto (
          profiles (nombre_completo, telefono),
          direcciones_entrega (*)
        )
      `)
      .eq('id', ordenId)
      .single();

    if (ordenError || !orden) {
      console.error('[Service] Orden no encontrada:', ordenError);
      throw new NotFoundError('Orden de compra no encontrada');
    }

    console.log('[Service] Validando orden:', { ordenId, ordenAlmacenId: orden.almacen_id, almacenAutenticadoId });

    // Verificar que el almacén autenticado es el dueño de la orden
    if (orden.almacen_id !== almacenAutenticadoId) {
      console.error('[Service] Permisos denegados:', { ordenAlmacenId: orden.almacen_id, almacenAutenticadoId });
      throw new ForbiddenError('No tienes permiso para ver esta orden de compra');
    }

    return orden;
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError || error instanceof BadRequestError) {
      throw error;
    }
    console.error('Error en getOrdenDetalleParaAlmacen:', error);
    throw new Error('Error interno del servidor al obtener el detalle de la orden');
  }
};

const updateOrdenEstado = async (ordenId, nuevoEstado, almacenId) => {
  try {
    // Validar que nuevoEstado sea válido
    const estadosValidos = ['pendiente_pago', 'confirmada', 'entregada', 'cancelada'];
    if (!estadosValidos.includes(nuevoEstado)) {
      throw new BadRequestError('Estado inválido. Estados válidos: pendiente_pago, confirmada, entregada, cancelada');
    }

    // Validar que la orden existe y pertenece al almacén autenticado
    const { data: orden, error: ordenError } = await supabase
      .from('ordenes_compra')
      .select('id, estado, almacen_id')
      .eq('id', ordenId)
      .single();

    if (ordenError || !orden) {
      throw new NotFoundError('Orden de compra no encontrada');
    }

    // Verificar que el almacén autenticado es el dueño de la orden
    if (orden.almacen_id !== almacenId) {
      throw new ForbiddenError('No tienes permiso para actualizar esta orden de compra');
    }

    // Ejecutar el UPDATE
    const { data: ordenActualizada, error: updateError } = await supabase
      .from('ordenes_compra')
      .update({ estado: nuevoEstado })
      .eq('id', ordenId)
      .select()
      .single();

    if (updateError || !ordenActualizada) {
      throw new BadRequestError('Error al actualizar el estado de la orden');
    }

    return ordenActualizada;
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError || error instanceof BadRequestError) {
      throw error;
    }
    console.error('Error en updateOrdenEstado:', error);
    throw new Error('Error interno del servidor al actualizar el estado de la orden');
  }
};

/**
 * Guarda la calificación del almacén de una orden entregada. Una orden admite
 * una sola calificación (restricción única en `orden_id`).
 */
const calificarOrden = async (ordenId, clienteAutenticadoId, { estrellas, comentario }, opciones = {}) => {
  const db = opciones.supabase || supabase;
  try {
    const { data: orden, error: ordenError } = await db
      .from('ordenes_compra')
      .select('id, cliente_id, almacen_id, estado')
      .eq('id', ordenId)
      .single();

    if (ordenError || !orden) {
      throw new NotFoundError('Orden de compra no encontrada');
    }
    if (orden.cliente_id !== clienteAutenticadoId) {
      throw new ForbiddenError('No tienes permiso para calificar esta orden');
    }
    if (orden.estado !== 'entregada') {
      throw new BadRequestError('Solo puedes calificar una orden entregada');
    }

    const { data: existente, error: existenteError } = await db
      .from('calificaciones_orden')
      .select('id')
      .eq('orden_id', ordenId)
      .maybeSingle();
    if (existenteError) throw existenteError;
    if (existente) {
      throw new ConflictError('Esta orden ya fue calificada');
    }

    const { data, error: insertError } = await db
      .from('calificaciones_orden')
      .insert({
        orden_id: ordenId,
        almacen_id: orden.almacen_id,
        cliente_id: clienteAutenticadoId,
        estrellas,
        comentario: comentario || null,
      })
      .select('estrellas, comentario, created_at')
      .single();

    if (insertError) {
      // 23505: unique_violation (dos envíos simultáneos de la misma orden).
      if (insertError.code === '23505') {
        throw new ConflictError('Esta orden ya fue calificada');
      }
      throw new BadRequestError('No se pudo guardar la calificación');
    }
    return data;
  } catch (error) {
    if (
      error instanceof NotFoundError ||
      error instanceof ForbiddenError ||
      error instanceof BadRequestError ||
      error instanceof ConflictError
    ) {
      throw error;
    }
    console.error('Error en calificarOrden:', error);
    throw new Error('Error interno del servidor al guardar la calificación');
  }
};

module.exports = {
  getOrdenDetalle,
  getOrdenDetalleParaAlmacen,
  updateOrdenEstado,
  calificarOrden,
  NotFoundError,
  ForbiddenError,
  BadRequestError,
  ConflictError
};
