import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ClientBottomNavigationBar extends StatelessWidget {
  const ClientBottomNavigationBar({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = [
    (label: 'Inicio', icon: Icons.home_rounded, route: RouteNames.home),
    (
      label: 'Solicitudes',
      icon: Icons.assignment_rounded,
      route: RouteNames.solicitudes,
    ),
    (
      label: 'Órdenes',
      icon: Icons.shopping_cart_rounded,
      route: RouteNames.misOrdenes,
    ),
    (label: 'Perfil', icon: Icons.person_rounded, route: RouteNames.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('bottom-nav-bar'),
      color: AppColors.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              children: [
                for (var index = 0; index < _items.length; index++)
                  Expanded(
                    child: _buildItem(
                      context,
                      item: _items[index],
                      selected: currentIndex == index,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required ({String label, IconData icon, String route}) item,
    required bool selected,
  }) {
    final color = selected
        ? AppColors.primaryContainer
        : AppColors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: selected ? null : () => context.goNamed(item.route),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: color, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
