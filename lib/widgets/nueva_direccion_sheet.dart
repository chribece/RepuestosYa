import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/direccion_service.dart';
import '../services/geocoding_service.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'ry_button.dart';
import 'ry_location_picker.dart';
import 'ry_text_field.dart';

/// Bottom sheet de "Nueva dirección" con selector visual de ubicación en la
/// parte SUPERIOR (GPS → mapa con pin) y campos de texto DEBAJO, prellenados
/// automáticamente por geocodificado inverso (Nominatim) al usar el GPS o
/// mover el pin.
///
/// Flujo UX (evita reescribir texto cuando ya se seleccionó el pin):
/// 1. "Usar mi ubicación actual" o arrastrar/tocar el pin → reverse geocoding
///    automático (debounced) → "Calle principal" y "Referencia" se rellenan
///    en segundo plano con los datos recuperados.
/// 2. El usuario solo hace una lectura rápida y corrige si la API falló o el
///    nombre quedó mal; si edita un campo, el autocompletado deja de pisarlo.
/// 3. Si el GPS no resuelve (denegado permanente, servicio apagado, sin
///    señal), degrada al camino de texto manual: sin mapa, y el backend
///    geocodifica al guardar. Si el reverse falla, los campos quedan vacíos
///    para escritura manual (misma degradación silenciosa).
class NuevaDireccionSheet extends StatefulWidget {
  const NuevaDireccionSheet({
    super.key,
    required this.direccionService,
    required this.resolverUbicacion,
    this.geocodingService,
  });

  final DireccionService direccionService;

  /// Reutiliza el flujo de GPS del formulario principal (`_flujoUbicacionGps`
  /// → `UbicacionService.resolveLocation()`), con sus diálogos de
  /// Reintentar / Abrir Ajustes / Usar dirección manual. No se duplica
  /// lógica de permisos.
  final Future<UbicacionResultado> Function() resolverUbicacion;

  /// Inyectable para tests; por defecto usa el servicio de Nominatim.
  final GeocodingService? geocodingService;

  @override
  State<NuevaDireccionSheet> createState() => _NuevaDireccionSheetState();
}

