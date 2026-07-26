const supabase = require('./supabase');
const notificacionesQueue = require('../queues/notificaciones.queue');

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

const aceptarCotizacion = async (cotizacionId, clienteAutenticadoId) => {
  try {
    // a) Validar existencia y estado 'pendiente' de la cotización
    const { data: cotizacion, error: cotizacionError } = await supabase
      .from('cotizaciones')
      .select('id, estado, solicitud_id, almacen_id, precio_venta, condicion_repuesto, tiempo_entrega_estimado, notas_adicionales, foto_evidencia_url')
      .eq('id', cotizacionId)
      .single();

    if (cotizacionError || !cotizacion) {
      throw new NotFoundError('Cotización no encontrada');
    }

    if (cotizacion.estado !== 'pendiente') {
      throw new BadRequestError('La cotización no está en estado pendiente');
    }

    // b) Validar que solicitud.cliente_id === clienteAutenticadoId
    const { data: solicitud, error: solicitudError } = await supabase
      .from('solicitudes_repuesto')
      .select('cliente_id')
      .eq('id', cotizacion.solicitud_id)
      .single();

    if (solicitudError || !solicitud) {
      throw new NotFoundError('Solicitud no encontrada');
    }

    if (solicitud.cliente_id !== clienteAutenticadoId) {
      throw new ForbiddenError('No tienes permiso para aceptar esta cotización');
    }

    // c) Ejecutar RPC aceptar_cotización con snapshot de detalles en JSONB
    const { data: rpcResult, error: rpcError } = await supabase.rpc('aceptar_cotizacion', {
      p_cotizacion_id: cotizacionId,
      p_cliente_id: clienteAutenticadoId
    });

    if (rpcError) {
      console.error('RPC Error:', rpcError);
      throw new BadRequestError(rpcError.message || 'Error al procesar la aceptación de cotización');
    }

    // d) Si el RPC es exitoso, encolar 3 jobs en BullMQ
    try {
      // Job 1: Notificar al almacén ganador
      await notificacionesQueue.add(
        'notificar-almacen-ganador',
        {
          cotizacionId,
          almacenId: cotizacion.almacen_id,
          solicitudId: cotizacion.solicitud_id,
          ordenId: rpcResult?.orden_id,
          
        },
        {
          attempts: 3,
          backoff: {
            type: 'exponential',
            delay: 2000
          },
          removeOnComplete: 100
        }
      );

      // Job 2: Notificar a los almacenes perdedores
      await notificacionesQueue.add(
        'notificar-almacenes-perdedores',
        {
          solicitudId: cotizacion.solicitud_id,
          cotizacionGanadoraId: cotizacionId
        },
        {
          attempts: 3,
          backoff: {
            type: 'exponential',
            delay: 2000
          },
          removeOnComplete: 100
        }
      );

      // Job 3: Notificar al cliente sobre la aceptación
      await notificacionesQueue.add(
        'notificar-cliente-aceptacion',
        {
          cotizacionId,
          clienteId: clienteAutenticadoId,
          ordenId: rpcResult?.orden_id
        },
        {
          attempts: 3,
          backoff: {
            type: 'exponential',
            delay: 2000
          },
          removeOnComplete: 100
        }
      );
    } catch (queueError) {
      console.warn('[Queue] Error al encolar notificaciones:', queueError.message);
      // No bloqueamos la respuesta si la cola falla
    }

    return {
      ordenId: rpcResult?.orden_id,
      solicitudId: rpcResult?.solicitud_id,
      cotizacionGanadoraId: rpcResult?.cotizacion_ganadora_id
    };
  } catch (error) {
    // Re-lanzar errores personalizados
    if (error instanceof NotFoundError || error instanceof ForbiddenError || error instanceof BadRequestError) {
      throw error;
    }
    console.error('Error en aceptarCotizacion:', error);
    throw new Error('Error interno del servidor al aceptar cotización');
  }
};

