import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://vpgnasrlgdgkxpggorxl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwZ25hc3JsZ2Rna3hwZ2dvcnhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Njg0MzgsImV4cCI6MjA5NjQ0NDQzOH0.iENx5XVTyvr2-GLqOKqPzxwsekThJu1PNGDDpDfrOOE',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
