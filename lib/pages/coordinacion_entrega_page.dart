import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/coordinacion_entrega.dart';
import '../router/route_names.dart';
import '../services/coordinacion_entrega_cache.dart';
import '../services/solicitud_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../utils/contact_launcher.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_state_container.dart';

/// Éxito y Coordinación de Entrega (rol cliente): tras aceptar una
/// cotización se muestra el contacto del almacén ganador para coordinar el
/// pago y la entrega por fuera de la app.
///
/// - [datosIniciales] llega completo tras aceptar (navegación inmediata);
/// - si se reabre desde una solicitud ACEPTADA, se recupera de la caché
///   local y, si no hay caché, del backend (funciona con datos cacheados
///   aunque no haya conexión).
class CoordinacionEntregaPage extends StatefulWidget {
  final String solicitudId;
  final DatosCoordinacionEntrega? datosIniciales;

  /// Inyectables para tests (mismo patrón que WarehouseDashboard).
  final SolicitudService? solicitudService;
  final CoordinacionEntregaCache? cache;

  const CoordinacionEntregaPage({
    super.key,
    required this.solicitudId,
    this.datosIniciales,
    this.solicitudService,
    this.cache,
  });

  @override
  State<CoordinacionEntregaPage> createState() =>
      _CoordinacionEntregaPageState();
}

class _CoordinacionEntregaPageState extends State<CoordinacionEntregaPage> {
  static const String _logName = 'CoordinacionEntregaPage';

  late final SolicitudService _solicitudService =
      widget.solicitudService ?? SolicitudService();
  CoordinacionEntregaCache? _cache;

  DatosCoordinacionEntrega? _datos;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // 1. Datos recién aceptados (navegación inmediata).
    if (widget.datosIniciales != null) {
      _datos = widget.datosIniciales;
      _isLoading = false;
      if (mounted) setState(() {});
      unawaited(_persistirDatos());
      return;
    }

    // 2. Caché local (reabrir sin conexión o con datos guardados).
    final cache = widget.cache ?? await CoordinacionEntregaCache.instancia();
    _cache = cache;
    final cacheData = cache.leer(widget.solicitudId);
    if (cacheData != null) {
      _datos = cacheData;
      _isLoading = false;
      if (mounted) setState(() {});
      return;
    }

