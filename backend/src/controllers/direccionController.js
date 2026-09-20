const supabase = require('../services/supabase');
const {
  validationError,
  validationErrors
} = require('../utils/validation');
const {
  GeocodingError,
  validarCoordenadas,
  geocodeDireccion
} = require('../utils/geocoding');

/**
 * Resuelve las coordenadas de una dirección. Prioridad:
 * 1. Coordenadas enviadas por el cliente (GPS del dispositivo, fuente 'gps').
 * 2. Geocodificación server-side del texto de la dirección (fuente 'manual').
 *
 * Devuelve `{ latitude, longitude, coordenadasFuente }` o lanza GeocodingError.
 */
async function resolverCoordenadas({ callePrincipal, calleSecundaria, referencia, latitude, longitude, coordenadasFuente }) {
  const lat = typeof latitude === 'string' ? parseFloat(latitude) : latitude;
  const lon = typeof longitude === 'string' ? parseFloat(longitude) : longitude;

  if (validarCoordenadas(lat, lon)) {
    return {
      latitude: lat,
      longitude: lon,
      coordenadasFuente: coordenadasFuente === 'manual' ? 'manual' : 'gps'
    };
  }

  // Sin coordenadas del dispositivo: única vía de degradación controlada,
  // el backend geocodifica antes de aceptar el registro.
  return geocodeDireccion({ callePrincipal, calleSecundaria, referencia }).then(
    ({ latitude: geoLat, longitude: geoLon }) => ({
      latitude: geoLat,
      longitude: geoLon,
      coordenadasFuente: 'manual'
    })
  );
}

