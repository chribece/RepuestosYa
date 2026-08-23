import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum RyTextFieldType {
  text,
  email,
  password,
  number,
  decimal,
  phone,
  url,
  multiline,
  search,
}

class RyTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? initialValue;
  final TextEditingController? controller;
  final String? helperText;
  final String? errorText;
  final RyTextFieldType type;
  final bool isRequired;
  final bool isReadOnly;
  final bool isDense;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final Widget? prefixWidget;
  final Widget? suffixWidget;

  const RyTextField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.controller,
    this.helperText,
    this.errorText,
    this.type = RyTextFieldType.text,
    this.isRequired = false,
    this.isReadOnly = false,
    this.isDense = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.prefixWidget,
    this.suffixWidget,
  });

  @override
  State<RyTextField> createState() => _RyTextFieldState();
}

class _RyTextFieldState extends State<RyTextField> {
  late TextEditingController _controller;
  bool _obscureText = false;

  /// true cuando el controller lo creó este widget (y por tanto debe liberarlo).
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _obscureText = widget.type == RyTextFieldType.password;
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  TextInputType? _getKeyboardType() {
    if (widget.keyboardType != null) return widget.keyboardType;

    switch (widget.type) {
      case RyTextFieldType.email:
        return TextInputType.emailAddress;
      case RyTextFieldType.phone:
        return TextInputType.phone;
      case RyTextFieldType.number:
        return TextInputType.number;
      case RyTextFieldType.decimal:
        return const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        );
      case RyTextFieldType.url:
        return TextInputType.url;
      case RyTextFieldType.multiline:
        return TextInputType.multiline;
      case RyTextFieldType.search:
        return TextInputType.text;
      case RyTextFieldType.text:
      case RyTextFieldType.password:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? _getInputFormatters() {
    if (widget.inputFormatters != null) return widget.inputFormatters;

    switch (widget.type) {
      case RyTextFieldType.number:
        return [FilteringTextInputFormatter.digitsOnly];
      case RyTextFieldType.decimal:
        // Permite dígitos, un único punto decimal y un signo negativo
        // opcional al inicio (necesario para lat/long). Bloquea todo lo
        // demás (letras, comas, signo en medio, múltiples puntos, etc.).
        return [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*$'))];
      case RyTextFieldType.phone:
        return [FilteringTextInputFormatter.digitsOnly];
      default:
        return null;
    }
  }

  int? _getMaxLines() {
    if (widget.type == RyTextFieldType.multiline) {
      return widget.maxLines ?? 3;
    }
    return widget.maxLines;
  }

  bool _getObscureText() {
    if (widget.type != RyTextFieldType.password) return false;
    return _obscureText;
  }

  IconData? _getSuffixIcon() {
    if (widget.suffixWidget != null) return null;
    if (widget.suffixIcon != null) return widget.suffixIcon;

    if (widget.type == RyTextFieldType.password) {
      return _obscureText ? Icons.visibility_off : Icons.visibility;
    }

    return null;
  }

  VoidCallback? _getSuffixIconCallback() {
    if (widget.suffixWidget != null) return null;
    if (widget.onSuffixIconTap != null) return widget.onSuffixIconTap;

    if (widget.type == RyTextFieldType.password) {
      return () {
        setState(() {
          _obscureText = !_obscureText;
        });
      };
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Los estados de foco/error los resuelve inputDecorationTheme (app_theme.dart).
    // Semantics expone el campo a TalkBack/VoiceOver con label legible y
    // hint (error/helper) en lugar de leer fragmentos sueltos del
    // InputDecoration. excludeSemantics evita que el label/helper/error
    // se anuncien dos veces.
    return Semantics(
      label: widget.label ?? widget.hint,
      hint: widget.errorText ?? widget.helperText,
      textField: true,
      enabled: !widget.isReadOnly,
      excludeSemantics: true,
      child: TextFormField(
        controller: _controller,
        keyboardType: _getKeyboardType(),
        inputFormatters: _getInputFormatters(),
        obscureText: _getObscureText(),
        maxLines: _getMaxLines(),
        maxLength: widget.maxLength,
        readOnly: widget.isReadOnly,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        onTap: widget.onTap,
        style: AppTextStyles.textStyleBody.copyWith(color: AppColors.onSurface),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: widget.helperText,
          errorText: widget.errorText,
          isDense: widget.isDense,
          prefixIcon: widget.prefixWidget != null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.spacingSm),
                  child: widget.prefixWidget,
                )
              : widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: AppColors.onSurfaceVariant)
              : null,
          suffixIcon: widget.suffixWidget != null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.spacingSm),
                  child: widget.suffixWidget,
                )
              : _getSuffixIcon() != null
              ? IconButton(
                  icon: Icon(
                    _getSuffixIcon(),
                    color: AppColors.onSurfaceVariant,
                  ),
                  onPressed: _getSuffixIconCallback(),
                  // 48×48 dp mínimo WCAG 2.5.5 (antes constraints:
                  // BoxConstraints() colapsaba el área táctil a ~24 dp).
                  visualDensity: VisualDensity.standard,
                  iconSize: 24,
                )
              : null,
          suffix: widget.isRequired && widget.label != null
              ? Text(
                  ' *',
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.requiredAsterisk,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
