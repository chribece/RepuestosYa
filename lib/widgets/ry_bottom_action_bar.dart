import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'ry_button.dart';

/// Barra de acción fija al fondo de una pantalla (Parte 1 de los fixes de
/// layout móvil).
///
/// Resuelve la causa raíz compartida de "botones tapados por la barra de
/// gestos": un elemento fijo al fondo que no respeta el área segura del
/// dispositivo. Aquí el fondo ([ColoredBox]) se extiende hasta el borde real
/// de la pantalla y el contenido se eleva con [SafeArea] (top: false) por
/// encima del inset inferior — el mismo patrón del bottom nav del
/// Home/Dashboard del almacén.
///
/// Soporta 1-2 botones (primario + secundario opcional) reutilizando
/// [RyButton] (nunca GetWidget) y un [banner] opcional encima de los
/// botones para avisos (p. ej. "Ubicación pendiente").
class RyBottomActionBar extends StatelessWidget {
  /// Texto del botón primario (siempre presente).
  final String primaryLabel;

  /// Ícono opcional del botón primario.
  final IconData? primaryIcon;

  /// Callback del botón primario (`null` + [primaryDisabled] lo deshabilita).
  final VoidCallback? onPrimaryPressed;

  /// Muestra el spinner de carga en el botón primario.
  final bool primaryLoading;

  /// Deshabilita el botón primario.
  final bool primaryDisabled;

  /// Variante del botón primario (por defecto `primary`).
  final RyButtonVariant primaryVariant;

  /// Texto del botón secundario opcional (se muestra a la izquierda del
  /// primario, con variante `outline`).
  final String? secondaryLabel;

  /// Ícono opcional del botón secundario.
  final IconData? secondaryIcon;

  /// Callback del botón secundario.
  final VoidCallback? onSecondaryPressed;

  /// Deshabilita el botón secundario.
  final bool secondaryDisabled;

  /// Aviso opcional encima de los botones (fila con ícono + texto).
  final Widget? banner;

  /// Fondo de la barra. Por defecto la superficie elevada del DS.
  final Color backgroundColor;

  /// Borde superior separador del contenido.
  final bool showTopBorder;

  const RyBottomActionBar({
    super.key,
    required this.primaryLabel,
    this.primaryIcon,
    this.onPrimaryPressed,
    this.primaryLoading = false,
    this.primaryDisabled = false,
    this.primaryVariant = RyButtonVariant.primary,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryPressed,
    this.secondaryDisabled = false,
    this.banner,
    this.backgroundColor = AppColors.surfaceContainerHigh,
    this.showTopBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.spacingMd,
            AppSpacing.spacingSm,
            AppSpacing.spacingMd,
            AppSpacing.spacingMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner != null) ...[
                banner!,
                const SizedBox(height: AppSpacing.spacingSm),
              ],
              Row(
                children: [
                  if (secondaryLabel != null) ...[
                    Expanded(
                      child: RyButton(
                        label: secondaryLabel!,
                        icon: secondaryIcon,
                        variant: RyButtonVariant.outline,
                        size: RyButtonSize.large,
                        isFullWidth: true,
                        isDisabled: secondaryDisabled,
                        onPressed: onSecondaryPressed,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spacingSm),
                  ],
                  Expanded(
                    flex: secondaryLabel != null ? 2 : 1,
                    child: RyButton(
                      label: primaryLabel,
                      icon: primaryIcon,
                      variant: primaryVariant,
                      size: RyButtonSize.large,
                      isLoading: primaryLoading,
                      isFullWidth: true,
                      isDisabled: primaryDisabled,
                      onPressed: onPrimaryPressed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
