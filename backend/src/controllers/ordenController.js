const { getOrdenDetalle, NotFoundError, ForbiddenError, BadRequestError } = require('../services/ordenService');

const getOrdenDetalleController = async (req, res) => {
  try {
    const { id } = req.params;
    const clienteAutenticadoId = req.user.id;

    // Validar UUID con regex estricto
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      return res.status(400).json({ error: 'ID de orden inválido' });
    }

    const orden = await getOrdenDetalle(id, clienteAutenticadoId);

    res.status(200).json({
      success: true,
      data: orden
    });
  } catch (error) {
    if (error instanceof NotFoundError) {
      return res.status(404).json({ error: error.message });
    }
    if (error instanceof ForbiddenError) {
      return res.status(403).json({ error: error.message });
    }
    if (error instanceof BadRequestError) {
      return res.status(400).json({ error: error.message });
    }
    console.error('Get orden detalle error:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  getOrdenDetalleController
};
