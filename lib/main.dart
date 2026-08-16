import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/welcome_page.dart';
import 'pages/orden_compra_page.dart';
import 'providers/user_role_provider.dart';
import 'providers/orden_compra_provider.dart';
import 'services/api_client.dart';
import 'services/realtime_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase (necesario al inicio)
  try {
    await Supabase.initialize(
      url: 'https://vpgnasrlgdgkxpggorxl.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwZ25hc3JsZ2Rna3hwZ2dvcnhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Njg0MzgsImV4cCI6MjA5NjQ0NDQzOH0.iENx5XVTyvr2-GLqOKqPzxwsekThJu1PNGDDpDfrOOE',
    );
    print('[SUPABASE] ✅ Inicializado correctamente');
    print('[SUPABASE] URL: https://vpgnasrlgdgkxpggorxl.supabase.co');
  } catch (e) {
    print('[SUPABASE] ❌ Error de inicialización: $e');
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
      ],
      child: MaterialApp(
        title: 'RepuestosYa',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF5722),
            brightness: Brightness.dark,
          ),
        ),
        home: const WelcomePage(),
        routes: {
          '/orden-compra': (context) => const OrdenCompraPage(),
        },
      ),
    );
  }
}
