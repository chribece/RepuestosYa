const supabase = require('../services/supabase');
const { invalidatePattern, getOrSet } = require('../services/cache');
const notificacionesQueue = require('../queues/notificaciones.queue');
const { aceptarCotizacion, rechazarCotizacion, NotFoundError, ForbiddenError, BadRequestError } = require('../services/cotizacionService');

// POST /quotations (solo almacenes)
const createCotizacion = async (req, res) => {
  try {
    // Verify warehouse role
    if (req.user.rol !== 'almacen') {
      return res.status(403).json({ error: 'Only warehouses can create quotes' });
    }

    const { solicitud_id, almacen_id, precio_venta, condicion_repuesto, foto_evidencia_url, notas_adicionales, tiempo_entrega_estimado } = req.body;

    if (!solicitud_id || !almacen_id || !precio_venta) {
      return res.status(400).json({ error: 'solicitud_id, almacen_id and precio_venta are required' });
    }

    // Verify solicitud is active
    const { data: solicitud, error: solicitudError } = await supabase
      .from('solicitudes_repuesto')
      .select('estado')
      .eq('id', solicitud_id)
      .single();

    if (solicitudError || !solicitud) {
      return res.status(404).json({ error: 'Solicitud not found' });
    }

    if (solicitud.estado !== 'en_proceso') {
      return res.status(400).json({ error: 'Solicitud is not active' });
    }

    // Verify warehouse ownership and status
    const { data: almacen, error: almacenError } = await supabase
      .from('almacenes')
      .select('encargado_id, verification_status')
      .eq('id', almacen_id)
      .single();

    if (almacenError || !almacen) {
      return res.status(404).json({ error: 'Warehouse not found' });
    }

    if (almacen.encargado_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this warehouse' });
    }

    // Bloquear si el almacén no está aprobado
    if (almacen.verification_status !== 'approved') {
      return res.status(403).json({ 
        code: 'WAREHOUSE_NOT_APPROVED',
        message: 'Tu almacén aún no ha sido aprobado para realizar cotizaciones.' 
      });
    }

    const { data: cotizacion, error } = await supabase
      .from('cotizaciones')
      .insert({
        solicitud_id,
        almacen_id,
        precio_venta,
        condicion_repuesto,
        foto_evidencia_url,
        notas_adicionales,
        tiempo_entrega_estimado,
        estado: 'pendiente'
      })
      .select('*, almacenes(nombre_comercial)')
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Invalidar caché de solicitudes activas
    await invalidatePattern('solicitudes:activas:*');

    // Encolar job de notificación (no espera a que se procese)
    try {
      await notificacionesQueue.add(
        'cotizacion-creada',
        { 
          cotizacionId: cotizacion.id, 
          solicitudId: solicitud_id 
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
      console.warn('[Queue] Error al encolar notificación:', queueError.message);
      // No bloqueamos la respuesta si la cola falla
    }

    res.status(201).json(cotizacion);
  } catch (error) {
    console.error('Create cotizacion error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /quotations/my-quotations (para almacenes)
const getMisCotizaciones = async (req, res) => {
  try {
    // Get warehouse ID for this user
    const { data: almacen, error: almacenError } = await supabase
      .from('almacenes')
      .select('id')
      .eq('encargado_id', req.user.id)
      .single();

    if (almacenError || !almacen) {
      return res.status(404).json({ error: 'Warehouse not found for this user' });
    }

    const { data: cotizaciones, error } = await supabase
      .from('cotizaciones')
      .select('*, solicitudes_repuesto(pieza_nombre, estado, profiles(nombre_completo)), ordenes_compra(id, estado)')
      .eq('almacen_id', almacen.id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(cotizaciones || []);
  } catch (error) {
    console.error('Get cotizaciones error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /quotations/request/:solicitud_id (para clientes)
const getCotizacionesPorSolicitud = async (req, res) => {
  try {
    const { solicitud_id } = req.params;

    // Verify solicitud ownership
    const { data: solicitud, error: solicitudError } = await supabase
      .from('solicitudes_repuesto')
      .select('cliente_id')
      .eq('id', solicitud_id)
      .single();

    if (solicitudError || !solicitud) {
      return res.status(404).json({ error: 'Solicitud not found' });
    }

    if (solicitud.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { data: cotizaciones, error } = await supabase
      .from('cotizaciones')
      .select('*, almacenes(nombre_comercial, direccion_texto, latitude, longitude)')
      .eq('solicitud_id', solicitud_id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(cotizaciones || []);
  } catch (error) {
    console.error('Get cotizaciones por solicitud error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// PUT /quotations/:id/status (solo clientes)
const updateCotizacionEstado = async (req, res) => {
  try {
    const { id } = req.params;
    const { estado } = req.body;

    if (!estado || !['aceptada', 'rechazada'].includes(estado)) {
      return res.status(400).json({ error: 'Estado must be "aceptada" or "rechazada"' });
    }

    // Get cotizacion with solicitud
    const { data: cotizacion, error: cotizacionError } = await supabase
      .from('cotizaciones')
      .select('*, solicitudes_repuesto(cliente_id)')
      .eq('id', id)
      .single();

    if (cotizacionError || !cotizacion) {
      return res.status(404).json({ error: 'Cotizacion not found' });
    }

    // Verify client ownership
    if (cotizacion.solicitudes_repuesto.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this solicitud' });
    }

    // Update cotizacion estado
    const { data: updatedCotizacion, error: updateError } = await supabase
      .from('cotizaciones')
      .update({ estado })
      .eq('id', id)
      .select()
      .single();

    if (updateError) {
      return res.status(400).json({ error: updateError.message });
    }

    // If accepted, update solicitud to completado
    if (estado === 'aceptada') {
      await supabase
        .from('solicitudes_repuesto')
        .update({ estado: 'completado' })
        .eq('id', cotizacion.solicitud_id);
    }

    // Invalidar caché de solicitudes activas
    await invalidatePattern('solicitudes:activas:*');

    res.json(updatedCotizacion);
  } catch (error) {
    console.error('Update cotizacion estado error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /almacen/mi-almacen (para almacenes)
const getMiAlmacen = async (req, res) => {
  try {
    const { data: almacen, error } = await supabase
      .from('almacenes')
      .select('*')
      .eq('encargado_id', req.user.id)
      .single();

    if (error || !almacen) {
      return res.status(404).json({ error: 'Warehouse not found for this user' });
    }

    res.json(almacen);
  } catch (error) {
    console.error('Get mi almacen error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /quotations/:id/accept (solo clientes)
const aceptarCotizacionController = async (req, res) => {
  try {
    // Validar rol 'cliente'
    if (req.user.rol !== 'cliente') {
      return res.status(403).json({ error: 'Solo los clientes pueden aceptar cotizaciones' });
    }

    const { id } = req.params;

    // Validar UUID con regex estricto
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      return res.status(400).json({ error: 'ID de cotización inválido' });
    }

    const result = await aceptarCotizacion(id, req.user.id);

    res.status(200).json({
      success: true,
      ordenId: result.ordenId,
      solicitudId: result.solicitudId,
      cotizacionGanadoraId: result.cotizacionGanadoraId
    });
  } catch (error) {
    // Mapeo explícito de errores a códigos HTTP
    if (error instanceof NotFoundError) {
      return res.status(404).json({ error: error.message });
    }
    if (error instanceof ForbiddenError) {
      return res.status(403).json({ error: error.message });
    }
    if (error instanceof BadRequestError) {
      return res.status(400).json({ error: error.message });
    }
    console.error('Aceptar cotizacion error:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /quotations/:id/reject (solo clientes)
const rechazarCotizacionController = async (req, res) => {
  try {
    // Validar rol 'cliente'
    if (req.user.rol !== 'cliente') {
      return res.status(403).json({ error: 'Solo los clientes pueden rechazar cotizaciones' });
    }

    const { id } = req.params;

    // Validar UUID con regex estricto
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      return res.status(400).json({ error: 'ID de cotización inválido' });
    }

    const result = await rechazarCotizacion(id, req.user.id);

    res.status(200).json({
      success: true,
      solicitudCerrada: result.solicitudCerrada
    });
  } catch (error) {
    // Mapeo explícito de errores a códigos HTTP
    if (error instanceof NotFoundError) {
      return res.status(404).json({ error: error.message });
    }
    if (error instanceof ForbiddenError) {
      return res.status(403).json({ error: error.message });
    }
    if (error instanceof BadRequestError) {
      return res.status(400).json({ error: error.message });
    }
    console.error('Rechazar cotizacion error:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = { createCotizacion, getMisCotizaciones, getCotizacionesPorSolicitud, updateCotizacionEstado, getMiAlmacen, aceptarCotizacion: aceptarCotizacionController, rechazarCotizacion: rechazarCotizacionController };
