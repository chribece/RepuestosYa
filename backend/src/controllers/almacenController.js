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

    if (!encargado_id || !nombre_comercial || !direccion_texto || !ruc || !representante_legal || !telefono || !email) {
      return res.status(400).json({ 
        error: 'encargado_id, nombre_comercial, direccion_texto, ruc, representante_legal, telefono and email are required' 
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
        estado_abierto: true
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
    const { nombre_comercial, direccion_texto, latitude, longitude, verificado, estado_abierto } = req.body;

    // Verify ownership
    const { data: existing, error: existingError } = await supabase
      .from('almacenes')
      .select('encargado_id')
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
    if (verificado !== undefined) updateData.verificado = verificado;
    if (estado_abierto !== undefined) updateData.estado_abierto = estado_abierto;

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
