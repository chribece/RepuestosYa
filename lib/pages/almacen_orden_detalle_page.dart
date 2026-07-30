import 'package:flutter/material.dart';
import '../services/orden_compra_service.dart';

class AlmacenOrdenDetallePage extends StatefulWidget {
  final String ordenId;

  const AlmacenOrdenDetallePage({super.key, required this.ordenId});

  @override
  State<AlmacenOrdenDetallePage> createState() =>
      _AlmacenOrdenDetallePageState();
}

class _AlmacenOrdenDetallePageState extends State<AlmacenOrdenDetallePage> {
  // Configuración de Colores basada en tu JSON de Tailwind
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceVariant = Color(0xFF353534);
  static const Color cardBackground = Color(0xFF1E1E1E);

  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color primary = Color(0xFFFFB5A0);
  static const Color secondary = Color(0xFF9ECAFF);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);

  final OrdenCompraService _ordenService = OrdenCompraService();
  Map<String, dynamic>? _orden;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _cargarOrden();
  }

  Future<void> _cargarOrden() async {
    setState(() => _isLoading = true);
    try {
      final orden = await _ordenService.getOrdenDetalle(widget.ordenId);
      if (mounted) {
        setState(() {
          _orden = orden.toJson();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar la orden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _actualizarEstado(String nuevoEstado) async {
    setState(() => _isUpdating = true);
    try {
      await _ordenService.actualizarEstadoOrden(widget.ordenId, nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isUpdating = false);
        await _cargarOrden();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getEstadoColor(String? estado) {
    switch (estado) {
      case 'pendiente_pago':
        return Colors.orange;
      case 'confirmada':
        return Colors.blue;
      case 'entregada':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoTexto(String? estado) {
    switch (estado) {
      case 'pendiente_pago':
        return 'PENDIENTE DE PAGO';
      case 'confirmada':
        return 'CONFIRMADA';
      case 'entregada':
        return 'ENTREGADA';
      case 'cancelada':
        return 'CANCELADA';
      default:
        return 'DESCONOCIDO';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryContainer),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalle de Orden',
          style: TextStyle(
            color: onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Sora',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryContainer),
            )
          : _orden == null
          ? const Center(
              child: Text(
                'No se pudo cargar la orden',
                style: TextStyle(color: onSurfaceVariant),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado Badge Grande
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: outlineVariant, width: 1),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(
                              _orden?['estado'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: _getEstadoColor(
                                _orden?['estado'],
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _getEstadoTexto(_orden?['estado']),
                            style: TextStyle(
                              color: _getEstadoColor(_orden?['estado']),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Sora',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ID: ${widget.ordenId}',
                          style: const TextStyle(
                            color: onSurfaceVariant,
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Información del Almacén
                  _buildInfoCard(
                    title: 'Almacén',
                    icon: Icons.store,
                    content:
                        _orden?['almacenes']?['nombre_comercial'] ??
                        'No disponible',
                  ),
                  const SizedBox(height: 16),

                  // Información de la Solicitud
                  _buildInfoCard(
                    title: 'ID de Solicitud',
                    icon: Icons.description,
                    content: _orden?['solicitud_id'] ?? 'No disponible',
                  ),
                  const SizedBox(height: 16),

                  // Detalles de la orden
                  if (_orden?['detalles'] != null) ...[
                    _buildDetallesCard(_orden?['detalles']),
                    const SizedBox(height: 16),
                  ],

                  // Fechas
                  _buildInfoCard(
                    title: 'Creada',
                    icon: Icons.calendar_today,
                    content: _formatFecha(_orden?['created_at']),
                  ),
                  const SizedBox(height: 16),

                  // Botones de acción condicionales
                  if (_orden?['estado'] == 'pendiente' ||
                      _orden?['estado'] == 'pendiente_pago')
                    _buildActionButton(
                      label: 'Marcar como Confirmada',
                      color: primaryContainer,
                      onPressed: _isUpdating
                          ? null
                          : () => _actualizarEstado('confirmada'),
                    ),
                  if (_orden?['estado'] == 'confirmada')
                    _buildActionButton(
                      label: 'Marcar como Entregada',
                      color: Colors.green,
                      onPressed: _isUpdating
                          ? null
                          : () => _actualizarEstado('entregada'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryContainer, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Sora',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesCard(dynamic detalles) {
    if (detalles == null) return const SizedBox.shrink();

    final Map<String, dynamic> detallesMap = detalles is Map<String, dynamic>
        ? detalles
        : {};

    final precio = detallesMap['precio_venta'];
    final condicion = detallesMap['condicion_repuesto'];
    final tiempoEntrega = detallesMap['tiempo_entrega_estimado'];
    final notas = detallesMap['notas_adicionales'];
    final fotoUrl = detallesMap['foto_evidencia_url'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list, color: primaryContainer, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Detalles',
                style: TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (precio != null) ...[
            _buildDetalleRow(
              icon: Icons.attach_money,
              label: 'Precio',
              value: '\$${precio.toString()}',
            ),
            const SizedBox(height: 12),
          ],
          if (condicion != null) ...[
            _buildDetalleRow(
              icon: Icons.check_circle,
              label: 'Condición',
              value: condicion.toString(),
            ),
            const SizedBox(height: 12),
          ],
          if (tiempoEntrega != null) ...[
            _buildDetalleRow(
              icon: Icons.access_time,
              label: 'Tiempo de entrega',
              value: tiempoEntrega.toString(),
            ),
            const SizedBox(height: 12),
          ],
          if (notas != null && notas.toString().isNotEmpty) ...[
            _buildDetalleRow(
              icon: Icons.note,
              label: 'Notas adicionales',
              value: notas.toString(),
            ),
            const SizedBox(height: 12),
          ],
          if (fotoUrl != null && fotoUrl.toString().isNotEmpty)
            _buildFotoEvidencia(fotoUrl.toString()),
        ],
      ),
    );
  }

  Widget _buildDetalleRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryContainer, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Sora',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFotoEvidencia(String fotoUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.image, color: primaryContainer, size: 18),
            const SizedBox(width: 12),
            const Text(
              'Foto de evidencia',
              style: TextStyle(
                color: onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: outlineVariant, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fotoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        color: onSurfaceVariant,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No se pudo cargar la imagen',
                        style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: primaryContainer),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: color.withOpacity(0.5),
        ),
        child: _isUpdating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora',
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return 'No disponible';
    try {
      final dateTime = DateTime.parse(fecha);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'No disponible';
    }
  }
}
