// require('./supabase') y la cola se resuelven PEREZOSAMENTE: los tests
// inyectan dobles por parámetro (mismo patrón que cancelacionSolicitudService)
// y así el módulo carga sin variables de entorno ni Redis.
let _supabase;
let _notificacionesQueue;

const obtenerSupabase = () => {
  if (!_supabase) {
    _supabase = require('./supabase');
  }
  return _supabase;
};

const obtenerNotificacionesQueue = () => {
  if (!_notificacionesQueue) {
    _notificacionesQueue = require('../queues/notificaciones.queue');
  }
  return _notificacionesQueue;
};

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

/**
 * Acepta una cotización de forma atómica (RPC transaccional) y devuelve los
 * datos de contacto del almacén ganador para que el cliente coordine el pago
 * y la entrega por fuera de la app.
 *
 * Reglas:
 * - Solo el dueño de la solicitud puede aceptar (403).
 * - Idempotente: aceptar la MISMA cotización dos veces devuelve la orden
 *   existente sin fallar ni duplicar.
 * - Conflicto (409): la cotización ya fue decidida o ya existe otra
 *   cotización aceptada para la solicitud.
 * - La respuesta incluye nombre/teléfono/email del almacén ganador; esos
 *   datos solo se exponen tras la aceptación.
 *
 * [opciones] permite inyectar `supabase` y `notificacionesQueue` para tests
 * (mismo patrón que cancelacionSolicitudService); en producción se usan los
 * singulares del módulo.
 */
const aceptarCotizacion = async (cotizacionId, clienteAutenticadoId, opciones = {}) => {
  const db = opciones.supabase || obtenerSupabase();

  try {
    // a) Validar existencia de la cotización
    const { data: cotizacion, error: cotizacionError } = await db
      .from('cotizaciones')
      .select('id, estado, solicitud_id, almacen_id')
      .eq('id', cotizacionId)
      .single();

    if (cotizacionError || !cotizacion) {
      throw new NotFoundError('Cotización no encontrada');
    }

    // b) Validar que solicitud.cliente_id === clienteAutenticadoId
    const { data: solicitud, error: solicitudError } = await db
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

    // c) Idempotencia: la misma cotización ya aceptada → replay sin efectos.
    if (cotizacion.estado === 'aceptada') {
      return await construirRespuestaAceptacion(db, cotizacionId);
    }

    // d) Conflicto: la cotización ya fue decidida (rechazada) o el RPC
    //    detectará que otra cotización de la solicitud ya ganó (409).
    if (cotizacion.estado !== 'pendiente') {
      throw new ConflictError('Esta solicitud ya tiene una cotización aceptada');
    }

    // e) Ejecutar RPC aceptar_cotizacion (transacción atómica + idempotente)
    const { data: rpcResult, error: rpcError } = await db.rpc('aceptar_cotizacion', {
      p_cotizacion_id: cotizacionId,
      p_cliente_id: clienteAutenticadoId
    });

    if (rpcError) {
      const mensajeRpc = rpcError.message || '';
      // 409: ya existe otra cotización aceptada para la solicitud.
      if (mensajeRpc.includes('SOLICITUD_YA_ACEPTADA') ||
          mensajeRpc.includes('no está en estado pendiente')) {
        throw new ConflictError('Esta solicitud ya tiene una cotización aceptada');
      }
      if (mensajeRpc.includes('No tienes permiso')) {
        throw new ForbiddenError(mensajeRpc);
      }
      console.error('RPC Error:', rpcError);
      throw new BadRequestError(mensajeRpc || 'Error al procesar la aceptación de cotización');
    }

    // f) Si el RPC es exitoso, encolar 3 jobs en BullMQ
    // (la cola se resuelve solo aquí: los tests inyectan un doble y en
    // producción no se abre Redis si el RPC falló).
    const queue = opciones.notificacionesQueue || obtenerNotificacionesQueue();
    try {
      // Job 1: Notificar al almacén ganador
      await queue.add(
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
      await queue.add(
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
      await queue.add(
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

    // g) Respuesta con los datos de contacto del almacén ganador.
    return await construirRespuestaAceptacion(db, cotizacionId, rpcResult);
  } catch (error) {
    // Re-lanzar errores personalizados
    if (error instanceof NotFoundError ||
        error instanceof ForbiddenError ||
        error instanceof BadRequestError ||
        error instanceof ConflictError) {
      throw error;
    }
    console.error('Error en aceptarCotizacion:', error);
    throw new Error('Error interno del servidor al aceptar cotización');
  }
};

/**
 * Arma la respuesta de aceptación con el contacto del almacén ganador, el
 * nombre del repuesto y el precio. Se usa tanto tras el RPC como en el
 * replay idempotente (en ese caso [rpcResult] llega vacío y se leen la orden
 * y la solicitud desde la relación).
 */
const construirRespuestaAceptacion = async (db, cotizacionId, rpcResult = {}) => {
  const { data: detalles, error } = await db
    .from('cotizaciones')
    .select(
      'solicitud_id, precio_venta, ordenes_compra(id), ' +
      'solicitudes_repuesto(pieza_nombre, repuesto_nombre_snapshot), ' +
      'almacenes(nombre_comercial, telefono, email)'
    )
    .eq('id', cotizacionId)
    .single();

  if (error || !detalles) {
    throw new BadRequestError('No se pudieron cargar los datos de la aceptación');
  }

  const solicitudData = detalles.solicitudes_repuesto || {};
  const almacenData = detalles.almacenes || {};
  const orden = detalles.ordenes_compra;

  return {
    success: true,
    ordenId: rpcResult.orden_id || (orden && orden.id) || null,
    solicitudId: rpcResult.solicitud_id || detalles.solicitud_id || null,
    cotizacionGanadoraId: rpcResult.cotizacion_ganadora_id || cotizacionId,
    almacen: {
      nombre: almacenData.nombre_comercial || 'Almacén desconocido',
      telefono: almacenData.telefono || null,
      email: almacenData.email || null
    },
    repuestoNombre: solicitudData.repuesto_nombre_snapshot || solicitudData.pieza_nombre || '',
    precioVenta: detalles.precio_venta !== null && detalles.precio_venta !== undefined
      ? Number(detalles.precio_venta)
      : 0
  };
};

const rechazarCotizacion = async (cotizacionId, clienteAutenticadoId, opciones = {}) => {
  const db = opciones.supabase || obtenerSupabase();

  try {
    // a) Validaciones de existencia, estado 'pendiente' y propiedad
    const { data: cotizacion, error: cotizacionError } = await db
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

    const { data: solicitud, error: solicitudError } = await db
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
    const { data: updateData, error: updateError } = await db
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
    const queue = opciones.notificacionesQueue || obtenerNotificacionesQueue();
    try {
      await queue.add(
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
    const { count, error: countError } = await db
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
      const { error: solicitudUpdateError } = await db
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
  BadRequestError,
  ConflictError
};
