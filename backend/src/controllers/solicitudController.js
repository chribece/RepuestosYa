const supabase = require('../services/supabase');
const { getOrSet, invalidatePattern } = require('../services/cache');
const {
  validationError,
  validationErrors,
  validateImageUrl
} = require('../utils/validation');
const {
  GeocodingError,
  validarCoordenadas,
  geocodeDireccion
} = require('../utils/geocoding');

// Shape de respuesta con las relaciones que necesita el cliente.
// Incluye direcciones_entrega (texto y coordenadas) para que el almacén
// pueda ubicar el punto de entrega al cotizar. Requiere la FK
// solicitudes_repuesto.direccion_entrega_id -> direcciones_entrega.id
// (recreada por la migración 20260919_fix_fk_direccion_entrega.sql; sin
// ella PostgREST falla con 400 "Could not find a relationship...").
const SOLICITUD_SELECT = '*, direcciones_entrega(*), vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))';

/**
 * Convierte un valor a número SOLO si representa una coordenada real.
 * `null`, `undefined`, `NaN`, `''` y strings no numéricos → `null`
 * (ausente). NUNCA convierte `null` en `0` (corrige el escape (0,0) por el
 * que una dirección legacy sin coordenadas se insertaba como ubicación
 * real). Exportado para pruebas.
 */
function coordsANumero(valor) {
  if (valor === null || valor === undefined) return null;
  if (typeof valor === 'string') {
    const trim = valor.trim();
    if (trim === '') return null;
    const n = parseFloat(trim);
    return Number.isNaN(n) ? null : n;
  }
  if (typeof valor !== 'number') return null;
  if (Number.isNaN(valor)) return null;
  return Number.isFinite(valor) ? valor : null;
}

/**
 * Resuelve las coordenadas de entrega de una solicitud. Prioridad:
 * 1. Coordenadas GPS enviadas por el cliente (fuente 'gps').
 * 2. Coordenadas ya registradas en la dirección seleccionada.
 * 3. Geocodificación server-side del texto de la dirección (fuente 'manual'):
 *    única vía de degradación controlada cuando el GPS está inoperable.
 *
 * Si el cliente aporta coordenadas GPS frescas, la dirección se actualiza
 * para que queden registradas (las futuras solicitudes las reutilizan).
 *
 * Invariante: NUNCA devuelve (0,0) ni coordenadas sin confirmar; si no hay
 * coordenadas reales de ningún origen, lanza GeocodingError (el controlador
 * responde 422). `coordenadasResueltas: true` marca que las coordenadas
 * vienen de una fuente real (GPS, dirección registrada o geocodificación).
 *
 * @returns {Promise<{latitude: number, longitude: number, coordenadasFuente: string, coordenadasResueltas: boolean}>}
 */
