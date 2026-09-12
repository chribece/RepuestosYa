const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');

// Controllers
const authController = require('../controllers/authController');
const profileController = require('../controllers/profileController');
const vehiculoController = require('../controllers/vehiculoController');
const direccionController = require('../controllers/direccionController');
const solicitudController = require('../controllers/solicitudController');
const cotizacionController = require('../controllers/cotizacionController');
const marcaController = require('../controllers/marcaController');
const modeloController = require('../controllers/modeloController');
const almacenController = require('../controllers/almacenController');
const ordenController = require('../controllers/ordenController');
const adminController = require('../controllers/adminController');
const catalogoController = require('../controllers/catalogoController');

// Auth routes (public)
router.post('/auth/register', authController.register);
router.post('/auth/login', authController.login);
router.post('/auth/refresh', authController.refresh);
router.post('/auth/logout', auth, authController.logout);
router.get('/auth/me', auth, authController.getMe);

// Profile routes (protected)
router.get('/profile', auth, profileController.getProfile);
router.put('/profile', auth, profileController.updateProfile);

// Vehiculo routes (protected)
router.get('/vehicles', auth, vehiculoController.getVehiculos);
router.post('/vehicles', auth, vehiculoController.createVehiculo);
router.put('/vehicles/:id', auth, vehiculoController.updateVehiculo);
router.delete('/vehicles/:id', auth, vehiculoController.deleteVehiculo);

// Marca routes (public - catálogo)
router.get('/brands', marcaController.getMarcas);

// Modelo routes (public - catálogo con filtro)
router.get('/models', modeloController.getModelos);

// Catálogo de repuestos (public/authenticated)
router.get('/catalog/part-categories', catalogoController.getCategorias);
router.get('/catalog/parts', catalogoController.getRepuestos);

// Direccion routes (protected)
router.get('/addresses', auth, direccionController.getDirecciones);
router.post('/addresses', auth, direccionController.createDireccion);
router.put('/addresses/:id', auth, direccionController.updateDireccion);
router.delete('/addresses/:id', auth, direccionController.deleteDireccion);

// Almacen routes (protected)
router.post('/warehouses', auth, almacenController.createAlmacen); // No role requirement for registration
router.get('/warehouses/encargado/:encargadoId', auth, almacenController.getAlmacenByEncargado);
router.put('/warehouses/:id', auth, requireRole('almacen'), almacenController.updateAlmacen);
router.get('/warehouse/my-warehouse', auth, requireRole('almacen'), cotizacionController.getMiAlmacen);

// Solicitud routes (protected)
router.get('/requests', auth, solicitudController.getMisSolicitudes);
router.get('/requests/active', auth, requireRole('almacen'), solicitudController.getSolicitudesActivas);
router.get('/requests/stats', auth, solicitudController.getEstadisticasCliente);
router.post('/requests', auth, solicitudController.createSolicitud);
router.get('/requests/:id', auth, solicitudController.getSolicitudPorId);

// Cotizacion routes (protected)
router.post('/quotations', auth, requireRole('almacen'), cotizacionController.createCotizacion);
router.get('/quotations/my-quotations', auth, requireRole('almacen'), cotizacionController.getMisCotizaciones);
router.get('/quotations/request/:solicitud_id', auth, cotizacionController.getCotizacionesPorSolicitud);
router.put('/quotations/:id/status', auth, cotizacionController.updateCotizacionEstado);
router.post('/quotations/:id/accept', auth, cotizacionController.aceptarCotizacion);
router.post('/quotations/:id/reject', auth, cotizacionController.rechazarCotizacion);

// Orden de compra routes (protected)
router.get('/orders', auth, solicitudController.getMisOrdenes);
router.get('/orders/:id', auth, ordenController.getOrdenDetalleController);
router.patch('/orders/:id/status', auth, requireRole('almacen'), ordenController.updateOrdenEstadoController);

// Admin routes (solo admin)
router.get('/admin/metrics', auth, requireRole('admin'), adminController.getDashboardMetricsController);
router.get('/admin/orders', auth, requireRole('admin'), adminController.getAllOrdenesController);
router.get('/admin/users', auth, requireRole('admin'), adminController.getAllUsuariosController);
router.patch('/admin/users/:id/role', auth, requireRole('admin'), adminController.updateUsuarioRolController);
router.get('/admin/warehouses/pending', auth, requireRole('admin'), adminController.getAlmacenesPendientesController);
router.patch('/admin/warehouses/:id/verify', auth, requireRole('admin'), adminController.actualizarEstadoAlmacenController);

module.exports = router;
