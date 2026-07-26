const supabase = require('../services/supabase');
const { getOrSet, invalidatePattern } = require('../services/cache');

/**
 * ESTRATEGIA DE CARGA DE DATOS
 * 
 * EAGER loading (vehículo → marca, modelo): El feed del almacén SIEMPRE muestra estos datos
 * para identificar qué pieza necesita cada cliente, así que vienen embebidos en la misma consulta.
 * 
 * LAZY loading (cotizaciones): En el listado solo traemos el CONTEO (cotizaciones(count)).
 * El detalle completo de cotizaciones se consulta bajo demanda en endpoints específicos
 * (getCotizacionesPorSolicitud, getMisCotizaciones) para evitar sobrecarga en el feed principal.
 */

// GET /requests (mis solicitudes - clientes)
const getMisSolicitudes = async (req, res) => {
  try {
    // Capturamos page y limit desde la URL. Si no vienen, por defecto no paginamos (o asignamos valores base)
    const page = parseInt(req.query.page);
    const limit = parseInt(req.query.limit);

    let query = supabase
      .from('solicitudes_repuesto')
      .select('*, vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*))), cotizaciones(count)')
      .eq('cliente_id', req.user.id)
      .order('created_at', { ascending: false });

    // Si el frontend envía parámetros de paginación, aplicamos el rango
    if (!isNaN(page) && !isNaN(limit)) {
      const from = (page - 1) * limit;
      const to = from + limit - 1;
      query = query.range(from, to);
    }

    const { data: solicitudes, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(solicitudes || []);
  } catch (error) {
    console.error('Get solicitudes error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /requests/active (para almacenes)
const getSolicitudesActivas = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;

    // Get warehouse ID for this user
    const { data: almacen, error: almacenError } = await supabase
      .from('almacenes')
      .select('id')
      .eq('encargado_id', req.user.id)
      .single();

    if (almacenError || !almacen) {
      return res.status(404).json({ error: 'Warehouse not found for this user' });
    }

    // Cache key específica por almacén para no mezclar datos
    const cacheKey = `solicitudes:activas:almacen:${almacen.id}:page:${page}`;

    const { data: solicitudes, fromCache } = await getOrSet(
      cacheKey,
      60, // 60 segundos TTL
      async () => {
        // Obtener solicitudes activas
        const { data, error } = await supabase
          .from('solicitudes_repuesto')
          .select(`*, profiles(nombre_completo, email),
            vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*))),
            cotizaciones(count)`)
          .eq('estado', 'en_proceso')
          .order('created_at', { ascending: false });

        if (error) {
          throw new Error(error.message);
        }

        // Filtrar solicitudes que ya tienen cotización de este almacén
        console.log(`[DEBUG] Filtrando solicitudes para almacén ${almacen.id}, total: ${(data || []).length}`);
        const solicitudesSinCotizar = await Promise.all(
          (data || []).map(async (solicitud) => {
            const { data: cotizacionesExistentes } = await supabase
              .from('cotizaciones')
              .select('id')
              .eq('solicitud_id', solicitud.id)
              .eq('almacen_id', almacen.id);
            
            const tieneCotizacion = cotizacionesExistentes && cotizacionesExistentes.length > 0;
            if (tieneCotizacion) {
              console.log(`[DEBUG] Solicitud ${solicitud.id} ya tiene cotización, excluyendo`);
            }
            return tieneCotizacion ? null : solicitud;
          })
        );

        const resultado = solicitudesSinCotizar.filter(s => s !== null);
        console.log(`[DEBUG] Solicitudes después de filtrar: ${resultado.length}`);
        return resultado;
      }
    );

    res.setHeader('X-Cache', fromCache ? 'HIT' : 'MISS');
    res.json(solicitudes);
  } catch (error) {
    console.error('Get solicitudes activas error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /requests
const createSolicitud = async (req, res) => {
  try {
    const { vehiculo_id, pieza_nombre, descripcion, foto_url, vin_busqueda, direccion_entrega_id, es_urgente } = req.body;

    if (!pieza_nombre) {
      return res.status(400).json({ error: 'pieza_nombre is required' });
    }

    const data = {
      cliente_id: req.user.id,
      pieza_nombre,
      estado: 'en_proceso'
    };

    if (vehiculo_id) data.vehiculo_id = vehiculo_id;
    if (descripcion) data.descripcion = descripcion;
    if (foto_url) data.foto_url = foto_url;
    if (vin_busqueda) data.vin_busqueda = vin_busqueda;
    if (direccion_entrega_id) data.direccion_entrega_id = direccion_entrega_id;
    if (es_urgente) data.es_urgente = es_urgente;

    const { data: solicitud, error } = await supabase
      .from('solicitudes_repuesto')
      .insert(data)
      .select('*, vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))')
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    // Invalidar caché de solicitudes activas
    await invalidatePattern('solicitudes:activas:*');

    res.status(201).json(solicitud);
  } catch (error) {
    console.error('Create solicitud error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /requests/:id
const getSolicitudPorId = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: solicitud, error } = await supabase
      .from('solicitudes_repuesto')
      .select(`*, profiles(nombre_completo, email), 
        vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))`)
      .eq('id', id)
      .single();

    if (error) {
      return res.status(404).json({ error: 'Solicitud not found' });
    }

    // Verify ownership or warehouse role
    if (req.user.rol !== 'almacen' && solicitud.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json(solicitud);
  } catch (error) {
    console.error('Get solicitud error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { getMisSolicitudes, getSolicitudesActivas, createSolicitud, getSolicitudPorId };
