import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/welcome_page.dart';
import 'pages/orden_compra_page.dart';
import 'providers/user_role_provider.dart';
import 'providers/orden_compra_provider.dart';
import 'services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar ApiClient (carga el token desde SharedPreferences)
  await ApiClient().init();

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
        routes: {'/orden-compra': (context) => const OrdenCompraPage()},
      ),
    );
  }
}
