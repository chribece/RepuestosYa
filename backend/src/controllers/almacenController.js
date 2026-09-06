const supabase = require('../services/supabase');

// POST /warehouses (crear almacén)
const createAlmacen = async (req, res) => {
  try {
    const { 
      encargado_id, 
      nombre_comercial, 
      ruc, 
      representante_legal, 
      telefono, 
      email, 
      direccion_texto, 
      latitude, 
      longitude 
    } = req.body;

    const required = { encargado_id, nombre_comercial, direccion_texto, ruc, representante_legal, telefono, email };
    const missing = Object.entries(required)
      .filter(([_, value]) => !value)
      .map(([key]) => key);

    if (missing.length > 0) {
      return res.status(400).json({ 
        error: `Missing required fields: ${missing.join(', ')}` 
      });
    }

    // Validar RUC (13 dígitos)
    const normalizedRuc = ruc.toString().trim().replace(/\s+/g, '');
    if (!/^\d{13}$/.test(normalizedRuc)) {
      return res.status(422).json({
        field: 'ruc',
        message: 'El RUC debe tener exactamente 13 dígitos'
      });
    }

    // First, update the user's role to 'almacen' in profiles
    const { error: roleError } = await supabase
      .from('profiles')
      .update({ rol: 'almacen' })
      .eq('id', encargado_id);

    if (roleError) {
      console.error('Error updating user role:', roleError);
      // Continue anyway, as the trigger might handle this
    }

    // Create the warehouse
    const { data: almacen, error } = await supabase
      .from('almacenes')
      .insert({
        encargado_id,
        nombre_comercial,
        ruc,
        representante_legal,
        telefono,
        email,
        direccion_texto,
        latitude: latitude || 0,
        longitude: longitude || 0,
        verificado: false,
        verification_status: 'pending',
        estado_abierto: false
      })
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(201).json(almacen);
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
    const { nombre_comercial, direccion_texto, latitude, longitude, verificado, estado_abierto, telefono, ruc, representante_legal, email } = req.body;

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
    if (direccion_texto !== undefined) updateData.direccion_texto = direccion_texto;
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
    
    if (telefono !== undefined) updateData.telefono = telefono;
    
    if (ruc !== undefined) {
      // Validar RUC (13 dígitos)
      const normalizedRuc = ruc.toString().trim().replace(/\s+/g, '');
      if (!/^\d{13}$/.test(normalizedRuc)) {
        return res.status(422).json({
          field: 'ruc',
          message: 'El RUC debe tener exactamente 13 dígitos'
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
