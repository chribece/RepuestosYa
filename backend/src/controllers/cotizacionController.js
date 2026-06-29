const supabase = require('../services/supabase');

// POST /cotizaciones (solo almacenes)
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

    // Verify warehouse ownership
    const { data: almacen, error: almacenError } = await supabase
      .from('almacenes')
      .select('encargado_id')
      .eq('id', almacen_id)
      .single();

    if (almacenError || !almacen) {
      return res.status(404).json({ error: 'Warehouse not found' });
    }

    if (almacen.encargado_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this warehouse' });
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

    res.status(201).json(cotizacion);
  } catch (error) {
    console.error('Create cotizacion error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /cotizaciones/mis-cotizaciones (para almacenes)
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
      .select('*, solicitudes_repuesto(pieza_nombre, estado, profiles(nombre_completo))')
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

// GET /cotizaciones/solicitud/:solicitud_id (para clientes)
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
      .select('*, almacenes(nombre_comercial, direccion_texto)')
      .eq('solicitud_id', solicitud_id)
      .order('precio_venta', { ascending: true });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(cotizaciones || []);
  } catch (error) {
    console.error('Get cotizaciones por solicitud error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// PUT /cotizaciones/:id/estado (solo clientes)
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

    res.json(updatedCotizacion);
  } catch (error) {
    console.error('Update cotizacion estado error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { createCotizacion, getMisCotizaciones, getCotizacionesPorSolicitud, updateCotizacionEstado };
