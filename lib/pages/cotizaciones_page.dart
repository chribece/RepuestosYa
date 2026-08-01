import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cotizacion.dart';
import '../providers/cotizacion_provider.dart';

class CotizacionesPage extends StatefulWidget {
  final String solicitudId;

  const CotizacionesPage({super.key, required this.solicitudId});

  @override
  State<CotizacionesPage> createState() => _CotizacionesPageState();
}

class _CotizacionesPageState extends State<CotizacionesPage> {
  bool _hasShownErrorDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CotizacionProvider>();
      provider.clearError();
      provider.cargarCotizaciones(widget.solicitudId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotizaciones Recibidas'),
        backgroundColor: Colors.blue[700],
      ),
      body: Consumer<CotizacionProvider>(
        builder: (context, provider, child) {
          // Mostrar error con SnackBar si existe
          if (provider.errorMessage != null && !_hasShownErrorDialog) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage!),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: Colors.white,
                      onPressed: () {
                        provider.clearError();
                      },
                    ),
                  ),
                );
              }
            });
          }

          // Mostrar AlertDialog si la solicitud fue cerrada
          if (provider.solicitudCerrada && !_hasShownErrorDialog) {
            _hasShownErrorDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Solicitud Cerrada'),
                      content: const Text(
                        'Has rechazado todas las cotizaciones. La solicitud ha sido cerrada.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Volver'),
                        ),
                      ],
                    );
                  },
                );
              }
            });
          }

          // Navegar a la página de orden de compra si se aceptó una cotización
          if (provider.ordenCompraId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushNamed(
                  context,
                  '/orden-compra',
                  arguments: provider.ordenCompraId,
                );
              }
            });
          }

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.cotizaciones.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay cotizaciones aún',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.cargarCotizaciones(widget.solicitudId),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.cotizaciones.length,
              itemBuilder: (context, index) {
                final cotizacion = provider.cotizaciones[index];
                final isPendiente = cotizacion.isPendiente;
                final isProcesando = provider.isCotizacionProcesando(
                  cotizacion.id,
                );

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del almacén
                        Row(
                          children: [
                            const Icon(
                              Icons.store,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cotizacion.almacen?.nombreComercial ??
                                    'Almacén desconocido',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Badge de estado
                            _buildEstadoBadge(cotizacion.estado),
                          ],
                        ),
                        const Divider(height: 24),

                        // Precio
                        _buildInfoRow(
                          Icons.attach_money,
                          'Precio',
                          '\$${cotizacion.precioVenta.toStringAsFixed(2)}',
                        ),

                        // Condición del repuesto
                        if (cotizacion.condicionRepuesto != null)
                          _buildInfoRow(
                            Icons.category,
                            'Condición',
                            cotizacion.condicionRepuesto!,
                          ),

                        // Tiempo de entrega
                        if (cotizacion.tiempoEntregaEstimado != null)
                          _buildInfoRow(
                            Icons.access_time,
                            'Tiempo de entrega',
                            cotizacion.tiempoEntregaEstimado!,
                          ),

                        // Notas adicionales
                        if (cotizacion.notasAdicionales != null &&
                            cotizacion.notasAdicionales!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.note,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cotizacion.notasAdicionales!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Evidencia visual
                        if (cotizacion.fotoEvidenciaUrl != null &&
                            cotizacion.fotoEvidenciaUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Evidencia visual',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    cotizacion.fotoEvidenciaUrl!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                                size: 40,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Error al cargar imagen',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            width: double.infinity,
                                            height: 200,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Botones de acción
                        if (isPendiente)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isProcesando
                                      ? null
                                      : () {
                                          provider.aceptarCotizacion(
                                            cotizacion.id,
                                          );
                                        },
                                  icon: isProcesando
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(Icons.check),
                                  label: Text(
                                    isProcesando ? 'Procesando...' : 'Aceptar',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isProcesando
                                      ? null
                                      : () {
                                          provider.rechazarCotizacion(
                                            cotizacion.id,
                                          );
                                        },
                                  icon: const Icon(Icons.close),
                                  label: const Text('Rechazar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Center(
                            child: Text(
                              cotizacion.isAceptada
                                  ? 'Cotización aceptada'
                                  : 'Cotización rechazada',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cotizacion.isAceptada
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (estado.toLowerCase()) {
      case 'pendiente':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        text = 'Pendiente';
        break;
      case 'aceptada':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        text = 'Aceptada';
        break;
      case 'rechazada':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        text = 'Rechazada';
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[900]!;
        text = estado;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
