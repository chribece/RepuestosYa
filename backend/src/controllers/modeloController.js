const supabase = require('../services/supabase');

// GET /models?marcaId={id}
const getModelos = async (req, res) => {
  try {
    const { marcaId } = req.query;

    if (!marcaId) {
      return res.status(400).json({
        exito: false,
        errores: [
          { campo: 'marcaId', mensaje: 'El parámetro marcaId es requerido' }
        ],
        mensaje: 'Datos de entrada inválidos'
      });
    }

    // Validar que marcaId sea un número
    const marcaIdNum = parseInt(marcaId);
    if (isNaN(marcaIdNum) || marcaIdNum <= 0) {
      return res.status(400).json({
        exito: false,
        errores: [
          { campo: 'marcaId', mensaje: 'marcaId debe ser un número entero positivo' }
        ],
        mensaje: 'Datos de entrada inválidos'
      });
    }

    // Verificar que la marca existe
    const { data: marca, error: marcaError } = await supabase
      .from('marcas_vehiculo')
      .select('id')
      .eq('id', marcaIdNum)
      .single();

    if (marcaError || !marca) {
      return res.status(404).json({
        exito: false,
        errores: [],
        mensaje: 'Marca no encontrada'
      });
    }

    // Obtener modelos de la marca
    const { data: modelos, error } = await supabase
      .from('modelos_vehiculo')
      .select('id, nombre, marca_id')
      .eq('marca_id', marcaIdNum)
      .order('nombre', { ascending: true });

    if (error) {
      return res.status(500).json({
        exito: false,
        errores: [],
        mensaje: 'Error al obtener modelos'
      });
    }

    res.json({
      exito: true,
      datos: modelos || []
    });
  } catch (error) {
    console.error('Get modelos error:', error);
    res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error interno del servidor'
    });
  }
};

module.exports = { getModelos };
