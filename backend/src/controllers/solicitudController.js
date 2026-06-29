const supabase = require('../services/supabase');

// GET /solicitudes (mis solicitudes - clientes)
const getMisSolicitudes = async (req, res) => {
  try {
    const { data: solicitudes, error } = await supabase
      .from('solicitudes_repuesto')
      .select('*, vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))')
      .eq('cliente_id', req.user.id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(solicitudes || []);
  } catch (error) {
    console.error('Get solicitudes error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /solicitudes/activas (para almacenes)
const getSolicitudesActivas = async (req, res) => {
  try {
    const { data: solicitudes, error } = await supabase
      .from('solicitudes_repuesto')
      .select('*, profiles(nombre_completo, email), vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))')
      .eq('estado', 'en_proceso')
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(solicitudes || []);
  } catch (error) {
    console.error('Get solicitudes activas error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /solicitudes
const createSolicitud = async (req, res) => {
  try {
    const { vehiculo_id, pieza_nombre, descripcion, foto_url, vin_busqueda, direccion_entrega_id, es_urgente } = req.body;

    if (!pieza_nombre) {
      return res.status(400).json({ error: 'pieza_nombre is required' });
    }

    const data = {
      cliente_id: req.user.id,
      pieza_nombre,
      estado: 'en_proceso'
    };

    if (vehiculo_id) data.vehiculo_id = vehiculo_id;
    if (descripcion) data.descripcion = descripcion;
    if (foto_url) data.foto_url = foto_url;
    if (vin_busqueda) data.vin_busqueda = vin_busqueda;
    if (direccion_entrega_id) data.direccion_entrega_id = direccion_entrega_id;
    if (es_urgente) data.es_urgente = es_urgente;

    const { data: solicitud, error } = await supabase
      .from('solicitudes_repuesto')
      .insert(data)
      .select('*, vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))')
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(201).json(solicitud);
  } catch (error) {
    console.error('Create solicitud error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /solicitudes/:id
const getSolicitudPorId = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: solicitud, error } = await supabase
      .from('solicitudes_repuesto')
      .select('*, profiles(nombre_completo, email), vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))')
      .eq('id', id)
      .single();

    if (error) {
      return res.status(404).json({ error: 'Solicitud not found' });
    }

    // Verify ownership or warehouse role
    if (req.user.rol !== 'almacen' && solicitud.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json(solicitud);
  } catch (error) {
    console.error('Get solicitud error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { getMisSolicitudes, getSolicitudesActivas, createSolicitud, getSolicitudPorId };
