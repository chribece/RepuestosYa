const supabase = require('../services/supabase');

// GET /vehiculos
const getVehiculos = async (req, res) => {
  try {
    const { data: vehiculos, error } = await supabase
      .from('vehiculos_cliente')
      .select('*, modelos_vehiculo(*, marcas_vehiculo(*))')
      .eq('cliente_id', req.user.id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(vehiculos || []);
  } catch (error) {
    console.error('Get vehiculos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /vehiculos
const createVehiculo = async (req, res) => {
  try {
    const { marcaId, modeloId, anio, vin, patente } = req.body;

    // Validaciones de campos obligatorios
    if (!marcaId || !modeloId) {
      return res.status(400).json({
        exito: false,
        errores: [
          { campo: 'marcaId', mensaje: 'marcaId es requerido' },
          { campo: 'modeloId', mensaje: 'modeloId es requerido' }
        ],
        mensaje: 'Datos de entrada inválidos'
      });
    }

    // Validar que marcaId sea un número entero positivo
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

    // Validar que modeloId sea un número entero positivo
    const modeloIdNum = parseInt(modeloId);
    if (isNaN(modeloIdNum) || modeloIdNum <= 0) {
      return res.status(400).json({
        exito: false,
        errores: [
          { campo: 'modeloId', mensaje: 'modeloId debe ser un número entero positivo' }
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

    // Verificar que el modelo existe
    const { data: modelo, error: modeloError } = await supabase
      .from('modelos_vehiculo')
      .select('id, marca_id')
      .eq('id', modeloIdNum)
      .single();

    if (modeloError || !modelo) {
      return res.status(404).json({
        exito: false,
        errores: [],
        mensaje: 'Modelo no encontrado'
      });
    }

    // Regla de negocio: Verificar que el modelo pertenezca a la marca seleccionada
    if (modelo.marca_id !== marcaIdNum) {
      return res.status(422).json({
        exito: false,
        errores: [
          { campo: 'modeloId', mensaje: 'El modelo no pertenece a la marca seleccionada' }
        ],
        mensaje: 'Inconsistencia de datos: el modelo no corresponde a la marca'
      });
    }

    // MAPEO CORREGIDO: 'patente' de Flutter se almacena en la columna 'placa' de Supabase
    const vehiculoData = {
      cliente_id: req.user.id,
      modelo_id: modeloIdNum,
      anio: anio ? parseInt(anio) : null,
      vin: vin ? vin.trim() : null,
      placa: patente && patente.trim().length > 0 ? patente.trim() : null
    };

    const { data: vehiculo, error } = await supabase
      .from('vehiculos_cliente')
      .insert(vehiculoData)
      .select('*, modelos_vehiculo(*, marcas_vehiculo(*))')
      .single();

    if (error) {
      console.error('Supabase Insert Error:', error);
      return res.status(500).json({
        exito: false,
        errores: [],
        mensaje: 'Error al crear vehículo en la base de datos'
      });
    }

    res.status(201).json({
      exito: true,
      datos: vehiculo,
      mensaje: 'Vehículo creado correctamente'
    });
  } catch (error) {
    console.error('Create vehiculo error:', error);
    res.status(500).json({
      exito: false,
      errores: [],
      mensaje: 'Error interno del servidor'
    });
  }
};

// PUT /vehiculos/:id
const updateVehiculo = async (req, res) => {
  try {
    const { id } = req.params;
    // Captura los datos enviados desde Flutter
    const { modeloId, anio, vin, patente } = req.body;

    // Verificar pertenencia del registro
    const { data: existing, error: checkError } = await supabase
      .from('vehiculos_cliente')
      .select('cliente_id')
      .eq('id', id)
      .single();

    if (checkError || !existing) {
      return res.status(404).json({ error: 'Vehicle not found' });
    }

    if (existing.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this vehicle' });
    }

    const updateData = {
      updated_at: new Date().toISOString()
    };

    if (modeloId) updateData.modelo_id = parseInt(modeloId);
    if (anio) updateData.anio = parseInt(anio);
    if (vin) updateData.vin = vin.trim();
    
    // MAPEO EN EDICIÓN: Guarda 'patente' en el campo 'placa' si se modifica o remueve
    if (patente !== undefined) {
      updateData.placa = patente && patente.trim().length > 0 ? patente.trim() : null;
    }

    const { data: vehiculo, error } = await supabase
      .from('vehiculos_cliente')
      .update(updateData)
      .eq('id', id)
      .select('*, modelos_vehiculo(*, marcas_vehiculo(*))')
      .single();

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.json(vehiculo);
  } catch (error) {
    console.error('Update vehiculo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// DELETE /vehiculos/:id
const deleteVehiculo = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: existing, error: checkError } = await supabase
      .from('vehiculos_cliente')
      .select('cliente_id')
      .eq('id', id)
      .single();

    if (checkError || !existing) {
      return res.status(404).json({ error: 'Vehicle not found' });
    }

    if (existing.cliente_id !== req.user.id) {
      return res.status(403).json({ error: 'You do not own this vehicle' });
    }

    const { error } = await supabase
      .from('vehiculos_cliente')
      .delete()
      .eq('id', id);

    if (error) {
      return res.status(400).json({ error: error.message });
    }

    res.status(204).send();
  } catch (error) {
    console.error('Delete vehiculo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { getVehiculos, createVehiculo, updateVehiculo, deleteVehiculo };