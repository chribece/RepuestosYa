import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Selector visual de ubicación: mapa con un pin que el usuario puede
/// arrastrar (con el dedo) o reposicionar tocando el mapa (tap-to-move).
///
/// Usa `flutter_map` con tiles de OpenStreetMap (sin API key), consistente
/// con el geocoding server-side vía Nominatim ya implementado. En producción
/// se puede migrar a `google_maps_flutter` (Google Maps, requiere API key)
/// sin romper el resto del flujo: basta con reemplazar el cuerpo de este
/// widget por el `GoogleMap` equivalente y traducir [LatLng] — mismo criterio
/// "swappable" que se usó para el geocoding.
///
/// Reglas de comportamiento:
/// - Al mover el pin solo cambian las coordenadas en vivo vía [onChanged];
///   NO se dispara geocoding forward (ese solo aplica al camino de texto
///   manual, server-side).
/// - El pin se arrastra con LONG-PRESS: mantener presionado ~500ms y deslizar.
///   Se usa long-press (en lugar de drag directo) porque este widget vive
///   dentro de scroll views (bottom sheet de "Nueva dirección"): un drag
///   vertical directo lo ganaría el Scrollable en la arena de gestos, y el
///   long-press reclama la arena tras el umbral de 500ms sin competir con el
///   scroll ni con el pan del mapa.
/// - Alternativa: tocar cualquier punto del mapa reposiciona el pin
///   (tap-to-move).
/// - El mapa se desplaza normalmente con UN dedo (pan) y se hace zoom con
///   pellizco/scroll/doble tap.
/// - El mapa se centra en [initialPosition] (resultado del GPS del
///   dispositivo) y muestra una etiqueta de cobertura (Quito) como guía
///   visual. No es una restricción dura en el cliente: la restricción dura
///   sigue siendo la del backend para el camino de texto manual.
class RyLocationMapPicker extends StatefulWidget {
  const RyLocationMapPicker({
    super.key,
    required this.initialPosition,
    required this.onChanged,
    this.height = 240,
    this.showPin = true,
  });

  /// Centro inicial del mapa y posición inicial del pin (típicamente el
  /// resultado de `UbicacionService.resolveLocation()`). Si el padre cambia
  /// este valor (p. ej. el GPS resuelve en otro punto), el widget recentra
  /// la cámara y mueve el pin automáticamente ([didUpdateWidget]).
  final LatLng initialPosition;

  /// Se invoca en tiempo real cada vez que el pin cambia de posición.
  final ValueChanged<LatLng> onChanged;

  /// Alto del área del mapa.
  final double height;

  /// Si `false`, el mapa se muestra sin pin hasta que el usuario interactúe
  /// (toca el mapa o el padre fija una posición). Evita el "pin fantasma"
  /// cuando aún no hay ubicación elegida.
  final bool showPin;

  @override
  State<RyLocationMapPicker> createState() => _RyLocationMapPickerState();
}

class _RyLocationMapPickerState extends State<RyLocationMapPicker> {
  final MapController _mapController = MapController();
  late LatLng _pin;
  bool _arrastrandoPin = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPosition;
  }

  @override
  void didUpdateWidget(RyLocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cambio externo de posición (p. ej. GPS resuelto en el padre): mover el
    // pin y centrar la cámara en el punto. No se reacciona cuando el cambio
    // es un eco del propio pin tras arrastrar (initialPosition == _pin).
    if (widget.initialPosition != _pin) {
      _mapController.move(widget.initialPosition, _mapController.camera.zoom);
      _pin = widget.initialPosition;
    }
  }

  void _moverPin(LatLng latLng) {
    setState(() {
      _pin = latLng;
    });
    widget.onChanged(latLng);
  }

  /// Convierte una posición global del gesto a coordenadas del mapa y
  /// reposiciona el pin. Usada por el arrastre del marcador y el tap-to-move.
  void _moverPinDesdeGesto(Offset globalPosition) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final local = renderBox.globalToLocal(globalPosition);
    final latLng = _mapController.camera.screenOffsetToLatLng(local);
    _moverPin(latLng);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialPosition,
                initialZoom: 15,
                minZoom: 9,
                maxZoom: 19,
                // Gestos estándar: pan con un dedo + zoom. El arrastre del
                // pin funciona porque el recognizer del marcador (más
                // profundo) gana la arena cuando el gesto empieza sobre él.
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.repuestosya.app',
                ),
                MarkerLayer(
                  markers: widget.showPin
                      ? [
                          Marker(
                            point: _pin,
                            width: 48,
                            height: 48,
                            // El vértice inferior del pin coincide con la
                            // coordenada.
                            alignment: Marker.computePixelAlignment(
                              width: 48,
                              height: 48,
                              left: 24,
                              top: 44,
                            ),
                            child: GestureDetector(
                              // Long-press para arrastrar (ver doc de la
                              // clase): reclama la arena frente al Scrollable
                              // y al pan del mapa sin competencia.
                              onLongPressStart: (_) =>
                                  setState(() => _arrastrandoPin = true),
                              onLongPressMoveUpdate: (details) =>
                                  _moverPinDesdeGesto(details.globalPosition),
                              onLongPressEnd: (_) =>
                                  setState(() => _arrastrandoPin = false),
                              onLongPressCancel: () =>
                                  setState(() => _arrastrandoPin = false),
                              child: Icon(
                                Icons.location_pin,
                                size: 48,
                                // Feedback visual mientras se arrastra.
                                color: _arrastrandoPin
                                    ? AppColors.primaryContainer
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ]
                      : const [],
                ),
              ],
            ),
            // Guía visual de cobertura (no es una restricción dura).
            Positioned(
              top: AppSpacing.spacingXs,
              left: AppSpacing.spacingXs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingSm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_city,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cobertura: Quito',
                      style: AppTextStyles.textStyleSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tap-to-move determinista: detector translúcido propio en lugar
            // del onTap del mapa (el detector interno usa deferToChild y no
            // recibe taps si las tiles aún no cargaron). Translúcido: no
            // bloquea los gestos del mapa ni del marcador.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) =>
                    _moverPinDesdeGesto(details.globalPosition),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
