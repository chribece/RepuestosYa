import 'package:supabase_flutter/supabase_flutter.dart';

class SolicitudService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Crear una nueva solicitud de repuesto
  Future<Map<String, dynamic>> crearSolicitud({
    required String clienteId,
    String? vehiculoId,
    required String piezaNombre,
    String? descripcion,
    String? fotoUrl,
    String? vinBusqueda,
    String? direccionEntregaId,
    bool esUrgente = false,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'cliente_id': clienteId,
        'pieza_nombre': piezaNombre,
        'estado': 'en_proceso',
      };

      // Solo agregar campos opcionales si tienen valor
      if (vehiculoId != null) data['vehiculo_id'] = vehiculoId;
      if (descripcion != null && descripcion.isNotEmpty) data['descripcion'] = descripcion;
      if (fotoUrl != null && fotoUrl.isNotEmpty) data['foto_url'] = fotoUrl;
      if (vinBusqueda != null && vinBusqueda.isNotEmpty) data['vin_busqueda'] = vinBusqueda;
      if (direccionEntregaId != null && direccionEntregaId.isNotEmpty) data['direccion_entrega_id'] = direccionEntregaId;
      if (esUrgente) data['es_urgente'] = esUrgente;

      final response = await _supabase.from('solicitudes_repuesto').insert(data).select().single();

      return response;
    } catch (e) {
      throw Exception('Error al crear solicitud: $e');
    }
  }

  // Obtener todas las solicitudes de un cliente
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(String clienteId) async {
    try {
      final response = await _supabase
          .from('solicitudes_repuesto')
          .select('*, vehiculos_cliente(*, modelos_vehiculo(*, marcas_vehiculo(*)))')
          .eq('cliente_id', clienteId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener solicitudes: $e');
    }
  }

  // Obtener una solicitud por ID
  Future<Map<String, dynamic>> obtenerSolicitudPorId(String solicitudId) async {
    try {
      final response = await _supabase
          .from('solicitudes_repuesto')
          .select('*')
          .eq('id', solicitudId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Error al obtener solicitud: $e');
    }
  }
}
