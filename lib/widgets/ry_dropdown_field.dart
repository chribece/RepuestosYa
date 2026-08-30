import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_radius.dart';

class RyDropdownField<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabelBuilder;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final bool isRequired;
  final bool isLoading;
  final bool enabled;

  const RyDropdownField({
    super.key,
    this.label,
    this.hint,
    this.value,
    required this.items,
    required this.itemLabelBuilder,
    this.onChanged,
    this.errorText,
    this.isRequired = false,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isRequired)
                  TextSpan(
                    text: ' *',
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.requiredAsterisk,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spacingXs),
        ],
        Semantics(
          label: label ?? hint,
          hint: errorText,
          enabled: enabled && !isLoading,
          child: Container(
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.surfaceContainerHigh
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              border: Border.all(
                color: errorText != null
                    ? AppColors.error
                    : AppColors.outlineVariant,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<T>(
                initialValue: (items.contains(value)) ? value : null,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spacingMd,
                    vertical: AppSpacing.spacingSm,
                  ),
                  border: InputBorder.none,
                  hintText: isLoading ? 'Cargando...' : hint,
                  errorStyle: const TextStyle(
                    height: 0,
                  ), // Ocultar el error nativo ya que lo manejamos abajo
                ),
                dropdownColor: AppColors.surfaceContainerHigh,
                style: AppTextStyles.textStyleBody.copyWith(
                  color: enabled
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.expand_more,
                        color: AppColors.onSurfaceVariant,
                      ),
                items: isLoading
                    ? []
                    : _getUniqueItems(items).map((T item) {
                        return DropdownMenuItem<T>(
                          value: item,
                          child: Text(itemLabelBuilder(item)),
                        );
                      }).toList(),
                onChanged: enabled && !isLoading ? onChanged : null,
                isExpanded: true,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.spacingXxs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.spacingSm),
            child: Text(
              errorText!,
              style: AppTextStyles.textStyleCaption.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<T> _getUniqueItems(List<T> items) {
    final Set<T> uniqueItems = {};
    final List<T> result = [];
    for (var item in items) {
      if (uniqueItems.add(item)) {
        result.add(item);
      }
    }
    return result;
  }
}
