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

module.exports = {
  getOrdenDetalle,
  NotFoundError,
  ForbiddenError,
  BadRequestError
};
