import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/user_role_provider.dart';
import 'providers/orden_compra_provider.dart';
import 'providers/create_request_provider.dart';
import 'services/api_client.dart';
import 'services/realtime_notification_service.dart';
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

  // Inicializar ApiClient en background
  ApiClient().init();

  // Inicializar notificaciones en background después de que la app cargue
  Future.delayed(const Duration(milliseconds: 500), () async {
    await RealtimeNotificationService().init();
    await RealtimeNotificationService().requestPermissions();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserRoleProvider()),
        ChangeNotifierProvider(create: (_) => OrdenCompraProvider()),
        ChangeNotifierProvider(create: (_) => CreateRequestProvider()),
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
