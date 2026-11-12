import 'package:flutter/material.dart';
import 'screens/venta_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MiPosApp());
}

class MiPosApp extends StatelessWidget {
  const MiPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Lite',
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF3AA6C8),
      ),
      home: const VentaScreen()    );
  }
}