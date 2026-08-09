import 'package:flutter/material.dart';
import '../services/solicitud_service.dart';
import '../services/realtime_notification_service.dart';

class ReceivedQuotationsPage extends StatefulWidget {
  final String solicitudId;
  final String piezaNombre;
  final String? fotoUrl;
  final int ofertasPendientes;

  const ReceivedQuotationsPage({
    super.key,
    required this.solicitudId,
    required this.piezaNombre,
    this.fotoUrl,
    this.ofertasPendientes = 0,
  });

  @override
  State<ReceivedQuotationsPage> createState() => _ReceivedQuotationsPageState();
}

class _ReceivedQuotationsPageState extends State<ReceivedQuotationsPage> {
  final SolicitudService _solicitudService = SolicitudService();

  // Paleta de colores industrial oscura
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceVariant = Color(0xFF353534);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color secondary = Color(0xFF9ECAFF);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color cardGradientStart = Color(0xFF1E1E1E);
  static const Color cardGradientEnd = Color(0xFF161616);
  static const Color cardBorder = Color(0xFF333333);

  int _selectedTabIndex = 0;
  List<Map<String, dynamic>> _cotizaciones = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, bool> _loadingCotizaciones = {};

  @override
  void initState() {
    super.initState();
    _cargarCotizaciones();
    RealtimeNotificationService().subscribeToCotizaciones(widget.solicitudId);
  }

  @override
  void dispose() {
    RealtimeNotificationService().unsubscribe();
    super.dispose();
  }

