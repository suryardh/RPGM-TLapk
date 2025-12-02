import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/services/background_service.dart';
import 'features/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Minta izin notifikasi di awal
  await Permission.notification.request();
  
  // Inisialisasi Service Background
  await initializeService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPGM Translator',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark, // Tema Gelap biar keren kayak terminal
      ),
      home: const HomeScreen(),
    );
  }
}
