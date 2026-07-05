const supabase = require('../services/supabase');

// GET /marcas
const getMarcas = async (req, res) => {
  try {
    const { data: marcas, error } = await supabase
      .from('marcas_vehiculo')
      .select('id, nombre')
      .order('nombre', { ascending: true });

    if (error) {
      return res.status(500).json({
        exito: false,
        errores: [],
        mensaje: 'Error al obtener marcas'
      });
    }

    res.json({
      exito: true,
      datos: marcas || []
    });
  } catch (error) {
    console.error('Get marcas error:', error);
    res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error interno del servidor'
    });
  }
};

module.exports = { getMarcas };