  Future<void> _cargarCotizaciones() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cotizaciones = await _solicitudService.obtenerCotizacionesRecibidas(
        widget.solicitudId,
      );
      setState(() {
        _cotizaciones = _ordenarCotizaciones(cotizaciones, _selectedTabIndex);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar cotizaciones: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _ordenarCotizaciones(
    List<Map<String, dynamic>> cotizaciones,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 0: // Todas
        return cotizaciones;
      case 1: // Más baratas
        final sorted = List<Map<String, dynamic>>.from(cotizaciones);
        sorted.sort(
          (a, b) =>
              (a['precio_venta'] as num).compareTo(b['precio_venta'] as num),
        );
        return sorted;
      case 2: // Más cercanas (simulado por ahora)
        return cotizaciones;
      default:
        return cotizaciones;
    }
  }

  String _formatTiempoEnvio(String? createdAt) {
    if (createdAt == null) return 'Hace un momento';

    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Hace un momento';
      } else if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} h';
      } else {
        return 'Hace ${difference.inDays} días';
      }
    } catch (e) {
      return 'Hace un momento';
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
      _cotizaciones = _ordenarCotizaciones(_cotizaciones, index);
    });
  }

  Future<void> _aceptarCotizacion(String cotizacionId) async {
    setState(() {
      _loadingCotizaciones[cotizacionId] = true;
    });

    try {
      print('Intentando aceptar cotización con ID: $cotizacionId');
      final response = await _solicitudService.aceptarCotizacion(cotizacionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cotización aceptada correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        final ordenId = response['ordenId'] as String?;
        if (ordenId != null) {
          Navigator.of(
            context,
          ).pushReplacementNamed('/orden-compra', arguments: ordenId);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      print('Error al aceptar cotización: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar cotización: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingCotizaciones[cotizacionId] = false;
        });
      }
    }
  }

  Future<void> _rechazarCotizacion(String cotizacionId) async {
    try {
      print('Intentando rechazar cotización con ID: $cotizacionId');
      await _solicitudService.rechazarCotizacion(cotizacionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cotización rechazada'),
            backgroundColor: Colors.orange,
          ),
        );
        _cargarCotizaciones();
      }
    } catch (e) {
      print('Error al rechazar cotización: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al rechazar cotización: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: _buildTopAppBar(),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildTabsBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryContainer),
                  )
                : _errorMessage != null
                ? _buildErrorState()
                : _cotizaciones.isEmpty
                ? _buildEmptyState()
                : _buildQuotationsList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Cotizaciones',
        style: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Row(
        children: [
          // Foto mini del repuesto
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported,
                          color: onSurfaceVariant,
                          size: 32,
                        );
                      },
                    ),
                  )
                : const Icon(Icons.image, color: onSurfaceVariant, size: 32),
          ),
          const SizedBox(width: 16),
          // Información de la pieza
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.piezaNombre,
                  style: const TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.ofertasPendientes} ofertas pendientes',
                  style: const TextStyle(color: secondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsBar() {
    final tabs = ['Todas', 'Más baratas', 'Más cercanas'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: cardBorder, width: 1)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = _selectedTabIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () => _onTabChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? primaryContainer : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? primaryContainer : onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Error desconocido',
              style: const TextStyle(color: onSurface, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarCotizaciones,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryContainer,
                foregroundColor: onPrimaryContainer,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, color: onSurfaceVariant, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No hay cotizaciones aún',
              style: TextStyle(
                color: onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Los almacenes enviarán sus ofertas pronto',
              style: TextStyle(color: onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cotizaciones.length,
      itemBuilder: (context, index) {
        final cotizacion = _cotizaciones[index];
        return _buildQuotationCard(cotizacion);
      },
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> cotizacion) {
    final almacenes = cotizacion['almacenes'] as Map<String, dynamic>?;
    final almacenNombre =
        almacenes?['nombre_comercial'] ?? 'Almacén desconocido';
    final precio = (cotizacion['precio_venta'] as num?)?.toDouble() ?? 0.0;
    final tiempoEntrega =
        cotizacion['tiempo_entrega_estimado'] ?? 'No especificado';
    final fotoEvidencia = cotizacion['foto_evidencia_url'];
    final notas = cotizacion['notas_adicionales'];
    final estado = cotizacion['estado'] ?? 'pendiente';
    final createdAt = cotizacion['created_at'];

    // Simular disponibilidad basado en tiempo de entrega
    final disponibilidad = tiempoEntrega.toLowerCase().contains('hoy')
        ? 'Disponible hoy'
        : 'Mañana';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [cardGradientStart, cardGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección superior: Info del almacén
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            almacenNombre,
                            style: const TextStyle(
                              color: onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: disponibilidad == 'Disponible hoy'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: disponibilidad == 'Disponible hoy'
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              disponibilidad,
                              style: TextStyle(
                                color: disponibilidad == 'Disponible hoy'
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: onSurfaceVariant,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTiempoEnvio(createdAt),
                            style: const TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.schedule,
                            color: onSurfaceVariant,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tiempoEntrega,
                            style: const TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (notas != null && notas.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          notas,
                          style: const TextStyle(
                            color: onSurfaceVariant,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Separador
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: cardBorder,
          ),
          // Sección inferior: Precio y acciones
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Precio destacado
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Precio Final',
                        style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '\$${precio.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: primaryContainer,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: primaryContainer,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Botones de acción
                if (estado == 'pendiente') ...[
                  // Botón Ver foto
                  if (fotoEvidencia != null && fotoEvidencia.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        // Mostrar foto en diálogo
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: surface,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      fotoEvidencia,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.error,
                                              color: Colors.red,
                                              size: 64,
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.image, size: 16),
                      label: const Text('Ver foto'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onSurface,
                        side: const BorderSide(color: cardBorder),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Botón de rechazar
                  OutlinedButton.icon(
                    onPressed: () => _rechazarCotizacion(cotizacion['id']),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón Aceptar
                  ElevatedButton.icon(
                    onPressed: _loadingCotizaciones[cotizacion['id']] == true
                        ? null
                        : () => _aceptarCotizacion(cotizacion['id']),
                    icon: _loadingCotizaciones[cotizacion['id']] == true
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Aceptar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryContainer,
                      foregroundColor: onPrimaryContainer,
                      elevation: 0,
                    ),
                  ),
                ] else if (estado == 'aceptada') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Aceptada',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (estado == 'rechazada') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Rechazada',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
