const supabase = require('../services/supabase');
const { normalizarTelefono, telefonoValido } = require('../utils/phone');
const { validateImageUrl } = require('../utils/validation');

// POST /warehouses (crear almacén)
const createAlmacen = async (req, res) => {
  try {
    const {
      nombre_comercial,
      tipo_establecimiento,
      city,
      logo_url,
      ruc,
      representante_legal,
      direccion_texto,
      latitude,
      longitude
    } = req.body;
    const encargado_id = req.user?.id;
    const email = req.user?.email;
    const telefono = normalizarTelefono(req.body.telefono);

    if (req.body.encargado_id && req.body.encargado_id !== encargado_id) {
      return res.status(403).json({ error: 'No puedes crear un almacén para otro usuario' });
    }

    const required = {
      encargado_id,
      nombre_comercial,
      direccion_texto,
      ruc,
      representante_legal,
      telefono,
      email
    };
    const missing = Object.entries(required)
      .filter(([_, value]) => !value)
      .map(([key]) => key);

    if (missing.length > 0) {
      return res.status(400).json({
        error: `Missing required fields: ${missing.join(', ')}`
      });
    }

    const normalizedRuc = ruc.toString().trim().replace(/\s+/g, '');
    if (!/^\d{13}$/.test(normalizedRuc)) {
      return res.status(422).json({
        field: 'ruc',
        message: 'El RUC debe tener exactamente 13 dígitos'
      });
    }

    if (!telefonoValido(telefono)) {
      return res.status(422).json({
        field: 'telefono',
        message: 'El teléfono debe tener entre 9 y 15 dígitos'
      });
    }

    const normalizedName = nombre_comercial.trim();
    const normalizedRepresentative = representante_legal.trim();
    const normalizedAddress = direccion_texto.trim();
    const normalizedCity = typeof city === 'string' ? city.trim() : '';
    const normalizedEstablishmentType =
      typeof tipo_establecimiento === 'string'
        ? tipo_establecimiento.trim().toLowerCase()
        : '';
    if (!normalizedName || !normalizedRepresentative || !normalizedAddress) {
      return res.status(400).json({
        error: 'Nombre del establecimiento, representante y dirección son obligatorios'
      });
    }
    if (!normalizedCity) {
      return res.status(422).json({
        field: 'city',
        message: 'La ciudad del establecimiento es obligatoria'
      });
    }
    if (!['matriz', 'sucursal'].includes(normalizedEstablishmentType)) {
      return res.status(422).json({
        field: 'tipo_establecimiento',
        message: 'Selecciona Matriz o Sucursal'
      });
    }
    const logoValidation = await validateImageUrl(logo_url);
    if (!logoValidation.valid) {
      return res.status(422).json({
        field: 'logo_url',
        message: logoValidation.message
      });
    }

    const { data: rucExistente, error: rucError } = await supabase
      .from('almacenes')
      .select('id, encargado_id')
      .eq('ruc', normalizedRuc)
      .maybeSingle();

    if (rucError) {
      return res.status(400).json({ error: rucError.message });
    }
    if (rucExistente && rucExistente.encargado_id !== encargado_id) {
      return res.status(422).json({
        field: 'ruc',
        message: 'El RUC ya está registrado'
      });
    }

    // RPC transactionally updates the account phone/role and inserts its
    // commercial profile, so the two records cannot be left out of sync.
    const { data: almacen, error } = await supabase.rpc(
      'crear_almacen_con_perfil',
      {
        p_encargado_id: encargado_id,
        p_nombre_comercial: normalizedName,
        p_ruc: normalizedRuc,
        p_representante_legal: normalizedRepresentative,
        p_telefono: telefono,
        p_email: email.trim(),
        p_direccion_texto: normalizedAddress,
        p_latitude: Number.isFinite(Number(latitude)) ? Number(latitude) : 0,
        p_longitude: Number.isFinite(Number(longitude)) ? Number(longitude) : 0,
        p_city: normalizedCity,
        p_tipo_establecimiento: normalizedEstablishmentType,
        p_logo_url: logoValidation.value
      }
    );

    if (error) {
      if (error.code === '23505') {
        return res.status(422).json({
          field: 'ruc',
          message: 'El RUC ya está registrado'
        });
      }
      if (error.code === 'P0002') {
        return res.status(404).json({ error: 'Perfil de usuario no encontrado' });
      }
      console.error('Atomic warehouse registration failed:', error.message);
      return res.status(400).json({ error: 'No se pudo guardar el perfil comercial' });
    }

    return res.status(201).json(almacen);
  } catch (error) {
    console.error('Create almacen error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /warehouses/encargado/:encargadoId (obtener almacén por encargado)
const getAlmacenByEncargado = async (req, res) => {
  try {
    const { encargadoId } = req.params;

    const { data: almacen, error } = await supabase
      .from('almacenes')
      .select('*')
      .eq('encargado_id', encargadoId)
      .single();

    if (error || !almacen) {
      return res.status(404).json({ error: 'Warehouse not found' });
    }

    res.json(almacen);
  } catch (error) {
    console.error('Get almacen by encargado error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// PUT /warehouses/:id (actualizar almacén)
const updateAlmacen = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      nombre_comercial,
      tipo_establecimiento,
      city,
      direccion_texto,
      latitude,
      longitude,
      verificado,
      estado_abierto,
      telefono,
      ruc,
      representante_legal,
      email,
      logo_url
    } = req.body;

    // Verify ownership and status
    const { data: existing, error: existingError } = await supabase
      .from('almacenes')
      .select('encargado_id, verification_status')
      .eq('id', id)
      .single();

    if (existingError || !existing) {
      return res.status(404).json({ error: 'Warehouse not found' });
    }

    if (existing.encargado_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this warehouse' });
    }

    const updateData = {};
    if (nombre_comercial !== undefined) updateData.nombre_comercial = nombre_comercial;
    if (city !== undefined) {
      const normalizedCity = typeof city === 'string' ? city.trim() : '';
      if (!normalizedCity) {
        return res.status(422).json({
          field: 'city',
          message: 'La ciudad del establecimiento es obligatoria'
        });
      }
      updateData.city = normalizedCity;
    }
    if (tipo_establecimiento !== undefined) {
      const normalizedType = typeof tipo_establecimiento === 'string'
        ? tipo_establecimiento.trim().toLowerCase()
        : '';
      if (!['matriz', 'sucursal'].includes(normalizedType)) {
        return res.status(422).json({
          field: 'tipo_establecimiento',
          message: 'Selecciona Matriz o Sucursal'
        });
      }
      updateData.tipo_establecimiento = normalizedType;
    }
    if (direccion_texto !== undefined) updateData.direccion_texto = direccion_texto;
    if (logo_url !== undefined) {
      const logoValidation = await validateImageUrl(logo_url);
      if (!logoValidation.valid) {
        return res.status(422).json({
          field: 'logo_url',
          message: logoValidation.message
        });
      }
      updateData.logo_url = logoValidation.value;
    }
    if (latitude !== undefined) updateData.latitude = latitude;
    if (longitude !== undefined) updateData.longitude = longitude;
    
    // verificado y verification_status SOLO pueden ser cambiados por admin
    // a través de adminController.actualizarEstadoAlmacen
    
    if (estado_abierto !== undefined) {
      // Bloquear cambio de estado operativo si no está aprobado
      if (existing.verification_status !== 'approved') {
        return res.status(403).json({ 
          code: 'WAREHOUSE_NOT_APPROVED',
          message: 'No puedes cambiar tu estado operativo hasta que tu almacén sea aprobado.' 
        });
      }
      updateData.estado_abierto = estado_abierto;
    }
    
    if (telefono !== undefined) {
      const telefonoNormalizado = normalizarTelefono(telefono);
      if (telefono !== null && telefono !== '' && !telefonoValido(telefonoNormalizado)) {
        return res.status(422).json({
          field: 'telefono',
          message: 'El teléfono debe tener entre 9 y 15 dígitos'
        });
      }
      updateData.telefono = telefonoNormalizado;
    }
    
    if (ruc !== undefined) {
      // Validar RUC (13 dígitos)
      const normalizedRuc = ruc.toString().trim().replace(/\s+/g, '');
      if (!/^\d{13}$/.test(normalizedRuc)) {
        return res.status(422).json({
          field: 'ruc',
          message: 'El RUC debe tener exactamente 13 dígitos'
        });
      }

      // Unicidad: excluir el almacén actual
      const { data: rucExistente, error: rucError } = await supabase
        .from('almacenes')
        .select('id')
        .eq('ruc', normalizedRuc)
        .neq('id', id)
        .maybeSingle();

      if (rucError) {
        return res.status(400).json({ error: rucError.message });
      }
      if (rucExistente) {
        return res.status(422).json({
          field: 'ruc',
          message: 'El RUC ya está registrado'
        });
      }

      updateData.ruc = normalizedRuc;
    }

    if (representante_legal !== undefined) updateData.representante_legal = representante_legal;
    if (email !== undefined) updateData.email = email;

    const { data: almacen, error } = await supabase
      .from('almacenes')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(almacen);
  } catch (error) {
    console.error('Update almacen error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { createAlmacen, getAlmacenByEncargado, updateAlmacen };