const rechazarCotizacion = async (cotizacionId, clienteAutenticadoId) => {
  try {
    // a) Validaciones de existencia, estado 'pendiente' y propiedad
    const { data: cotizacion, error: cotizacionError } = await supabase
      .from('cotizaciones')
      .select('id, estado, solicitud_id, almacen_id')
      .eq('id', cotizacionId)
      .single();

    if (cotizacionError || !cotizacion) {
      throw new NotFoundError('Cotización no encontrada');
    }
    if (cotizacion.estado !== 'pendiente') {
      throw new BadRequestError('La cotización no está en estado pendiente');
    }

    const { data: solicitud, error: solicitudError } = await supabase
      .from('solicitudes_repuesto')
      .select('cliente_id')
      .eq('id', cotizacion.solicitud_id)
      .single();

    if (solicitudError || !solicitud) {
      throw new NotFoundError('Solicitud no encontrada');
    }
    if (solicitud.cliente_id !== clienteAutenticadoId) {
      throw new ForbiddenError('No tienes permiso para rechazar esta cotización');
    }

    // b) UPDATE directo a 'rechazada' (AGREGAMOS .select() PARA VERIFICAR)
    const { data: updateData, error: updateError } = await supabase
      .from('cotizaciones')
      .update({ estado: 'rechazada' })
      .eq('id', cotizacionId)
      .select(); // <-- ESTO ES CLAVE: devuelve la fila actualizada

    if (updateError) {
      console.error('[Service] Update Error en rechazar:', updateError);
      throw new BadRequestError('Error al actualizar el estado de la cotización');
    }

    // DIAGNÓSTICO: Si no hay error, pero updateData está vacío, ¡RLS lo está bloqueando!
    if (!updateData || updateData.length === 0) {
      console.warn('[Service] Advertencia: El UPDATE no afectó ninguna fila. Revisa las políticas RLS de "cotizaciones" o usa la SERVICE_ROLE_KEY en el backend.');
    } else {
      console.log('[Service] Cotización actualizada exitosamente a rechazada:', updateData[0].id);
    }

    // c) Encolar job 'notificar-almacen-rechazo'
    try {
      await notificacionesQueue.add(
        'notificar-almacen-rechazo',
        {
          cotizacionId,
          almacenId: cotizacion.almacen_id,
          solicitudId: cotizacion.solicitud_id
        },
        {
          attempts: 3,
          backoff: { type: 'exponential', delay: 2000 },
          removeOnComplete: 100
        }
      );
    } catch (queueError) {
      console.warn('[Queue] Error al encolar notificación de rechazo:', queueError.message);
    }

    // d) Contar cotizaciones pendientes restantes
    const { count, error: countError } = await supabase
      .from('cotizaciones')
      .select('*', { count: 'exact', head: true })
      .eq('solicitud_id', cotizacion.solicitud_id)
      .eq('estado', 'pendiente');

    if (countError) {
      console.warn('[Service] Error al contar cotizaciones pendientes:', countError.message);
    }

    console.log(`[Service] Cotizaciones pendientes restantes para solicitud ${cotizacion.solicitud_id}: ${count}`);

    // Si count === 0, UPDATE solicitud a 'cerrada'
    if (count === 0) {
      const { error: solicitudUpdateError } = await supabase
        .from('solicitudes_repuesto')
        .update({ estado: 'cerrada' })
        .eq('id', cotizacion.solicitud_id);
        
      if (solicitudUpdateError) {
        console.warn('[Service] Error al cerrar solicitud:', solicitudUpdateError.message);
      } else {
        console.log('[Service] Solicitud cerrada exitosamente por no tener más cotizaciones pendientes.');
      }
    }

    return {
      success: true,
      solicitudCerrada: count === 0
    };
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ForbiddenError || error instanceof BadRequestError) {
      throw error;
    }
    console.error('Error en rechazarCotizacion:', error);
    throw new Error('Error interno del servidor al rechazar cotización');
  }
};

module.exports = {
  aceptarCotizacion,
  rechazarCotizacion,
  NotFoundError,
  ForbiddenError,
  BadRequestError
};
