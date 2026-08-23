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
      .select('*, categorias_repuestos(nombre), vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*))), cotizaciones(count)')
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
      10, // 10 segundos TTL para mantener datos más actualizados
      async () => {
        // Obtener solicitudes activas
        const { data, error } = await supabase
          .from('solicitudes_repuesto')
          .select(`*, profiles(nombre_completo, email),
            categorias_repuestos(nombre),
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
    const { 
      vehiculo_id, 
      pieza_nombre, 
      descripcion, 
      foto_url, 
      vin_busqueda, 
      direccion_entrega_id, 
      es_urgente,
      categoria_id,
      repuesto_id,
      repuesto_nombre_snapshot,
      descripcion_problema
    } = req.body;

    if (!pieza_nombre && !repuesto_nombre_snapshot) {
      return res.status(400).json({ error: 'pieza_nombre or repuesto_nombre_snapshot is required' });
    }

    // Si viene repuesto_id, validamos que exista y obtenemos su nombre si no viene snapshot
    let finalPiezaNombre = pieza_nombre;
    let finalSnapshot = repuesto_nombre_snapshot;

    if (repuesto_id) {
      const { data: repuesto, error: repuestoError } = await supabase
        .from('repuestos_catalogo')
        .select('nombre, categoria_id, activo')
        .eq('id', repuesto_id)
        .single();

      if (repuestoError || !repuesto) {
        return res.status(400).json({ error: 'Invalid repuesto_id' });
      }

      if (!repuesto.activo) {
        return res.status(400).json({ error: 'Selected part is not active' });
      }

      // Validar que la categoría coincida si se envió
      if (categoria_id && repuesto.categoria_id !== categoria_id) {
        return res.status(400).json({ error: 'repuesto_id does not belong to the selected category' });
      }

      // Si no viene snapshot, usamos el nombre del catálogo
      if (!finalSnapshot) {
        finalSnapshot = repuesto.nombre;
      }
      
      // Si no viene pieza_nombre (flujo nuevo), usamos el del catálogo para compatibilidad
      if (!finalPiezaNombre) {
        finalPiezaNombre = repuesto.nombre;
      }
    }

    const data = {
      cliente_id: req.user.id,
      pieza_nombre: finalPiezaNombre,
      estado: 'en_proceso'
    };

    if (vehiculo_id) data.vehiculo_id = vehiculo_id;
    if (descripcion) data.descripcion = descripcion;
    if (foto_url) data.foto_url = foto_url;
    if (vin_busqueda) data.vin_busqueda = vin_busqueda;
    if (direccion_entrega_id) data.direccion_entrega_id = direccion_entrega_id;
    if (es_urgente) data.es_urgente = es_urgente;
    
    // Nuevos campos
    if (categoria_id) data.categoria_id = categoria_id;
    if (repuesto_id) data.repuesto_id = repuesto_id;
    if (finalSnapshot) data.repuesto_nombre_snapshot = finalSnapshot;
    if (descripcion_problema) data.descripcion_problema = descripcion_problema;

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
        categorias_repuestos(nombre),
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

// GET /requests/stats (estadísticas del cliente)
const getEstadisticasCliente = async (req, res) => {
  try {
    const clienteId = req.user.id;

    // Obtener solicitudes activas (en_proceso)
    const { data: solicitudesActivas, error: errorActivas } = await supabase
      .from('solicitudes_repuesto')
      .select('id')
      .eq('cliente_id', clienteId)
      .eq('estado', 'en_proceso');

    if (errorActivas) {
      return res.status(400).json({ error: errorActivas.message });
    }

    // Obtener cotizaciones recibidas (contando cotizaciones para todas las solicitudes del cliente)
    const { data: todasSolicitudes, error: errorSolicitudes } = await supabase
      .from('solicitudes_repuesto')
      .select('id, cotizaciones(count)')
      .eq('cliente_id', clienteId);

    if (errorSolicitudes) {
      return res.status(400).json({ error: errorSolicitudes.message });
    }

    let totalCotizaciones = 0;
    if (todasSolicitudes) {
      todasSolicitudes.forEach(solicitud => {
        if (solicitud.cotizaciones && solicitud.cotizaciones.length > 0) {
          totalCotizaciones += solicitud.cotizaciones[0].count || 0;
        }
      });
    }

    // Obtener solicitudes completadas
    const { data: solicitudesCompletadas, error: errorCompletadas } = await supabase
      .from('solicitudes_repuesto')
      .select('id')
      .eq('cliente_id', clienteId)
      .eq('estado', 'completado');

    if (errorCompletadas) {
      return res.status(400).json({ error: errorCompletadas.message });
    }

    // Obtener órdenes de compra del cliente
    const { data: ordenes, error: errorOrdenes } = await supabase
      .from('ordenes_compra')
      .select('id')
      .eq('cliente_id', clienteId);

    if (errorOrdenes) {
      return res.status(400).json({ error: errorOrdenes.message });
    }

    const estadisticas = {
      solicitudes_activas: solicitudesActivas?.length || 0,
      cotizaciones_recibidas: totalCotizaciones,
      solicitudes_en_proceso: solicitudesActivas?.length || 0,
      solicitudes_completadas: solicitudesCompletadas?.length || 0,
      ordenes_realizadas: ordenes?.length || 0
    };

    res.json(estadisticas);
  } catch (error) {
    console.error('Get estadísticas cliente error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /orders (mis órdenes - clientes)
const getMisOrdenes = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;

    let query = supabase
      .from('ordenes_compra')
      .select('*, cotizaciones(*, almacenes(nombre_comercial)), solicitudes_repuesto(pieza_nombre)')
      .eq('cliente_id', req.user.id)
      .order('created_at', { ascending: false });

    // Si el frontend envía parámetros de paginación, aplicamos el rango
    if (!isNaN(page) && !isNaN(limit)) {
      const from = (page - 1) * limit;
      const to = from + limit - 1;
      query = query.range(from, to);
    }

    const { data: ordenes, error } = await query;

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(ordenes || []);
  } catch (error) {
    console.error('Get mis órdenes error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { 
  getMisSolicitudes, 
  getSolicitudesActivas, 
  createSolicitud, 
  getSolicitudPorId,
  getEstadisticasCliente,
  getMisOrdenes
};
