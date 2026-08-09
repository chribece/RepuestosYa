import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  List<RealtimeChannel> _multipleChannels = [];

  static const String _channelId = 'repuestosya_channel';
  static const String _channelName = 'RepuestosYa Notifications';
  static const String _channelDescription =
      'Notificaciones de RepuestosYa en tiempo real';

  Future<void> init() async {
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
        if (kDebugMode) {
          print('Notification clicked: ${response.payload}');
        }
      },
    );

    if (kDebugMode) {
      print('RealtimeNotificationService initialized');
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo =
          await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final PermissionStatus status = await Permission.notification.request();
        if (kDebugMode) {
          print('Notification permission status: $status');
        }
        if (status.isDenied) {
          if (kDebugMode) {
            print('Notification permission denied');
          }
        }
      }
    } else if (Platform.isIOS) {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      if (kDebugMode) {
        print('iOS notification permissions: $result');
      }
    }
  }

  Future<void> showNotification(String title, String body) async {
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

    if (kDebugMode) {
      print('Notification shown: $title - $body');
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

    if (kDebugMode) {
      print('Subscribed to cotizaciones for solicitudId: $solicitudId');
    }
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

    if (kDebugMode) {
      print('Subscribed to ordenes for almacenId: $almacenId');
    }
  }

  Future<void> subscribeToAllMyRequests(List<String> solicitudIds) async {
    await unsubscribeMultiple();

    if (kDebugMode) {
      print(
        '[REALTIME] Iniciando suscripción a ${solicitudIds.length} solicitudes',
      );
    }

    if (solicitudIds.isEmpty) {
      if (kDebugMode) {
        print('[REALTIME] ⚠️ No hay solicitudes para suscribir - lista vacía');
      }
      return;
    }

    for (final solicitudId in solicitudIds) {
      if (kDebugMode) {
        print(
          '[REALTIME] Suscribiendo a cotizaciones de solicitud: $solicitudId',
        );
      }
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
                if (kDebugMode) {
                  print(
                    '[REALTIME] 📩 Nueva cotización recibida para solicitud: $solicitudId',
                  );
                  print('[REALTIME] Payload: ${payload.newRecord}');
                }
                showNotification(
                  '¡Nueva Cotización!',
                  'Un almacén ha respondido a tu solicitud.',
                );
              },
            )
            .subscribe((status, error) {
              if (kDebugMode) {
                print('[REALTIME] Canal status para $solicitudId: $status');
                if (error != null) {
                  print('[REALTIME] Error en canal $solicitudId: $error');
                }
              }
            });

        _multipleChannels.add(channel);
        if (kDebugMode) {
          print('[REALTIME] ✅ Canal creado para solicitud: $solicitudId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('[REALTIME] ❌ Error al suscribir a solicitud $solicitudId: $e');
        }
      }
    }

    if (kDebugMode) {
      print(
        '[REALTIME] ✅ Suscripción completada a ${solicitudIds.length} solicitudes',
      );
    }
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

    if (kDebugMode) {
      print('Unsubscribed from all channels');
    }
  }

  Future<void> unsubscribeMultiple() async {
    for (final channel in _multipleChannels) {
      await channel.unsubscribe();
    }
    _multipleChannels.clear();

    if (kDebugMode) {
      print('Unsubscribed from multiple channels');
    }
  }

  // 1. Para Almacenes: Escuchar nuevas solicitudes (Broadcast)
  void subscribeToNuevasSolicitudes() {
    if (kDebugMode) {
      print('[REALTIME] 👂 Escuchando nuevas solicitudes...');
    }
    _solicitudesChannel = Supabase.instance.client
        .channel('solicitudes_broadcast')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'solicitudes_repuesto',
          callback: (payload) {
            if (kDebugMode) {
              print(
                '[REALTIME] 📩 Nueva solicitud detectada: ${payload.newRecord['id']}',
              );
            }
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
    if (kDebugMode) {
      print(
        '[REALTIME] 👂 Escuchando cambios en órdenes del cliente: $clienteId',
      );
    }
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
            if (kDebugMode) {
              print('[REALTIME] 📩 Orden actualizada a: $nuevoEstado');
            }

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
