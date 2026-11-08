import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'ry_button.dart';

/// Envía la calificación. Devuelve `null` si se guardó o el mensaje de error.
typedef EnviarCalificacion =
    Future<String?> Function(int estrellas, String? comentario);

/// Calificación del almacén por parte del cliente, visible cuando la orden ya
/// fue entregada. Si la orden ya tiene calificación (`estrellasIniciales`), se
/// muestra directamente el agradecimiento con las estrellas otorgadas.
class RyCalificacionOrden extends StatefulWidget {
  const RyCalificacionOrden({
    super.key,
    required this.onEnviar,
    this.estrellasIniciales,
  });

  final EnviarCalificacion onEnviar;
  final int? estrellasIniciales;

  @override
  State<RyCalificacionOrden> createState() => _RyCalificacionOrdenState();
}

class _RyCalificacionOrdenState extends State<RyCalificacionOrden> {
  static const int _maxEstrellas = 5;

  final TextEditingController _comentarioController = TextEditingController();
  late int _estrellas = widget.estrellasIniciales ?? 0;
  late bool _enviada = widget.estrellasIniciales != null;
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_estrellas == 0 || _enviando) return;
    setState(() => _enviando = true);
    final comentario = _comentarioController.text.trim();
    final error = await widget.onEnviar(
      _estrellas,
      comentario.isEmpty ? null : comentario,
    );
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _enviada = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: _enviada ? _buildAgradecimiento() : _buildFormulario(),
    );
  }

  Widget _buildFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Califica tu experiencia',
          textAlign: TextAlign.center,
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text(
          '¿Cómo fue tu compra con el almacén?',
          textAlign: TextAlign.center,
          style: AppTextStyles.textStyleSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= _maxEstrellas; i++)
              IconButton(
                tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
                onPressed: _enviando
                    ? null
                    : () => setState(() => _estrellas = i),
                icon: Icon(
                  i <= _estrellas ? Icons.star : Icons.star_border,
                  color: AppColors.warning,
                  size: 32,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        TextField(
          controller: _comentarioController,
          enabled: !_enviando,
          maxLines: 3,
          maxLength: 500,
          style: AppTextStyles.textStyleBody,
          decoration: InputDecoration(
            hintText: 'Déjanos un breve comentario (opcional)',
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: _bordeComentario(AppColors.outlineVariant),
            enabledBorder: _bordeComentario(AppColors.outlineVariant),
            focusedBorder: _bordeComentario(AppColors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        RyButton(
          label: 'Enviar Calificación',
          variant: RyButtonVariant.primary,
          isFullWidth: true,
          isLoading: _enviando,
          isDisabled: _estrellas == 0,
          onPressed: _enviar,
        ),
      ],
    );
  }

  Widget _buildAgradecimiento() {
    final estrellas = _estrellas;
    return Column(
      children: [
        Text(
          '¡Gracias por tu calificación!',
          textAlign: TextAlign.center,
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= _maxEstrellas; i++)
              Icon(
                i <= estrellas ? Icons.star : Icons.star_border,
                color: AppColors.warning,
                size: 28,
              ),
          ],
        ),
      ],
    );
  }

  OutlineInputBorder _bordeComentario(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      borderSide: BorderSide(color: color),
    );
  }
}
