const supabase = require('./supabase');
const { crearNotificacion } = require('./notificacionService');

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

    // Almacenes activos (aprobados)
    const { count: almacenesActivos, error: error4 } = await supabase
      .from('almacenes')
      .select('*', { count: 'exact', head: true })
      .eq('verification_status', 'approved');
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

const getAlmacenesPorEstado = async (estado = 'pending') => {
  try {
    let query = supabase
      .from('almacenes')
      .select(`
        *,
        profiles!almacenes_encargado_id_fkey(nombre_completo, email)
      `)
      .order('created_at', { ascending: false });
    if (estado !== 'all') query = query.eq('verification_status', estado);
    const { data, error } = await query;
    if (error) throw new Error(error.message);
    return data || [];
  } catch (error) {
    console.error('Error en getAlmacenesPorEstado:', error);
    throw error;
  }
};

// Aviso in-app al encargado solo cuando el estado de verificación cambia a
// aprobado o rechazado. crearNotificacion nunca lanza error: no afecta a la
// verificación ya guardada.
const notificarCambioVerificacion = (almacen, status, rejectionReason) => {
  if (!almacen.encargado_id) return null;
  if (status === 'approved') {
    return crearNotificacion({
      userId: almacen.encargado_id,
      tipo: 'store_approved',
      titulo: '¡Tu establecimiento ha sido aprobado!',
      mensaje: 'Ya puedes visualizar solicitudes de clientes y enviar cotizaciones en RepuestosYa.',
      payload: { almacen_id: almacen.id },
    });
  }
  const motivo = rejectionReason ? ` Motivo: ${rejectionReason}` : '';
  return crearNotificacion({
    userId: almacen.encargado_id,
    tipo: 'store_rejected',
    titulo: 'Actualización sobre tu solicitud de registro',
    mensaje: `Tu establecimiento no pudo ser verificado. Revisa tus datos en Mi Local o contáctanos para más detalles.${motivo}`,
    payload: { almacen_id: almacen.id, motivo: rejectionReason ?? null },
  });
};

const actualizarEstadoAlmacen = async (almacenId, status, rejectionReason = null) => {
  try {
    const { data: previo, error: previoError } = await supabase
      .from('almacenes')
      .select('verification_status')
      .eq('id', almacenId)
      .single();
    if (previoError) throw new Error(previoError.message);

    const updateData = { 
      verification_status: status,
      verificado: status === 'approved' 
    };
    if (rejectionReason !== null) {
      updateData.rejection_reason = rejectionReason;
    }
    const { data, error } = await supabase
      .from('almacenes')
      .update(updateData)
      .eq('id', almacenId)
      .select()
      .single();
    if (error) throw new Error(error.message);

    if (previo.verification_status !== status && ['approved', 'rejected'].includes(status)) {
      await notificarCambioVerificacion(data, status, rejectionReason);
    }
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
  getAlmacenesPorEstado,
  actualizarEstadoAlmacen
};