async function resolverCoordenadasEntrega({ direccion, latitude, longitude, coordenadasFuente, supabase }) {
  const lat = coordsANumero(latitude);
  const lon = coordsANumero(longitude);

  // (0,0) no es una ubicación real (Golfo de Guinea): se trata como ausente.
  if (validarCoordenadas(lat, lon) && !(lat === 0 && lon === 0)) {
    const fuente = coordenadasFuente === 'manual' ? 'manual' : 'gps';
    // Persistir las coordenadas GPS en la dirección (mejora datos futuros).
    if (direccion && direccion.id && (direccion.latitude === null || direccion.longitude === null)) {
      await supabase
        .from('direcciones_entrega')
        .update({ latitude: lat, longitude: lon, coordenadas_fuente: fuente })
        .eq('id', direccion.id);
    }
    return { latitude: lat, longitude: lon, coordenadasFuente: fuente, coordenadasResueltas: true };
  }

  // Coordenadas ya registradas en la dirección: validar ausencia real
  // (null/undefined/NaN/'' → ausente, NUNCA cero).
  const dirLat = coordsANumero(direccion && direccion.latitude);
  const dirLon = coordsANumero(direccion && direccion.longitude);
  if (direccion && validarCoordenadas(dirLat, dirLon) && !(dirLat === 0 && dirLon === 0)) {
    return {
      latitude: dirLat,
      longitude: dirLon,
      coordenadasFuente: direccion.coordenadas_fuente || 'manual',
      coordenadasResueltas: true
    };
  }

  // Degradación controlada: geocodificar el texto de la dirección.
  const geocodificada = await geocodeDireccion({
    callePrincipal: direccion.calle_principal,
    calleSecundaria: direccion.calle_secundaria,
    referencia: direccion.referencia
  });

  // Persistir las coordenadas en la dirección para no geocodificar de nuevo.
  if (direccion && direccion.id) {
    await supabase
      .from('direcciones_entrega')
      .update({
        latitude: geocodificada.latitude,
        longitude: geocodificada.longitude,
        coordenadas_fuente: 'manual'
      })
      .eq('id', direccion.id);
  }

  return {
    latitude: geocodificada.latitude,
    longitude: geocodificada.longitude,
    coordenadasFuente: 'manual',
    coordenadasResueltas: true
  };
}

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
      .select('id, verification_status')
      .eq('encargado_id', req.user.id)
      .single();

    if (almacenError || !almacen) {
      return res.status(404).json({ error: 'Warehouse not found for this user' });
    }

    // Bloquear si el almacén no está aprobado
    if (almacen.verification_status !== 'approved') {
      return res.status(403).json({ 
        code: 'WAREHOUSE_NOT_APPROVED',
        message: 'Tu almacén aún no ha sido aprobado para recibir solicitudes.' 
      });
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
            direcciones_entrega(*),
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
      descripcion_problema,
      idempotency_key,
      latitude,
      longitude,
      coordenadas_fuente
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

    // 1b. Validar la URL de la foto (si se envía): debe pertenecer al Storage
    // del proyecto y el objeto debe existir con Content-Type image/* y
    // tamaño <= 10 MB. Errores normalizados 422 como el resto del contrato.
    if (foto_url) {
      const imageCheck = await validateImageUrl(foto_url);
      if (!imageCheck.valid) {
        return res.status(422).json(validationError('foto_url', imageCheck.message));
      }
    }

    // 1c. Idempotencia (Outbox): si la key ya fue procesada, devolver el
    // registro existente en lugar de crear uno nuevo (idempotent replay).
    if (idempotency_key) {
      const { data: existing, error: existingError } = await supabase
        .from('solicitudes_repuesto')
        .select(SOLICITUD_SELECT)
        .eq('idempotency_key', idempotency_key)
        .maybeSingle();

      if (!existingError && existing) {
        return res.status(200).json(existing);
      }
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

    // 2b. UBICACIÓN OBLIGATORIA: toda solicitud necesita coordenadas de
    // entrega verificables (GPS del dispositivo o geocodificación server-side
    // de la dirección). Sin coordenadas confiables el almacén no puede
    // calcular tiempos/costos de despacho ni el cliente validar el radio del
    // almacén sugerido; nunca se guarda una solicitud sin ellas.
    const { data: direccion, error: direccionError } = await supabase
      .from('direcciones_entrega')
      .select('id, cliente_id, calle_principal, calle_secundaria, referencia, latitude, longitude, coordenadas_fuente')
      .eq('id', direccion_entrega_id)
      .maybeSingle();

    if (direccionError || !direccion) {
      return res.status(422).json(validationError('direccion_entrega_id', 'La dirección seleccionada no es válida. Selecciona una dirección registrada.'));
    }

    if (direccion.cliente_id !== req.user.id) {
      return res.status(422).json(validationError('direccion_entrega_id', 'La dirección seleccionada no te pertenece. Selecciona una de tus direcciones.'));
    }

    let latitudEntrega;
    let longitudEntrega;
    let fuenteCoordenadas;
    let coordenadasResueltas = false;
    try {
      const coords = await resolverCoordenadasEntrega({
        direccion,
        latitude,
        longitude,
        coordenadasFuente: coordenadas_fuente,
        supabase
      });
      latitudEntrega = coords.latitude;
      longitudEntrega = coords.longitude;
      fuenteCoordenadas = coords.coordenadasFuente;
      coordenadasResueltas = coords.coordenadasResueltas === true;
    } catch (ubicacionError) {
      if (ubicacionError instanceof GeocodingError) {
        // Contracto 422: field 'ubicacion' (fuera de Quito / no resuelta)
        return res.status(422).json(validationError('ubicacion', ubicacionError.message));
      }
      throw ubicacionError;
    }

    // Guardia de defensa en profundidad (justo antes del INSERT): nunca
    // persistir (0,0) ni coordenadas no confirmadas por una fuente real.
    // El resolver ya no produce (0,0), pero esta validación impide que el
    // bug se reintroduzca silenciosamente en el futuro.
    if (!coordenadasResueltas || (latitudEntrega === 0 && longitudEntrega === 0)) {
      return res.status(422).json(validationError('ubicacion', 'No pudimos verificar la ubicación de entrega. Activa el GPS o corrige la dirección para continuar.'));
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
      descripcion_problema,
      // Snapshot de coordenadas de entrega (estable ante ediciones futuras)
      latitud_entrega: latitudEntrega,
      longitud_entrega: longitudEntrega,
      coordenadas_fuente: fuenteCoordenadas
    };

    if (idempotency_key) {
      data.idempotency_key = idempotency_key;
    }

    // 4. Inserción con manejo de errores de base de datos (422 si es FK violation)
    const { data: solicitud, error } = await supabase
      .from('solicitudes_repuesto')
      .insert(data)
      .select(SOLICITUD_SELECT)
      .single();

    if (error) {
      // Idempotencia: si otro intento con la misma key ya insertó el registro
      // (carrera entre reintentos), devolver el existente en lugar de fallar.
      if (error.code === '23505' && idempotency_key) {
        const { data: existing } = await supabase
          .from('solicitudes_repuesto')
          .select(SOLICITUD_SELECT)
          .eq('idempotency_key', idempotency_key)
          .maybeSingle();

        if (existing) {
          return res.status(200).json(existing);
        }
      }

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
  getMisOrdenes,
  // Exportados para pruebas unitarias (scripts/test_resolver.js)
  resolverCoordenadasEntrega,
  coordsANumero
};
