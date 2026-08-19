import 'package:flutter/material.dart';
import 'dart:io';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_notification_service.dart';
import 'received_quotations_page.dart';

class TodasSolicitudesPage extends StatefulWidget {
  const TodasSolicitudesPage({super.key});

  @override
  State<TodasSolicitudesPage> createState() => _TodasSolicitudesPageState();
}

class _TodasSolicitudesPageState extends State<TodasSolicitudesPage> {
  final ScrollController _scrollController = ScrollController();
  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _solicitudes = [];
  bool _isLoading = false;
  bool _cargandoMas = false;
  bool _hayMasDatos = true;
  int _paginaActual = 1;
  final int _limitePorPagina = 10;

  // Estilos y colores idénticos a tu HomePage
  static const Color background = Color(0xFF131313);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color secondaryContainer = Color(0xFF1E95F2);
  static const Color surfaceVariant = Color(0xFF353534);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _cargarPrimeraPagina();

    // Listener para detectar el scroll infinito
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.85) {
        _cargarMasSolicitudes();
      }
    });

    // Suscribirse a notificaciones de cotizaciones para solicitudes activas
    _suscribirANotificaciones();
  }

  Future<void> _suscribirANotificaciones() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final solicitudes = await _solicitudService.obtenerSolicitudesActivas();
        if (solicitudes != null && solicitudes.isNotEmpty) {
          final solicitudIds = solicitudes
              .map((s) => s['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          if (solicitudIds.isNotEmpty) {
            await RealtimeNotificationService().subscribeToAllMyRequests(
              solicitudIds,
            );
          }
        }
      }
    } catch (e) {
      print('Error al suscribir a notificaciones: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    RealtimeNotificationService().unsubscribeMultiple();
    super.dispose();
  }

  Future<void> _cargarPrimeraPagina() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final solicitudes = await _solicitudService.obtenerSolicitudesPaginadas(
          clienteId: user.id,
          page: 1,
          limit: _limitePorPagina,
        );
        setState(() {
          _solicitudes = solicitudes;
          _paginaActual = 1;
          _hayMasDatos = solicitudes.length == _limitePorPagina;
        });
      }
    } catch (e) {
      print('Error al cargar primera página: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMasSolicitudes() async {
    if (_cargandoMas || !_hayMasDatos) return;

    setState(() => _cargandoMas = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final siguientePagina = _paginaActual + 1;
        final nuevasSolicitudes = await _solicitudService
            .obtenerSolicitudesPaginadas(
              clienteId: user.id,
              page: siguientePagina,
              limit: _limitePorPagina,
            );

        setState(() {
          if (nuevasSolicitudes.isEmpty) {
            _hayMasDatos = false;
          } else {
            _paginaActual = siguientePagina;
            _solicitudes.addAll(nuevasSolicitudes);
            if (nuevasSolicitudes.length < _limitePorPagina) {
              _hayMasDatos = false;
            }
          }
        });
      }
    } catch (e) {
      print('Error al cargar más solicitudes: $e');
    } finally {
      setState(() => _cargandoMas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          'Todas mis Solicitudes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const Border(
          bottom: BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryContainer),
            )
          : _solicitudes.isEmpty
          ? const Center(
              child: Text(
                'No tienes solicitudes registradas',
                style: TextStyle(color: onSurfaceVariant),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _solicitudes.length + (_cargandoMas ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _solicitudes.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryContainer),
                    ),
                  );
                }

                final solicitud = _solicitudes[index];
                final estado = solicitud['estado'] as String? ?? 'en_proceso';
                Color statusColor = primaryContainer;
                String statusText = estado;

                switch (estado) {
                  case 'en_proceso':
                    statusColor = primaryContainer;
                    statusText = 'En Proceso';
                    break;
                  case 'completado':
                    statusColor = Colors.green;
                    statusText = 'Completado';
                    break;
                  case 'expirado':
                    statusColor = onSurfaceVariant;
                    statusText = 'Expirado';
                    break;
                }

                final createdAt = solicitud['created_at'] as String?;
                String timeText = 'Reciente';
                if (createdAt != null) {
                  final date = DateTime.parse(createdAt);
                  final difference = DateTime.now().difference(date);
                  if (difference.inHours < 1) {
                    timeText = 'Hace ${difference.inMinutes} min';
                  } else if (difference.inHours < 24) {
                    timeText = 'Hace ${difference.inHours}h';
                  } else if (difference.inDays == 1) {
                    timeText = 'Ayer';
                  } else {
                    timeText = 'Hace ${difference.inDays} días';
                  }
                }

                // Extraer el conteo de cotizaciones del formato que devuelve Supabase
                int cantidadCotizaciones = 0;
                if (solicitud['cotizaciones'] != null &&
                    solicitud['cotizaciones'] is List) {
                  final cotizacionesList = solicitud['cotizaciones'] as List;
                  if (cotizacionesList.isNotEmpty &&
                      cotizacionesList[0] is Map) {
                    cantidadCotizaciones = cotizacionesList[0]['count'] ?? 0;
                  }
                } else if (solicitud['cotizaciones_count'] != null) {
                  cantidadCotizaciones = solicitud['cotizaciones_count'];
                }

                final String quotesText = cantidadCotizaciones == 1
                    ? '1 Cotización nueva'
                    : '$cantidadCotizaciones Cotizaciones';
                final String urlFinal =
                    solicitud['image_url'] ?? solicitud['foto_url'] ?? '';
                final String piezaNombreFinal =
                    solicitud['pieza_nombre'] as String? ?? 'Repuesto';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReceivedQuotationsPage(
                            solicitudId: solicitud['id'].toString(),
                            piezaNombre: piezaNombreFinal,
                          ),
                        ),
                      );
                    },
                    child: _buildRequestCard(
                      title: piezaNombreFinal,
                      subtitle:
                          solicitud['descripcion'] as String? ??
                          'Sin descripción',
                      status: statusText,
                      statusColor: statusColor,
                      quotes: quotesText,
                      tieneCotizaciones: cantidadCotizaciones > 0,
                      time: timeText,
                      imageUrl: urlFinal,
                    ),
                  ),
                );
              },
            ),
    );
  }

  // Tu misma tarjeta reutilizable extraída de home_page.dart
  Widget _buildRequestCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required String quotes,
    required bool tieneCotizaciones,
    required String time,
    required String imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tieneCotizaciones ? primaryContainer : outlineVariant,
          width: tieneCotizaciones ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.startsWith('http') || imageUrl.startsWith('https')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.image_not_supported,
                        color: onSurfaceVariant,
                        size: 32,
                      ),
                    )
                  : Image.file(
                      File(imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.image_not_supported,
                        color: onSurfaceVariant,
                        size: 32,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: tieneCotizaciones
                              ? primaryContainer
                              : secondaryContainer,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          quotes,
                          style: TextStyle(
                            color: tieneCotizaciones
                                ? primaryContainer
                                : secondaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        color: onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
