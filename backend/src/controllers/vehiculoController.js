const supabase = require('../services/supabase');

// GET /vehiculos
const getVehiculos = async (req, res) => {
  try {
    const { data: vehiculos, error } = await supabase
      .from('vehiculos_cliente')
      .select('*, modelos_vehiculo(*, marcas_vehiculo(*))')
      .eq('cliente_id', req.user.id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(vehiculos || []);
  } catch (error) {
    console.error('Get vehiculos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /vehiculos
const createVehiculo = async (req, res) => {
  try {
    const { modelo_id, anio, vin } = req.body;

    if (!modelo_id || !anio) {
      return res.status(400).json({ error: 'modelo_id and anio are required' });
    }

    const { data: vehiculo, error } = await supabase
      .from('vehiculos_cliente')
      .insert({
        cliente_id: req.user.id,
        modelo_id,
        anio,
        vin
      })
      .select('*, modelos_vehiculo(*, marcas_vehiculo(*))')
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(201).json(vehiculo);
  } catch (error) {
    console.error('Create vehiculo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// PUT /vehiculos/:id
const updateVehiculo = async (req, res) => {
  try {
    const { id } = req.params;
    const { modelo_id, anio, vin } = req.body;

    // Verify ownership
    const { data: existing, error: checkError } = await supabase
      .from('vehiculos_cliente')
      .select('cliente_id')
      .eq('id', id)
      .single();

    if (checkError || !existing) {
      return res.status(404).json({ error: 'Vehicle not found' });
    }

    if (existing.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this vehicle' });
    }

    const { data: vehiculo, error } = await supabase
      .from('vehiculos_cliente')
      .update({
        modelo_id,
        anio,
        vin,
        updated_at: new Date().toISOString()
      })
      .eq('id', id)
      .select('*, modelos_vehiculo(*, marcas_vehiculo(*))')
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(vehiculo);
  } catch (error) {
    console.error('Update vehiculo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// DELETE /vehiculos/:id
const deleteVehiculo = async (req, res) => {
  try {
    const { id } = req.params;

    // Verify ownership
    const { data: existing, error: checkError } = await supabase
      .from('vehiculos_cliente')
      .select('cliente_id')
      .eq('id', id)
      .single();

    if (checkError || !existing) {
      return res.status(404).json({ error: 'Vehicle not found' });
    }

    if (existing.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this vehicle' });
    }

    const { error } = await supabase
      .from('vehiculos_cliente')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(204).send();
  } catch (error) {
    console.error('Delete vehiculo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { getVehiculos, createVehiculo, updateVehiculo, deleteVehiculo };