// GET /addresses
const getDirecciones = async (req, res) => {
  try {
    const { data: direcciones, error } = await supabase
      .from('direcciones_entrega')
      .select('*')
      .eq('cliente_id', req.user.id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(direcciones || []);
  } catch (error) {
    console.error('Get direcciones error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /addresses
const createDireccion = async (req, res) => {
  try {
    // 1. Extraemos las variables camelCase que enviará la app de Flutter
    const {
      alias,
      callePrincipal,
      calleSecundaria,
      referencia,
      latitude,
      longitude,
      coordenadasFuente
    } = req.body;

    // 2. Validación de campos obligatorios según el nuevo diseño del formulario
    const errors = [];
    if (!alias || !alias.trim()) {
      errors.push({ field: 'alias', message: 'El alias (ej. Casa) es obligatorio.' });
    }
    if (!callePrincipal || !callePrincipal.trim()) {
      errors.push({ field: 'callePrincipal', message: 'La calle principal es obligatoria.' });
    }
    if (errors.length > 0) {
      return res.status(422).json(validationErrors(errors));
    }

    // 3. Resolver coordenadas: GPS del dispositivo si vienen, o geocodificar
    //    server-side el texto de la dirección (degradación controlada).
    //    Nunca se guarda una dirección sin coordenadas de algún origen.
    let latitud;
    let longitud;
    let fuente;
    try {
      const coords = await resolverCoordenadas({
        callePrincipal: callePrincipal.trim(),
        calleSecundaria,
        referencia,
        latitude,
        longitude,
        coordenadasFuente
      });
      latitud = coords.latitude;
      longitud = coords.longitude;
      fuente = coords.coordenadasFuente;
    } catch (geocodeError) {
      if (geocodeError instanceof GeocodingError) {
        return res.status(422).json(validationError('ubicacion', geocodeError.message));
      }
      throw geocodeError;
    }

    // 4. Insertamos directamente mapeando a las nuevas columnas de Supabase
    const { data: direccion, error } = await supabase
      .from('direcciones_entrega')
      .insert({
        cliente_id: req.user.id,
        alias: alias.trim(),
        calle_principal: callePrincipal.trim(),
        calle_secundaria: calleSecundaria && calleSecundaria.trim().length > 0 ? calleSecundaria.trim() : null,
        referencia: referencia && referencia.trim().length > 0 ? referencia.trim() : null,
        latitude: latitud,
        longitude: longitud,
        coordenadas_fuente: fuente
      })
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(201).json(direccion);
  } catch (error) {
    console.error('Create direccion error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// PUT /addresses/:id
const updateDireccion = async (req, res) => {
  try {
    const { id } = req.params;
    // Capturamos las nuevas variables desde el cuerpo de la petición
    const {
      alias,
      callePrincipal,
      calleSecundaria,
      referencia,
      latitude,
      longitude,
      coordenadasFuente
    } = req.body;

    // Verificar pertenencia del registro (Seguridad)
    const { data: existing, error: checkError } = await supabase
      .from('direcciones_entrega')
      .select('cliente_id, calle_principal, calle_secundaria, referencia, latitude, longitude')
      .eq('id', id)
      .single();

    if (checkError || !existing) {
      return res.status(404).json({ error: 'Address not found' });
    }

    if (existing.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this address' });
    }

    // Construimos el objeto de actualización dinámicamente con los nuevos campos
    const updateData = {};
    const callePrincipalFinal = callePrincipal && callePrincipal.trim().length > 0
      ? callePrincipal.trim()
      : null;
    const calleSecundariaFinal = calleSecundaria !== undefined
      ? (calleSecundaria && calleSecundaria.trim().length > 0 ? calleSecundaria.trim() : null)
      : undefined;
    const referenciaFinal = referencia !== undefined
      ? (referencia && referencia.trim().length > 0 ? referencia.trim() : null)
      : undefined;

    if (alias) updateData.alias = alias.trim();
    if (callePrincipalFinal) updateData.calle_principal = callePrincipalFinal;
    if (calleSecundariaFinal !== undefined) updateData.calle_secundaria = calleSecundariaFinal;
    if (referenciaFinal !== undefined) updateData.referencia = referenciaFinal;

    // Coordenadas: si el cliente envía GPS se usan; si el texto de la
    // dirección cambió y no hay coordenadas, se re-geocodifica server-side
    // para mantener el invariante de "nunca sin coordenadas".
    const lat = typeof latitude === 'string' ? parseFloat(latitude) : latitude;
    const lon = typeof longitude === 'string' ? parseFloat(longitude) : longitude;

    if (validarCoordenadas(lat, lon)) {
      updateData.latitude = lat;
      updateData.longitude = lon;
      updateData.coordenadas_fuente = coordenadasFuente === 'manual' ? 'manual' : 'gps';
    } else if (
      updateData.calle_principal ||
      updateData.calle_secundaria !== undefined ||
      updateData.referencia !== undefined
    ) {
      try {
        const coords = await resolverCoordenadas({
          callePrincipal: callePrincipalFinal || existing.calle_principal,
          calleSecundaria: calleSecundariaFinal !== undefined ? calleSecundariaFinal : existing.calle_secundaria,
          referencia: referenciaFinal !== undefined ? referenciaFinal : existing.referencia
        });
        updateData.latitude = coords.latitude;
        updateData.longitude = coords.longitude;
        updateData.coordenadas_fuente = coords.coordenadasFuente;
      } catch (geocodeError) {
        if (geocodeError instanceof GeocodingError) {
          return res.status(422).json(validationError('ubicacion', geocodeError.message));
        }
        throw geocodeError;
      }
    }

    // Ejecutamos la actualización en la tabla reestructurada
    const { data: direccion, error } = await supabase
      .from('direcciones_entrega')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(direccion);
  } catch (error) {
    console.error('Update direccion error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// DELETE /addresses/:id
const deleteDireccion = async (req, res) => {
  try {
    const { id } = req.params;

    // Verificar pertenencia del registro
    const { data: existing, error: checkError } = await supabase
      .from('direcciones_entrega')
      .select('cliente_id')
      .eq('id', id)
      .single();

    if (checkError || !existing) {
      return res.status(404).json({ error: 'Address not found' });
    }

    if (existing.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this address' });
    }

    const { error } = await supabase
      .from('direcciones_entrega')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(204).send();
  } catch (error) {
    console.error('Delete direccion error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { getDirecciones, createDireccion, updateDireccion, deleteDireccion };