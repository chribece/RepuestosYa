const { getOrdenDetalle, getOrdenDetalleParaAlmacen, updateOrdenEstado, NotFoundError, ForbiddenError, BadRequestError } = require('../services/ordenService');
const supabase = require('../services/supabase');

const getOrdenDetalleController = async (req, res) => {
  try {
    const { id } = req.params;

    // Validar UUID con regex estricto
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      return res.status(400).json({ error: 'ID de orden inválido' });
    }

    let orden;
    if (req.user.rol === 'almacen') {
      // Obtener almacen_id del usuario
      const { data: almacen, error: almacenError } = await supabase
        .from('almacenes')
        .select('id')
        .eq('encargado_id', req.user.id)
        .single();

      if (almacenError || !almacen) {
        return res.status(404).json({ error: 'Almacén no encontrado para este usuario' });
      }

      orden = await getOrdenDetalleParaAlmacen(id, almacen.id);
    } else {
      // Cliente
      orden = await getOrdenDetalle(id, req.user.id);
    }

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

const updateOrdenEstadoController = async (req, res) => {
  try {
    const { id } = req.params;
    const { estado } = req.body;

    // Validar UUID con regex estricto
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      return res.status(400).json({ error: 'ID de orden inválido' });
    }

    // Validar que estado esté presente
    if (!estado) {
      return res.status(400).json({ error: 'El estado es requerido' });
    }

    // Obtener almacen_id del usuario
    const { data: almacen, error: almacenError } = await supabase
      .from('almacenes')
      .select('id, verification_status')
      .eq('encargado_id', req.user.id)
      .single();

    if (almacenError || !almacen) {
      return res.status(404).json({ error: 'Almacén no encontrado para este usuario' });
    }

    // Bloquear si el almacén no está aprobado
    if (almacen.verification_status !== 'approved') {
      return res.status(403).json({ 
        code: 'WAREHOUSE_NOT_APPROVED',
        message: 'Tu almacén aún no ha sido aprobado para gestionar órdenes.' 
      });
    }

    const ordenActualizada = await updateOrdenEstado(id, estado, almacen.id);

    res.status(200).json({
      success: true,
      data: ordenActualizada
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
    console.error('Update orden estado error:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  getOrdenDetalleController,
  updateOrdenEstadoController
};
