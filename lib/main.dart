import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/user_role_provider.dart';
import 'providers/orden_compra_provider.dart';
import 'providers/create_request_provider.dart';
import 'providers/solicitudes_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/realtime_notification_service.dart';
import 'services/solicitud_repository.dart';
import 'services/outbox.dart';
import 'services/sync_engine.dart';
import 'database/app_database.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase (necesario al inicio)
  try {
    await Supabase.initialize(
      url: 'https://vpgnasrlgdgkxpggorxl.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwZ25hc3JsZ2Rna3hwZ2dvcnhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Njg0MzgsImV4cCI6MjA5NjQ0NDQzOH0.iENx5XVTyvr2-GLqOKqPzxwsekThJu1PNGDDpDfrOOE',
    );
    AppLogger.info('Supabase inicializado correctamente', name: 'Supabase');
    AppLogger.info(
      'URL: https://vpgnasrlgdgkxpggorxl.supabase.co',
      name: 'Supabase',
    );
  } catch (e, st) {
    AppLogger.error(
      'Error de inicialización de Supabase',
      name: 'Supabase',
      error: e,
      stackTrace: st,
    );
  }

  // Inicializar el cliente de API (Lectura de token rápida)
  await ApiClient().init();

  // Inicializar validación de sesión en background (Llamada a red lenta)
  AuthService().init();

  // Inicializar notificaciones en background después de que la app cargue
  Future.delayed(const Duration(milliseconds: 500), () async {
    await RealtimeNotificationService().init();
    await RealtimeNotificationService().requestPermissions();
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AppDatabase database = AppDatabase();
  late final SolicitudRepository solicitudRepository;
  late final OutboxService outboxService;
  late final SyncEngine syncEngine;

  MyApp({super.key}) {
    solicitudRepository = SolicitudRepository(database);
    outboxService = OutboxService(database);
    syncEngine = SyncEngine(outboxService, solicitudRepository);

    // Configurar limpieza de logout
    AuthService().onLogoutCleanup = () async {
      await solicitudRepository.clearAll();
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<SolicitudRepository>.value(value: solicitudRepository),
        Provider<OutboxService>.value(value: outboxService),
        Provider<SyncEngine>.value(value: syncEngine),
        ChangeNotifierProvider(create: (_) => UserRoleProvider()),
        ChangeNotifierProvider(create: (_) => OrdenCompraProvider()),
        ChangeNotifierProvider(create: (_) => CreateRequestProvider()),
        ChangeNotifierProvider(
          create: (_) => SolicitudesProvider(solicitudRepository),
        ),
      ],
      child: Consumer<UserRoleProvider>(
        builder: (context, roleProvider, child) {
          return MaterialApp.router(
            title: 'RepuestosYa',
            debugShowCheckedModeBanner: false,
            theme: darkTheme,
            routerConfig: AppRouter.getRouter(roleProvider),
          );
        },
      ),
    );
  }
}