class _NuevaDireccionSheetState extends State<NuevaDireccionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _callePrincipalController = TextEditingController();
  final _calleSecundariaController = TextEditingController();
  final _referenciaController = TextEditingController();

  late final GeocodingService _geocodingService =
      widget.geocodingService ?? GeocodingService();

  // Estado del selector de ubicación
  bool _mapaVisible = false; // GPS resuelto → mapa con pin ajustable
  bool _modoManual = false; // GPS no disponible → texto manual (sin mapa)
  double? _pinLat; // posición en vivo del pin (se actualiza al arrastrar)
  double? _pinLng;
  double? _coordsLat; // coordenadas confirmadas por el usuario
  double? _coordsLng;
  bool _guardando = false;

  // Autocompletado por reverse geocoding
  Timer? _debounceTimer;
  int _autocompletarSeq = 0; // ignora respuestas obsoletas
  bool _aplicandoAutocompletado = false; // evita marcar edición del usuario
  bool _calleEditadaPorUsuario = false;
  bool _referenciaEditadaPorUsuario = false;
  bool _autocompletando = false; // indicador en vivo

  bool get _coordenadasConfirmadas => _coordsLat != null && _coordsLng != null;

  bool get _huboAutocompletado => _callePrincipalController.text.isNotEmpty;

  /// Guardar queda deshabilitado hasta que haya coordenadas confirmadas
  /// (por mapa) o, en el camino sin GPS, hasta que haya texto de dirección
  /// manual no vacío.
  bool get _puedeGuardar {
    if (_coordenadasConfirmadas) return true;
    return _callePrincipalController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _aliasController.addListener(_onTextoCambio);
    _callePrincipalController.addListener(_onCallePrincipalCambio);
    _calleSecundariaController.addListener(_onTextoCambio);
    _referenciaController.addListener(_onReferenciaCambio);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _aliasController.dispose();
    _callePrincipalController.dispose();
    _calleSecundariaController.dispose();
    _referenciaController.dispose();
    super.dispose();
  }

  void _onTextoCambio() {
    if (mounted) setState(() {});
  }

  void _onCallePrincipalCambio() {
    if (_aplicandoAutocompletado) return;
    if (_callePrincipalController.text.isEmpty) {
      // Borró el autocompletado: vuelve a permitir autocompletar.
      _calleEditadaPorUsuario = false;
    } else {
      _calleEditadaPorUsuario = true;
    }
    if (mounted) setState(() {});
  }

  void _onReferenciaCambio() {
    if (_aplicandoAutocompletado) return;
    if (_referenciaController.text.isEmpty) {
      _referenciaEditadaPorUsuario = false;
    } else {
      _referenciaEditadaPorUsuario = true;
    }
    if (mounted) setState(() {});
  }

  Future<void> _usarUbicacionActual() async {
    // Reutiliza UbicacionService + los diálogos del flujo principal
    // (progreso, Reintentar, Abrir Ajustes, Usar dirección manual).
    final resultado = await widget.resolverUbicacion();
    if (!mounted) return;
    setState(() {
      if (resultado.disponible) {
        _pinLat = resultado.latitude;
        _pinLng = resultado.longitude;
        _mapaVisible = true;
        _modoManual = false;
      } else {
        // Fallback: texto manual, sin mapa (el backend geocodifica).
        _mapaVisible = false;
        _modoManual = true;
      }
    });
    if (resultado.disponible) {
      _solicitarAutocompletado(resultado.latitude!, resultado.longitude!);
    }
  }

  /// Debounce del reverse geocoding: al arrastrar el pin se disparan muchos
  /// eventos; solo se consulta tras 700ms de reposo (y una sola petición en
  /// vuelo), respetando el límite de uso de Nominatim.
  void _solicitarAutocompletado(double lat, double lng) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 700),
      () => _autocompletar(lat, lng),
    );
  }

  Future<void> _autocompletar(double lat, double lng) async {
    final seq = ++_autocompletarSeq;
    if (mounted) setState(() => _autocompletando = true);
    final resultado = await _geocodingService.reverseGeocode(
      lat: lat,
      lng: lng,
    );
    if (!mounted || seq != _autocompletarSeq) return;

    setState(() {
      _autocompletando = false;
      if (resultado == null) return; // degradación: escribir a mano

      _aplicandoAutocompletado = true;
      if (!_calleEditadaPorUsuario &&
          resultado.callePrincipal != null &&
          resultado.callePrincipal!.isNotEmpty) {
        _callePrincipalController.text = resultado.callePrincipal!;
      }
      if (!_referenciaEditadaPorUsuario &&
          resultado.referencia != null &&
          resultado.referencia!.isNotEmpty) {
        _referenciaController.text = resultado.referencia!;
      }
      _aplicandoAutocompletado = false;
    });
  }

  void _moverPin(LatLng latLng) {
    setState(() {
      _pinLat = latLng.latitude;
      _pinLng = latLng.longitude;
    });
    // Reverse geocoding en vivo (debounced) para rellenar los campos.
    _solicitarAutocompletado(latLng.latitude, latLng.longitude);
  }

  void _confirmarUbicacion() {
    setState(() {
      _coordsLat = _pinLat;
      _coordsLng = _pinLng;
    });
  }

  void _editarUbicacion() {
    setState(() {
      _coordsLat = null;
      _coordsLng = null;
      _mapaVisible = true; // reabrir mapa con el pin donde quedó
      _modoManual = false;
    });
  }

  void _usarManualEnLugar() {
    _debounceTimer?.cancel();
    setState(() {
      _mapaVisible = false;
      _modoManual = true;
      _coordsLat = null;
      _coordsLng = null;
      _pinLat = null;
      _pinLng = null;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final nueva = await widget.direccionService.createDireccion(
        alias: _aliasController.text.trim(),
        callePrincipal: _callePrincipalController.text.trim(),
        calleSecundaria: _calleSecundariaController.text.trim(),
        referencia: _referenciaController.text.trim(),
        // Mismos campos del contrato existente: latitude/longitude/
        // coordenadasFuente='gps'. Sin coordenadas → camino manual, el
        // backend geocodifica server-side antes de aceptar.
        latitude: _coordsLat,
        longitude: _coordsLng,
        coordenadasFuente: _coordenadasConfirmadas ? 'gps' : null,
      );
      if (!mounted) return;
      Navigator.pop(context, nueva);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar dirección: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.spacingMd,
        right: AppSpacing.spacingMd,
        top: AppSpacing.spacingMd,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agregar nueva dirección',
                style: AppTextStyles.textStyleTitle.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              // Jerarquía visual: primero el selector de ubicación (mapa),
              // después los campos prellenados para confirmación rápida.
              _buildSelectorUbicacion(),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildCamposDireccion(),
              const SizedBox(height: AppSpacing.spacingLg),
              _buildAcciones(),
              const SizedBox(height: AppSpacing.spacingSm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamposDireccion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_huboAutocompletado || _autocompletando) ...[
          _buildAutocompletadoHint(),
          const SizedBox(height: AppSpacing.spacingSm),
        ],
        RyTextField(
          label: 'Alias (ej: Casa, Taller)',
          controller: _aliasController,
          isRequired: true,
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Ingresa un alias' : null,
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        RyTextField(
          label: 'Calle principal',
          controller: _callePrincipalController,
          isRequired: true,
          validator: (value) => (value == null || value.isEmpty)
              ? 'Ingresa la calle principal'
              : null,
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        RyTextField(
          label: 'Calle secundaria (opcional)',
          controller: _calleSecundariaController,
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        RyTextField(
          label: 'Referencia (opcional)',
          controller: _referenciaController,
        ),
      ],
    );
  }

  Widget _buildAutocompletadoHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingSm,
        vertical: AppSpacing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      ),
      child: Row(
        children: [
          _autocompletando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.edit_location_alt_outlined,
                  size: 16,
                  color: AppColors.secondary,
                ),
          const SizedBox(width: AppSpacing.spacingXs),
          Expanded(
            child: Text(
              _autocompletando
                  ? 'Obteniendo la calle desde el mapa…'
                  : 'Campos autocompletados desde el mapa. Revisa y corrige si el nombre no es exacto.',
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorUbicacion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.my_location,
                size: 18,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Text(
                'Ubicación (GPS)',
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          if (_coordenadasConfirmadas)
            _buildUbicacionConfirmada()
          else if (_mapaVisible)
            _buildMapaConPin()
          else
            _buildGpsInicial(),
        ],
      ),
    );
  }

  Widget _buildGpsInicial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _modoManual
              ? 'GPS no disponible: guardaremos la dirección y la verificaremos automáticamente al guardar.'
              : 'Usa tu ubicación actual para posicionar el pin en el mapa, o escribe la dirección y la verificaremos al guardar.',
          style: AppTextStyles.textStyleSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        RyButton(
          label: 'Usar mi ubicación actual',
          icon: Icons.my_location,
          variant: RyButtonVariant.primary,
          isFullWidth: true,
          onPressed: _usarUbicacionActual,
        ),
        if (_modoManual) ...[
          const SizedBox(height: AppSpacing.spacingXs),
          Text(
            'Camino manual: el backend geocodificará esta dirección (cobertura Quito).',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMapaConPin() {
    final pin = LatLng(_pinLat!, _pinLng!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RyLocationMapPicker(
          initialPosition: pin,
          height: 240,
          // Al mover el pin se actualizan las coordenadas en vivo y se
          // dispara el reverse geocoding (debounced) para rellenar los
          // campos de dirección; NO se hace forward geocoding (ese solo
          // aplica al camino de texto manual, server-side).
          onChanged: _moverPin,
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text(
          'Pin: ${_pinLat!.toStringAsFixed(6)}, ${_pinLng!.toStringAsFixed(6)} · Arrastra el pin o toca el mapa para ajustarlo',
          style: AppTextStyles.textStyleSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        RyButton(
          label: 'Confirmar ubicación',
          icon: Icons.check_circle_outline,
          variant: RyButtonVariant.primary,
          isFullWidth: true,
          onPressed: _confirmarUbicacion,
        ),
        TextButton(
          onPressed: _usarManualEnLugar,
          child: const Text('En su lugar, escribir la dirección manualmente'),
        ),
      ],
    );
  }

  Widget _buildUbicacionConfirmada() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified,
            color: SemanticColors.colorSuccess,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubicación confirmada (GPS)',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_coordsLat!.toStringAsFixed(6)}, ${_coordsLng!.toStringAsFixed(6)}',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _editarUbicacion, child: const Text('Cambiar')),
        ],
      ),
    );
  }

  Widget _buildAcciones() {
    return Row(
      children: [
        Expanded(
          child: RyButton(
            label: 'Cancelar',
            variant: RyButtonVariant.text,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: AppSpacing.spacingSm),
        Expanded(
          child: RyButton(
            label: 'Guardar',
            variant: RyButtonVariant.primary,
            isLoading: _guardando,
            isDisabled: !_puedeGuardar,
            onPressed: _puedeGuardar ? _guardar : null,
          ),
        ),
      ],
    );
  }
}
