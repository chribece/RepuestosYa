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

// Auth routes (public)
router.post('/auth/register', authController.register);
router.post('/auth/login', authController.login);
router.post('/auth/logout', auth, authController.logout);

// Profile routes (protected)
router.get('/profile', auth, profileController.getProfile);
router.put('/profile', auth, profileController.updateProfile);

// Vehiculo routes (protected)
router.get('/vehiculos', auth, vehiculoController.getVehiculos);
router.post('/vehiculos', auth, vehiculoController.createVehiculo);
router.put('/vehiculos/:id', auth, vehiculoController.updateVehiculo);
router.delete('/vehiculos/:id', auth, vehiculoController.deleteVehiculo);

// Marca routes (public - catálogo)
router.get('/marcas', marcaController.getMarcas);

// Modelo routes (public - catálogo con filtro)
router.get('/modelos', modeloController.getModelos);

// Direccion routes (protected)
router.get('/direcciones', auth, direccionController.getDirecciones);
router.post('/direcciones', auth, direccionController.createDireccion);
router.put('/direcciones/:id', auth, direccionController.updateDireccion);
router.delete('/direcciones/:id', auth, direccionController.deleteDireccion);

// Almacen routes (protected)
router.post('/almacenes', auth, requireRole('almacen'), almacenController.createAlmacen);
router.get('/almacenes/encargado/:encargadoId', auth, almacenController.getAlmacenByEncargado);
router.put('/almacenes/:id', auth, requireRole('almacen'), almacenController.updateAlmacen);
router.get('/almacen/mi-almacen', auth, requireRole('almacen'), cotizacionController.getMiAlmacen);

// Solicitud routes (protected)
router.get('/solicitudes', auth, solicitudController.getMisSolicitudes);
router.get('/solicitudes/activas', auth, requireRole('almacen'), solicitudController.getSolicitudesActivas);
router.post('/solicitudes', auth, solicitudController.createSolicitud);
router.get('/solicitudes/:id', auth, solicitudController.getSolicitudPorId);

// Cotizacion routes (protected)
router.post('/cotizaciones', auth, requireRole('almacen'), cotizacionController.createCotizacion);
router.get('/cotizaciones/mis-cotizaciones', auth, requireRole('almacen'), cotizacionController.getMisCotizaciones);
router.get('/cotizaciones/solicitud/:solicitud_id', auth, cotizacionController.getCotizacionesPorSolicitud);
router.put('/cotizaciones/:id/estado', auth, cotizacionController.updateCotizacionEstado);

module.exports = router;