    // 3. Backend: buscar la cotización GANADA de la solicitud.
    try {
      final cotizaciones = await _solicitudService.obtenerCotizacionesRecibidas(
        widget.solicitudId,
      );
      for (final cotizacion in cotizaciones) {
        final datos = DatosCoordinacionEntrega.fromCotizacionMap(
          cotizacion,
          solicitudId: widget.solicitudId,
        );
        if (datos != null) {
          _datos = datos;
          unawaited(_persistirDatos());
          if (mounted) setState(() {});
          return;
        }
      }
      if (mounted) {
        setState(() {
          _errorMessage =
              'No se encontró una cotización aceptada para esta solicitud.';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error(
        'Error al cargar datos de coordinación',
        name: _logName,
        error: e,
      );
      if (mounted) {
        setState(() {
          _errorMessage = ApiErrorHandler.userMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  /// Carga la instancia de caché (si aún no está) y persiste los datos
  /// actuales. Fire-and-forget: un fallo de persistencia no rompe la UI.
  Future<void> _persistirDatos() async {
    try {
      _cache ??= widget.cache ?? await CoordinacionEntregaCache.instancia();
      await _guardarEnCache();
    } catch (e) {
      AppLogger.error(
        'Error al persistir caché de coordinación',
        name: _logName,
        error: e,
      );
    }
  }

  Future<void> _guardarEnCache() async {
    final datos = _datos;
    final cache = _cache;
    if (datos == null || cache == null) return;
    try {
      await cache.guardar(datos);
    } catch (e) {
      AppLogger.error(
        'Error al guardar caché de coordinación',
        name: _logName,
        error: e,
      );
    }
  }

  Future<void> _llamar() async {
    final telefono = _datos?.telefono;
    if (telefono == null || !isValidPhone(telefono)) return;
    final resultado = await ContactLauncher.launch(buildTelUri(telefono));
    if (!mounted) return;
    if (resultado != ContactLaunchResult.launched) {
      _mostrarFalloApertura('No se pudo abrir el marcador', telefono);
    }
  }

  Future<void> _enviarWhatsApp() async {
    final datos = _datos;
    final telefono = datos?.telefono;
    if (datos == null || telefono == null || !isValidPhone(telefono)) return;
    final mensaje = mensajeWhatsAppCliente(
      almacenNombre: datos.almacenNombre,
      repuestoNombre: datos.repuestoNombre,
      precio: datos.precioVenta,
    );
    final resultado = await ContactLauncher.launch(
      buildWhatsAppUri(telefono, mensaje),
    );
    if (!mounted) return;
    if (resultado != ContactLaunchResult.launched) {
      _mostrarFalloApertura('No se pudo abrir WhatsApp', telefono);
    }
  }

  void _mostrarFalloApertura(String mensaje, String telefono) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Copiar',
          textColor: AppColors.onSurface,
          onPressed: () {
            copiarAlPortapapeles(telefono);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Número copiado'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _copiar(String texto, String etiqueta) async {
    await copiarAlPortapapeles(texto);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$etiqueta copiado'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _abrirCorreo(String email) {
    final uri = buildMailtoUri(email);
    if (uri == null) return;
    ContactLauncher.launch(uri).then((resultado) {
      if (!mounted) return;
      if (resultado != ContactLaunchResult.launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el correo'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          tooltip: 'Regresar',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Coordinación de entrega',
          style: AppTextStyles.textStyleTitle,
        ),
      ),
      body: _isLoading
          ? const RyStateContainer(
              title: 'Cargando datos de contacto...',
              type: RyStateType.loading,
            )
          : _errorMessage != null && _datos == null
          ? RyStateContainer(
              title: 'No se pudieron cargar los datos',
              subtitle: _errorMessage,
              type: RyStateType.error,
              actionLabel: 'Reintentar',
              onAction: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _cargarDatos();
              },
            )
          : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    final datos = _datos;
    if (datos == null) return const SizedBox.shrink();
    final telefonoValido = isValidPhone(datos.telefono);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.spacingLg),
      children: [
        // Ícono de éxito
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 72,
        ),
        const SizedBox(height: AppSpacing.spacingMd),

        // Mensaje exacto de la misión
        Text(
          '¡Cotización seleccionada! Ponte en contacto con el almacén para '
          'coordinar el método de pago y los detalles del envío de tu repuesto.',
          textAlign: TextAlign.center,
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingLg),

        // Card de contacto del almacén
        Container(
          padding: const EdgeInsets.all(AppSpacing.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            border: Border.all(color: AppColors.outlineVariant, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contacto del almacén', style: AppTextStyles.textStyleTitle),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildContactoRow(
                icon: Icons.store,
                label: 'Almacén',
                value: datos.almacenNombre,
              ),
              _buildContactoRow(
                icon: Icons.phone,
                label: 'Teléfono / Celular',
                value: telefonoValido ? datos.telefono! : null,
                placeholder: 'El almacén no registró teléfono',
                copiable: datos.telefono,
              ),
              if (datos.email != null && datos.email!.isNotEmpty)
                _buildContactoRow(
                  icon: Icons.mail_outline,
                  label: 'Correo electrónico',
                  value: datos.email!,
                  copiable: datos.email!,
                  onAbrirCorreo: () => _abrirCorreo(datos.email!),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spacingLg),

        // Acciones
        RyButton(
          label: 'Llamar por Teléfono',
          icon: Icons.phone,
          variant: RyButtonVariant.primary,
          isFullWidth: true,
          isDisabled: !telefonoValido,
          onPressed: _llamar,
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        RyButton(
          label: 'Enviar WhatsApp',
          icon: Icons.chat,
          variant: RyButtonVariant.secondary,
          isFullWidth: true,
          isDisabled: !telefonoValido,
          onPressed: _enviarWhatsApp,
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        RyButton(
          label: 'Volver al inicio',
          icon: Icons.home_outlined,
          variant: RyButtonVariant.outline,
          isFullWidth: true,
          onPressed: () => context.go(RouteNames.home),
        ),
      ],
    );
  }

  Widget _buildContactoRow({
    required IconData icon,
    required String label,
    required String? value,
    String? placeholder,
    String? copiable,
    VoidCallback? onAbrirCorreo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryContainer, size: 20),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  value ?? placeholder ?? '—',
                  style: AppTextStyles.textStyleBody.copyWith(
                    color: value == null
                        ? AppColors.onSurfaceVariant
                        : AppColors.onSurface,
                    fontWeight: value == null
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (copiable != null && copiable.isNotEmpty) ...[
            IconButton(
              tooltip: 'Copiar $label',
              icon: const Icon(Icons.copy, size: 18),
              color: AppColors.primaryContainer,
              onPressed: () => _copiar(copiable, label),
            ),
            if (onAbrirCorreo != null)
              IconButton(
                tooltip: 'Abrir correo',
                icon: const Icon(Icons.open_in_new, size: 18),
                color: AppColors.primaryContainer,
                onPressed: onAbrirCorreo,
              ),
          ],
        ],
      ),
    );
  }
}
