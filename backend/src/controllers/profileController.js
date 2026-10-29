const supabase = require('../services/supabase');
const { normalizarTelefono } = require('../utils/phone');

// GET /profile
const getProfile = async (req, res) => {
  try {
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', req.user.id)
      .maybeSingle();

    if (error) {
      console.error('Profile fetch error:', error);
      return res.status(404).json({ error: 'Profile not found' });
    }

    if (!profile) {
      console.log('Profile not found for ID:', req.user.id);
      return res.status(404).json({ error: 'Profile not found' });
    }

    res.json(profile);
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// PUT /profile
const updateProfile = async (req, res) => {
  try {
    const { nombre_completo, avatar_url } = req.body;
    // El teléfono se normaliza a dígitos (el usuario puede escribir
    // "+593 99...", espacios o guiones); coherente con el CHECK de la base.
    const telefono = normalizarTelefono(req.body.telefono);

    const { data: profile, error } = await supabase
      .from('profiles')
      .update({
        nombre_completo,
        telefono,
        avatar_url,
        updated_at: new Date().toISOString()
      })
      .eq('id', req.user.id)
      .select()
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(profile);
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// PUT /profile/phone - Teléfono local obligatorio durante el alta con Google.
const updatePhone = async (req, res) => {
  try {
    const telefono = normalizarTelefono(req.body.telefono);
    if (!telefono || !/^09\d{8}$/.test(telefono)) {
      return res.status(400).json({
        error: 'Ingresa un celular ecuatoriano de 10 dígitos que comience con 09'
      });
    }

    const { data: profile, error } = await supabase
      .from('profiles')
      .update({
        telefono,
        updated_at: new Date().toISOString()
      })
      .eq('id', req.user.id)
      .select('id, telefono')
      .maybeSingle();

    if (error) {
      console.error('Profile phone update error:', error.message);
      return res.status(400).json({ error: 'No se pudo guardar el teléfono' });
    }
    if (!profile) {
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    return res.json(profile);
  } catch (error) {
    console.error('Profile phone update error:', error.message);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = { getProfile, updateProfile, updatePhone };
