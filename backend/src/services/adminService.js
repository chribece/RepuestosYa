const supabase = require('./supabase');

const getDashboardMetrics = async () => {
  try {
    // Total de órdenes
    const { count: totalOrdenes, error: error1 } = await supabase
      .from('ordenes_compra')
      .select('*', { count: 'exact', head: true });
    if (error1) throw new Error(error1.message);

    // Comisiones totales (5% del monto_total de cada orden)
    const { data: ordenes, error: error2 } = await supabase
      .from('ordenes_compra')
      .select('detalles')
      .eq('estado', 'entregada');
    if (error2) throw new Error(error2.message);
    
    let comisionesTotales = 0;
    (ordenes || []).forEach(orden => {
      const monto = orden.detalles?.precio_venta || 0;
      comisionesTotales += monto * 0.05;
    });

    // Total de usuarios
    const { count: totalUsuarios, error: error3 } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true });
    if (error3) throw new Error(error3.message);

    // Almacenes activos (verificados)
    const { count: almacenesActivos, error: error4 } = await supabase
      .from('almacenes')
      .select('*', { count: 'exact', head: true })
      .eq('verificado', true);
    if (error4) throw new Error(error4.message);

    return {
      totalOrdenes: totalOrdenes || 0,
      comisionesTotales: Math.round(comisionesTotales * 100) / 100,
      totalUsuarios: totalUsuarios || 0,
      almacenesActivos: almacenesActivos || 0
    };
  } catch (error) {
    console.error('Error en getDashboardMetrics:', error);
    throw error;
  }
};

const getAllOrdenes = async (filtroEstado = null) => {
  try {
    let query = supabase
      .from('ordenes_compra')
      .select(`
        *,
        almacenes(nombre_comercial),
        profiles!ordenes_compra_cliente_id_fkey(nombre_completo, email)
      `)
      .order('created_at', { ascending: false });
    
    if (filtroEstado) {
      query = query.eq('estado', filtroEstado);
    }
    
    const { data, error } = await query;
    if (error) throw new Error(error.message);
    return data || [];
  } catch (error) {
    console.error('Error en getAllOrdenes:', error);
    throw error;
  }
};

const getAllUsuarios = async () => {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, nombre_completo, email, telefono, rol, created_at')
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return data || [];
  } catch (error) {
    console.error('Error en getAllUsuarios:', error);
    throw error;
  }
};

const updateUsuarioRol = async (usuarioId, nuevoRol) => {
  try {
    const rolesValidos = ['cliente', 'almacen', 'admin'];
    if (!rolesValidos.includes(nuevoRol)) {
      throw new Error('Rol no válido');
    }
    const { data, error } = await supabase
      .from('profiles')
      .update({ rol: nuevoRol })
      .eq('id', usuarioId)
      .select()
      .single();
    if (error) throw new Error(error.message);
    return data;
  } catch (error) {
    console.error('Error en updateUsuarioRol:', error);
    throw error;
  }
};

const getAlmacenesPendientes = async () => {
  try {
    const { data, error } = await supabase
      .from('almacenes')
      .select(`
        *,
        profiles!almacenes_encargado_id_fkey(nombre_completo, email)
      `)
      .eq('verificado', false)
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return data || [];
  } catch (error) {
    console.error('Error en getAlmacenesPendientes:', error);
    throw error;
  }
};

const actualizarEstadoAlmacen = async (almacenId, verificado) => {
  try {
    const { data, error } = await supabase
      .from('almacenes')
      .update({ verificado: verificado })
      .eq('id', almacenId)
      .select()
      .single();
    if (error) throw new Error(error.message);
    return data;
  } catch (error) {
    console.error('Error en actualizarEstadoAlmacen:', error);
    throw error;
  }
};

module.exports = {
  getDashboardMetrics,
  getAllOrdenes,
  getAllUsuarios,
  updateUsuarioRol,
  getAlmacenesPendientes,
  actualizarEstadoAlmacen
};
