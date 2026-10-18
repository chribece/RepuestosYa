import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/notificaciones_provider.dart';
import '../router/route_names.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class RyNotificationBell extends StatelessWidget {
  final Future<void> Function()? onPressed;

  const RyNotificationBell({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificacionesProvider?>();
    final count = provider?.unreadCount ?? 0;
    final semanticLabel = count == 0
        ? 'Notificaciones'
        : count == 1
        ? '1 notificación sin leer'
        : '$count notificaciones sin leer';

    Future<void> openNotifications() async {
      if (onPressed != null) {
        await onPressed!();
        return;
      }
      await context.pushNamed(RouteNames.notifications);
      if (context.mounted) await provider?.refrescar();
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: () => unawaited(openNotifications()),
      child: ExcludeSemantics(
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => unawaited(openNotifications()),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.onSurface,
                    size: 24,
                  ),
                  if (count > 0)
                    Positioned(
                      top: AppSpacing.spacingXxs,
                      right: AppSpacing.spacingXxs,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.spacingXxs,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(
                            AppRadius.radiusFull,
                          ),
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: AppTextStyles.textStyleSmall.copyWith(
                            color: AppColors.onSurface,
                            height: 1,
                            letterSpacing: 0,
                          ),
                          textAlign: TextAlign.center,
                        ),
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
