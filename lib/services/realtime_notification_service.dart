import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/app_logger.dart';

class RealtimeNotificationService {
  static final RealtimeNotificationService _instance =
      RealtimeNotificationService._internal();
  factory RealtimeNotificationService() => _instance;

  RealtimeNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  RealtimeChannel? _cotizacionesChannel;
  RealtimeChannel? _ordenesChannel;
  RealtimeChannel? _solicitudesChannel;
  RealtimeChannel? _ordenesStatusChannel;
  final List<RealtimeChannel> _multipleChannels = [];

  static const String _channelId = 'repuestosya_channel';
  static const String _channelName = 'RepuestosYa Notifications';
  static const String _channelDescription =
      'Notificaciones de RepuestosYa en tiempo real';

  Future<void> init() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          AppLogger.debug(
            'Notification clicked: ${response.payload}',
            name: 'RealtimeNotificationService',
          );
        },
      );

      // Canal Android creado EXPLÍCITAMENTE aquí, antes de que cualquier
      // showNotification() pueda ejecutarse (hasta ahora se creaba de forma
      // implícita en el primer show vía AndroidNotificationDetails).
      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
      }

      AppLogger.info(
        'RealtimeNotificationService initialized',
        name: 'RealtimeNotificationService',
      );
    } catch (e, st) {
      // Nunca propagar: un fallo del plugin no debe romper el arranque.
      AppLogger.error(
        'Error al inicializar RealtimeNotificationService',
        name: 'RealtimeNotificationService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Solicita el permiso nativo de notificaciones y devuelve el estado
  /// resultante para que el caller decida la UI (reintento / Ajustes).
  ///
  /// Manejo explícito de estados: concedido, denegado, denegado
  /// permanentemente y restringido, con log para cada rama. En Android < 13
  /// (sin `POST_NOTIFICATIONS`) y en plataformas no soportadas devuelve
  /// `granted` porque el permiso no aplica. NUNCA lanza: cualquier fallo de
  /// plataforma se registra y se degrada a `denied`.
  Future<PermissionStatus> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo =
            await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt < 33) {
          // Android < 13: no existe el permiso runtime de notificaciones.
          return PermissionStatus.granted;
        }
        final PermissionStatus status = await Permission.notification.request();
        AppLogger.debug(
          'Notification permission status: $status',
          name: 'RealtimeNotificationService',
        );
        if (status.isGranted) {
          AppLogger.info(
            'Notification permission granted',
            name: 'RealtimeNotificationService',
          );
        } else if (status.isPermanentlyDenied) {
          AppLogger.warning(
            'Notification permission permanently denied (solo Ajustes)',
            name: 'RealtimeNotificationService',
          );
        } else if (status.isRestricted) {
          AppLogger.warning(
            'Notification permission restricted',
            name: 'RealtimeNotificationService',
          );
        } else {
          AppLogger.warning(
            'Notification permission denied',
            name: 'RealtimeNotificationService',
          );
        }
        return status;
      }

      if (Platform.isIOS) {
        final bool? result = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        AppLogger.debug(
          'iOS notification permissions: $result',
          name: 'RealtimeNotificationService',
        );
        // En iOS un rechazo es definitivo: el sistema no vuelve a mostrar el
        // diálogo; la única vía es Ajustes (lo decide el caller según estado).
        return (result ?? false)
            ? PermissionStatus.granted
            : PermissionStatus.denied;
      }

      // Plataforma sin soporte (p. ej. tests en host): el permiso no aplica.
      return PermissionStatus.granted;
    } catch (e, st) {
      AppLogger.error(
        'Error al solicitar permiso de notificaciones',
        name: 'RealtimeNotificationService',
        error: e,
        stackTrace: st,
      );
      return PermissionStatus.denied;
    }
  }

  /// Verifica el permiso JUSTO ANTES de cada uso (revocado durante el uso):
  /// cubre el caso de que el usuario lo apague en Ajustes mientras la app
  /// corre. Nunca lanza.
  Future<bool> _tienePermisoNotificaciones() async {
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo =
            await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt < 33) return true;
        final status = await Permission.notification.status;
        return status.isGranted || status.isProvisional;
      }
      if (Platform.isIOS) {
        final status = await Permission.notification.status;
        return status.isGranted || status.isProvisional;
      }
      return false;
    } catch (e) {
      AppLogger.error(
        'Error al verificar permiso de notificaciones',
        name: 'RealtimeNotificationService',
        error: e,
      );
      return false;
    }
  }

  Future<void> showNotification(String title, String body) async {
    try {
      // Re-chequeo del permiso justo antes de cada uso: si el usuario lo
      // revocó en Ajustes mientras la app corría, no se muestra ni se pierde
      // tiempo en el canal nativo.
      if (!await _tienePermisoNotificaciones()) {
        AppLogger.debug(
          'Notificación omitida (permiso no concedido o revocado): $title',
          name: 'RealtimeNotificationService',
        );
        return;
      }

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
          );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
      );

      AppLogger.debug(
        'Notification shown: $title - $body',
        name: 'RealtimeNotificationService',
      );
    } catch (e, st) {
      // Los callbacks realtime llaman a showNotification sin await: un error
      // aquí no debe convertirse en una excepción no capturada.
      AppLogger.error(
        'Error al mostrar notificación: $title',
        name: 'RealtimeNotificationService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> subscribeToCotizaciones(String solicitudId) async {
    await _cotizacionesChannel?.unsubscribe();

    _cotizacionesChannel = Supabase.instance.client
        .channel('cotizaciones_$solicitudId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'cotizaciones',
          filter: PostgresChangeFilter(
            column: 'solicitud_id',
            type: PostgresChangeFilterType.eq,
            value: solicitudId,
          ),
          callback: (payload) {
            showNotification(
              '¡Nueva Cotización!',
              'Un almacén ha respondido a tu solicitud.',
            );
          },
        )
        .subscribe();

    AppLogger.info(
      'Subscribed to cotizaciones for solicitudId: $solicitudId',
      name: 'RealtimeNotificationService',
    );
  }

  Future<void> subscribeToOrdenes(String almacenId) async {
    await _ordenesChannel?.unsubscribe();

    _ordenesChannel = Supabase.instance.client
        .channel('ordenes_$almacenId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ordenes_compra',
          filter: PostgresChangeFilter(
            column: 'almacen_id',
            type: PostgresChangeFilterType.eq,
            value: almacenId,
          ),
          callback: (payload) {
            showNotification(
              '¡Orden Ganada!',
              'Un cliente aceptó tu cotización.',
            );
          },
        )
        .subscribe();

    AppLogger.info(
      'Subscribed to ordenes for almacenId: $almacenId',
      name: 'RealtimeNotificationService',
    );
  }

  Future<void> subscribeToAllMyRequests(List<String> solicitudIds) async {
    await unsubscribeMultiple();

    AppLogger.debug(
      'Iniciando suscripción a ${solicitudIds.length} solicitudes',
      name: 'REALTIME',
    );

    if (solicitudIds.isEmpty) {
      AppLogger.warning(
        '⚠️ No hay solicitudes para suscribir - lista vacía',
        name: 'REALTIME',
      );
      return;
    }

    for (final solicitudId in solicitudIds) {
      AppLogger.debug(
        'Suscribiendo a cotizaciones de solicitud: $solicitudId',
        name: 'REALTIME',
      );
      try {
        final channel = Supabase.instance.client
            .channel('cotizaciones_$solicitudId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'cotizaciones',
              filter: PostgresChangeFilter(
                column: 'solicitud_id',
                type: PostgresChangeFilterType.eq,
                value: solicitudId,
              ),
              callback: (payload) {
                AppLogger.debug(
                  '📩 Nueva cotización recibida para solicitud: $solicitudId - Payload: ${payload.newRecord}',
                  name: 'REALTIME',
                );
                showNotification(
                  '¡Nueva Cotización!',
                  'Un almacén ha respondido a tu solicitud.',
                );
              },
            )
            .subscribe((status, error) {
              AppLogger.debug(
                'Canal status para $solicitudId: $status',
                name: 'REALTIME',
              );
              if (error != null) {
                AppLogger.error(
                  'Error en canal $solicitudId: $error',
                  name: 'REALTIME',
                  error: error,
                );
              }
            });

        _multipleChannels.add(channel);
        AppLogger.debug(
          '✅ Canal creado para solicitud: $solicitudId',
          name: 'REALTIME',
        );
      } catch (e) {
        AppLogger.error(
          '❌ Error al suscribir a solicitud $solicitudId: $e',
          name: 'REALTIME',
          error: e,
        );
      }
    }

    AppLogger.info(
      '✅ Suscripción completada a ${solicitudIds.length} solicitudes',
      name: 'REALTIME',
    );
  }

  Future<void> unsubscribe() async {
    await _cotizacionesChannel?.unsubscribe();
    await _ordenesChannel?.unsubscribe();
    await _solicitudesChannel?.unsubscribe();
    await _ordenesStatusChannel?.unsubscribe();
    _cotizacionesChannel = null;
    _ordenesChannel = null;
    _solicitudesChannel = null;
    _ordenesStatusChannel = null;

    AppLogger.info(
      'Unsubscribed from all channels',
      name: 'RealtimeNotificationService',
    );
  }

  Future<void> unsubscribeMultiple() async {
    for (final channel in _multipleChannels) {
      await channel.unsubscribe();
    }
    _multipleChannels.clear();

    AppLogger.info(
      'Unsubscribed from multiple channels',
      name: 'RealtimeNotificationService',
    );
  }

  // 1. Para Almacenes: Escuchar nuevas solicitudes (Broadcast)
  Future<void> subscribeToNuevasSolicitudes() async {
    await _solicitudesChannel?.unsubscribe();
    AppLogger.info('👂 Escuchando nuevas solicitudes...', name: 'REALTIME');
    _solicitudesChannel = Supabase.instance.client
        .channel('solicitudes_broadcast')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'solicitudes_repuesto',
          callback: (payload) {
            AppLogger.debug(
              '📩 Nueva solicitud detectada: ${payload.newRecord['id']}',
              name: 'REALTIME',
            );
            showNotification(
              '¡Nueva Solicitud!',
              'Un cliente necesita un repuesto. Revisa tu dashboard.',
            );
          },
        )
        .subscribe();
  }

  // 2. Para Clientes: Escuchar cambios de estado en sus órdenes
  void subscribeToEstadoOrden(String clienteId) {
    AppLogger.info(
      '👂 Escuchando cambios en órdenes del cliente: $clienteId',
      name: 'REALTIME',
    );
    _ordenesStatusChannel = Supabase.instance.client
        .channel('ordenes_status_$clienteId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ordenes_compra',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'cliente_id',
            value: clienteId,
          ),
          callback: (payload) {
            final nuevoEstado = payload.newRecord['estado'] as String?;
            AppLogger.debug(
              '📩 Orden actualizada a: $nuevoEstado',
              name: 'REALTIME',
            );

            if (nuevoEstado == 'confirmada') {
              showNotification(
                '¡Orden Confirmada!',
                'El almacén ha confirmado tu pedido y lo está preparando.',
              );
            } else if (nuevoEstado == 'entregada') {
              showNotification(
                '¡Orden Entregada!',
                'Tu repuesto ha sido entregado. ¡Gracias por usar RepuestosYa!',
              );
            }
          },
        )
        .subscribe();
  }
}
