const adminService = require('../services/adminService');

const getDashboardMetricsController = async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ error: 'Acceso denegado. Solo administradores.' });
    }
    const metrics = await adminService.getDashboardMetrics();
    res.json({ success: true, data: metrics });
  } catch (error) {
    console.error('Error en getDashboardMetricsController:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

const getAllOrdenesController = async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ error: 'Acceso denegado' });
    }
    const filtroEstado = req.query.estado || null;
    const ordenes = await adminService.getAllOrdenes(filtroEstado);
    res.json({ success: true, data: ordenes });
  } catch (error) {
    console.error('Error en getAllOrdenesController:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

const getAllUsuariosController = async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ error: 'Acceso denegado' });
    }
    const usuarios = await adminService.getAllUsuarios();
    res.json({ success: true, data: usuarios });
  } catch (error) {
    console.error('Error en getAllUsuariosController:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

const updateUsuarioRolController = async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ error: 'Acceso denegado' });
    }
    const { id } = req.params;
    const { rol } = req.body;
    const usuario = await adminService.updateUsuarioRol(id, rol);
    res.json({ success: true, data: usuario });
  } catch (error) {
    console.error('Error en updateUsuarioRolController:', error);
    res.status(500).json({ error: error.message });
  }
};

const getAlmacenesPendientesController = async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ error: 'Acceso denegado' });
    }
    const almacenes = await adminService.getAlmacenesPendientes();
    res.json({ success: true, data: almacenes });
  } catch (error) {
    console.error('Error en getAlmacenesPendientesController:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

const actualizarEstadoAlmacenController = async (req, res) => {
  try {
    if (req.user.rol !== 'admin') {
      return res.status(403).json({ error: 'Acceso denegado' });
    }
    const { id } = req.params;
    const { verificado } = req.body;
    const almacen = await adminService.actualizarEstadoAlmacen(id, verificado);
    res.json({ success: true, data: almacen });
  } catch (error) {
    console.error('Error en actualizarEstadoAlmacenController:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getDashboardMetricsController,
  getAllOrdenesController,
  getAllUsuariosController,
  updateUsuarioRolController,
  getAlmacenesPendientesController,
  actualizarEstadoAlmacenController
};
