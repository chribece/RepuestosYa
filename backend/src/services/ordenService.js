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

module.exports = {
  getOrdenDetalle,
  getOrdenDetalleParaAlmacen,
  updateOrdenEstado,
  NotFoundError,
  ForbiddenError,
  BadRequestError
};
