import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/login_page.dart';
import 'providers/user_role_provider.dart';
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
        home: const LoginPage(),
      ),
    );
  }
}
