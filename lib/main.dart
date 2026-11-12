import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/venta_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const MiPosApp());
}

class MiPosApp extends StatefulWidget {
  const MiPosApp({super.key});

  @override
  State<MiPosApp> createState() => _MiPosAppState();
}

class _MiPosAppState extends State<MiPosApp> {
  bool _modoNoche = false;

  void _alternarModoNoche() {
    setState(() => _modoNoche = !_modoNoche);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Lite',
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF3AA6C8),
      ),
      home: VentaScreen(
        initialDarkMode: _modoNoche,
        isDarkMode: _modoNoche,
        onThemeToggle: _alternarModoNoche,
      ),
    );
  }
}