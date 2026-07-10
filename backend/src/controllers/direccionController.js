const supabase = require('../services/supabase');

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
    const { alias, callePrincipal, calleSecundaria, referencia } = req.body;

    // 2. Validación de campos obligatorios según el nuevo diseño del formulario
    if (!alias || !callePrincipal) {
      return res.status(400).json({ 
        error: 'El alias (ej. Casa) y la calle principal son obligatorios.' 
      });
    }

    // 3. Insertamos directamente mapeando a las nuevas columnas de Supabase
    const { data: direccion, error } = await supabase
      .from('direcciones_entrega')
      .insert({
        cliente_id: req.user.id,
        alias: alias.trim(),
        calle_principal: callePrincipal.trim(),
        calle_secundaria: calleSecundaria && calleSecundaria.trim().length > 0 ? calleSecundaria.trim() : null,
        referencia: referencia && referencia.trim().length > 0 ? referencia.trim() : null
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
    const { alias, callePrincipal, calleSecundaria, referencia } = req.body;

    // Verificar pertenencia del registro (Seguridad)
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

    // Construimos el objeto de actualización dinámicamente con los nuevos campos
    const updateData = {};
    if (alias) updateData.alias = alias.trim();
    if (callePrincipal) updateData.calle_principal = callePrincipal.trim();
    
    // Permitir limpiar o modificar campos opcionales
    if (calleSecundaria !== undefined) {
      updateData.calle_secundaria = calleSecundaria && calleSecundaria.trim().length > 0 ? calleSecundaria.trim() : null;
    }
    if (referencia !== undefined) {
      updateData.referencia = referencia && referencia.trim().length > 0 ? referencia.trim() : null;
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