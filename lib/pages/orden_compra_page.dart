import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/orden_compra.dart';
import '../providers/orden_compra_provider.dart';

class OrdenCompraPage extends StatefulWidget {
  const OrdenCompraPage({super.key});

  @override
  State<OrdenCompraPage> createState() => _OrdenCompraPageState();
}

class _OrdenCompraPageState extends State<OrdenCompraPage> {
  String? _ordenId;
  bool _hasShownErrorDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ordenId = ModalRoute.of(context)?.settings.arguments as String?;
      if (ordenId != null) {
        _ordenId = ordenId;
        final provider = context.read<OrdenCompraProvider>();
        provider.clearError();
        provider.cargarOrden(ordenId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<OrdenCompraProvider>(
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

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final orden = provider.orden;

          if (orden == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No se pudo cargar la orden',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header verde con éxito
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Text(
                        '¡Orden Generada con Éxito!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjeta de Estado Actual
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado Actual',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildEstadoBadge(orden.estado),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjeta de Detalles del Repuesto
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalles del Repuesto',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.attach_money,
                          'Precio',
                          '\$${orden.precioVenta.toStringAsFixed(2)}',
                        ),
                        if (orden.condicionRepuesto != null)
                          _buildDetailRow(
                            Icons.category,
                            'Condición',
                            orden.condicionRepuesto!,
                          ),
                        if (orden.tiempoEntrega != null)
                          _buildDetailRow(
                            Icons.access_time,
                            'Tiempo de Entrega',
                            orden.tiempoEntrega!,
                          ),
                        if (orden.fechaAceptacion != null)
                          _buildDetailRow(
                            Icons.calendar_today,
                            'Fecha de Aceptación',
                            orden.fechaAceptacion!,
                          ),
                        if (orden.notasAdicionales != null &&
                            orden.notasAdicionales!.isNotEmpty)
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
                                    orden.notasAdicionales!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (orden.fotoEvidenciaUrl != null &&
                            orden.fotoEvidenciaUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.photo_library,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Evidencia visual del repuesto:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    orden.fotoEvidenciaUrl!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'No se pudo cargar la imagen',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            height: 150,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjeta de Proveedor
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Proveedor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.store,
                          'Nombre',
                          orden.nombreComercialAlmacen,
                        ),
                        if (orden.direccionTextoAlmacen != null)
                          _buildDetailRow(
                            Icons.location_on,
                            'Dirección',
                            orden.direccionTextoAlmacen!,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botón Volver al Inicio
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Volver al Inicio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
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
        text = 'PENDIENTE';
        break;
      case 'procesando':
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        text = 'EN PROCESO';
        break;
      case 'completada':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        text = 'COMPLETADA';
        break;
      case 'cancelada':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        text = 'CANCELADA';
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[900]!;
        text = estado.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
