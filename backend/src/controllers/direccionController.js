const supabase = require('../services/supabase');

// GET /direcciones
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

// POST /direcciones
const createDireccion = async (req, res) => {
  try {
    const { nombre_ubicacion, direccion_texto, latitude, longitude } = req.body;

    if (!nombre_ubicacion || !direccion_texto) {
      return res.status(400).json({ error: 'nombre_ubicacion and direccion_texto are required' });
    }

    const { data: direccion, error } = await supabase
      .from('direcciones_entrega')
      .insert({
        cliente_id: req.user.id,
        nombre_ubicacion,
        direccion_texto,
        latitude,
        longitude
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

// PUT /direcciones/:id
const updateDireccion = async (req, res) => {
  try {
    const { id } = req.params;
    const { nombre_ubicacion, direccion_texto, latitude, longitude } = req.body;

    // Verify ownership
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

    const { data: direccion, error } = await supabase
      .from('direcciones_entrega')
      .update({
        nombre_ubicacion,
        direccion_texto,
        latitude,
        longitude,
        updated_at: new Date().toISOString()
      })
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

// DELETE /direcciones/:id
const deleteDireccion = async (req, res) => {
  try {
    const { id } = req.params;

    // Verify ownership
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
