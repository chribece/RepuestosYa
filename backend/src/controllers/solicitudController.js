const supabase = require('../services/supabase');
const { getOrSet, invalidatePattern } = require('../services/cache');

// Helpers para normalización de errores de validación (422)
const validationError = (field, message) => ({
  message: 'Errores de validación',
  errors: [{ field, message }]
});

const validationErrors = (errors) => ({
  message: 'Errores de validación',
  errors
});

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

    const errors = [];

    // 1. Validaciones de presencia (Contrato legacy + normalizado)
    if (!pieza_nombre && !repuesto_nombre_snapshot) {
      errors.push({
        field: "repuesto_nombre_snapshot",
        message: "Debes indicar el nombre del repuesto o seleccionar uno del catálogo."
      });
    }

    if (!vehiculo_id) {
      errors.push({
        field: "vehiculo_id",
        message: "El vehículo seleccionado no es válido. Selecciona un vehículo de tu garaje."
      });
    }

    if (!direccion_entrega_id) {
      errors.push({
        field: "direccion_entrega_id",
        message: "La dirección seleccionada no es válida. Selecciona una dirección registrada."
      });
    }

    if (!categoria_id) {
      errors.push({
        field: "categoria_id",
        message: "La categoría seleccionada no es válida. Selecciona una categoría del catálogo."
      });
    }

    if (!repuesto_id) {
      errors.push({
        field: "repuesto_id",
        message: "El repuesto seleccionado no es válido. Selecciona un repuesto del catálogo."
      });
    }

    if (descripcion_problema && descripcion_problema.length < 10) {
      errors.push({
        field: "descripcion_problema",
        message: "La descripción del problema debe tener al menos 10 caracteres."
      });
    }

    if (errors.length > 0) {
      return res.status(422).json(validationErrors(errors));
    }

    // 2. Validar que el repuesto exista, esté activo y pertenezca a la categoría
    const { data: repuesto, error: repuestoError } = await supabase
      .from('repuestos_catalogo')
      .select('nombre, categoria_id, activo')
      .eq('id', repuesto_id)
      .single();

    if (repuestoError || !repuesto) {
      return res.status(422).json(validationError('repuesto_id', 'El repuesto seleccionado no existe en nuestro catálogo.'));
    }

    if (!repuesto.activo) {
      return res.status(422).json(validationError('repuesto_id', 'Este repuesto no está disponible actualmente en el catálogo.'));
    }

    if (categoria_id && repuesto.categoria_id !== categoria_id) {
      return res.status(422).json(validationError('categoria_id', 'El repuesto seleccionado no pertenece a la categoría indicada.'));
    }

    // 3. Preparar datos para inserción
    let finalPiezaNombre = pieza_nombre || repuesto.nombre;
    let finalSnapshot = repuesto_nombre_snapshot || repuesto.nombre;

    const data = {
      cliente_id: req.user.id,
      pieza_nombre: finalPiezaNombre,
      estado: 'en_proceso',
      vehiculo_id,
      descripcion,
      foto_url,
      vin_busqueda,
      direccion_entrega_id,
      es_urgente: !!es_urgente,
      categoria_id,
      repuesto_id,
      repuesto_nombre_snapshot: finalSnapshot,
      descripcion_problema
    };

    // 4. Inserción con manejo de errores de base de datos (422 si es FK violation)
    const { data: solicitud, error } = await supabase
      .from('solicitudes_repuesto')
      .insert(data)
      .select('*, vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))')
      .single();

    if (error) {
      // Manejo específico de errores de integridad referencial
      if (error.code === '23503') {
        if (error.message.includes('vehiculo_id')) {
          return res.status(422).json(validationError('vehiculo_id', 'El vehículo seleccionado no es válido o no pertenece a tu cuenta.'));
        }
        if (error.message.includes('direccion_entrega_id')) {
          return res.status(422).json(validationError('direccion_entrega_id', 'La dirección seleccionada no es válida.'));
        }
        if (error.message.includes('categoria_id')) {
          return res.status(422).json(validationError('categoria_id', 'La categoría seleccionada no es válida.'));
        }
        if (error.message.includes('repuesto_id')) {
          return res.status(422).json(validationError('repuesto_id', 'El repuesto seleccionado no es válido.'));
        }
      }
      
      // Error de formato UUID
      if (error.code === '22P02') {
        return res.status(422).json({
          message: 'Error de formato en los identificadores',
          errors: [{ field: 'identificador', message: 'Uno de los IDs enviados no tiene el formato correcto (UUID).' }]
        });
      }

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
