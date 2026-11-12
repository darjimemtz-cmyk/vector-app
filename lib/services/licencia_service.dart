import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class LicenciaService {
  // Enlace a tu base de datos Firebase Realtime Database (REST API gratuita)
  static const String _firebaseUrl = "https://vektor-pos-default-rtdb.firebaseio.com";
  // Llave secreta maestra para cálculo matemático de claves
  static const String _secretKey = String.fromEnvironment('VEKTOR_SECRET', defaultValue: 'FNG2026POS');

  /// Obtiene un Terminal ID único e inmutable basado en el hardware físico de Android
  static Future<String> obtenerTerminalId() async {
    final prefs = await SharedPreferences.getInstance();
    String? idGuardado = prefs.getString('terminal_id');
    if (idGuardado != null && idGuardado.isNotEmpty) {
      return idGuardado;
    }

    String rawId = "DEMO1001";
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // androidId es inmutable y único por dispositivo físico
        rawId = androidInfo.id.toUpperCase();
      }
    } catch (e) {
      debugPrint("Error obteniendo hardware id: $e");
    }

    // Derivamos un hash numérico corto de 4 dígitos para que sea amigable en WhatsApp
    int hash = 0;
    for (int i = 0; i < rawId.length; i++) {
      hash = (hash * 37 + rawId.codeUnitAt(i)) % 9000;
    }
    final terminalId = "POS-${1000 + hash}";
    await prefs.setString('terminal_id', terminalId);
    return terminalId;
  }

  /// Consulta el switch y la fecha límite en Firebase. Si no hay internet, no truena la app.
  static Future<bool> sincronizarEnLinea() async {
    try {
      final terminalId = await obtenerTerminalId();
      final url = Uri.parse("$_firebaseUrl/licencias/$terminalId.json");

      final respuesta = await http.get(url).timeout(const Duration(seconds: 4));
      if (respuesta.statusCode == 200 && respuesta.body != "null") {
        final data = jsonDecode(respuesta.body);
        final bool activo = data['activo'] == true;
        final String? venceStr = data['vence'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('licencia_switch_activo', activo);
        if (venceStr != null && venceStr.isNotEmpty) {
          await prefs.setString('licencia_vencimiento', venceStr);
        }
        return activo;
      }
    } catch (e) {
      debugPrint("Modo offline: sin internet para sincronizar licencia ($e)");
    }
    return false;
  }

  /// Verifica si la suscripción sigue vigente (incluyendo detección anti-manipulación de hora)
  static Future<bool> isLicenciaValida() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1. Control Anti-Time-Travel (si retrasan la hora del sistema deliberadamente)
    final ultimoUsoStr = prefs.getString('licencia_ultimo_uso');
    if (ultimoUsoStr != null) {
      final ultimoUso = DateTime.parse(ultimoUsoStr);
      if (now.isBefore(ultimoUso.subtract(const Duration(minutes: 5)))) {
        return false;
      }
    }
    await prefs.setString('licencia_ultimo_uso', now.toIso8601String());

    // 2. Control de Switch Remoto
    final switchActivo = prefs.getBool('licencia_switch_activo') ?? false;
    if (!switchActivo) {
      return false;
    }

    // 3. Control de Fecha Límite automática
    final vencimientoStr = prefs.getString('licencia_vencimiento');
    if (vencimientoStr == null) {
      return false;
    }

    final vencimiento = DateTime.parse(vencimientoStr);
    return now.isBefore(vencimiento);
  }

  /// Devuelve la fecha exacta de expiración
  static Future<DateTime> obtenerFechaVencimiento() async {
    final prefs = await SharedPreferences.getInstance();
    final vencimientoStr = prefs.getString('licencia_vencimiento');
    if (vencimientoStr == null) {
      return DateTime.now(); // Marca vencida desde el inicio
    }
    return DateTime.parse(vencimientoStr);
  }

  /// Algoritmo con efecto avalancha criptográfico (imposible de adivinar o predecir)
  static String calcularClave(String terminalId, [String? periodo]) {
    final now = DateTime.now();
    final p = periodo ?? "${now.year}${now.month.toString().padLeft(2, '0')}";
    final inputStr = "${terminalId.trim().toUpperCase()}_${p}_$_secretKey";

    // FNV-1a Hash de 32 bits
    int h = 0x811C9DC5;
    for (int i = 0; i < inputStr.length; i++) {
      h ^= inputStr.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }

    // Mezclador de Avalancha Murmur3 (fmix32): dispersión caótica
    h ^= (h >> 16);
    h = (h * 0x85ebca6b) & 0xFFFFFFFF;
    h ^= (h >> 13);
    h = (h * 0xc2b2ae35) & 0xFFFFFFFF;
    h ^= (h >> 16);
    h = h & 0xFFFFFFFF;

    return ((h % 900000) + 100000).toString();
  }

  // Datos bancarios oficiales para visualización y copiado
  static const String banco = "Santander";
  static const String clabe = "014700569481983803";
  static const String costoMensual = "\$200 MXN";

  /// Copia la CLABE directa al portapapeles
  static Future<void> copiarClabe() async {
    await Clipboard.setData(const ClipboardData(text: clabe));
  }

  /// Valida la clave mensual y quema el código para evitar reutilizaciones
  static Future<bool> activarLicencia(String codigoIngresado) async {
    final terminalId = await obtenerTerminalId();
    final prefs = await SharedPreferences.getInstance();
    final codigo = codigoIngresado.trim();

    final now = DateTime.now();
    // Revisa mes actual, siguiente y anterior (por compras anticipadas o límites de mes)
    final periodosCandidatos = [
      "${now.year}${now.month.toString().padLeft(2, '0')}",
      "${DateTime(now.year, now.month + 1, 1).year}${DateTime(now.year, now.month + 1, 1).month.toString().padLeft(2, '0')}",
      "${DateTime(now.year, now.month - 1, 1).year}${DateTime(now.year, now.month - 1, 1).month.toString().padLeft(2, '0')}",
      "${DateTime(now.year, now.month + 2, 1).year}${DateTime(now.year, now.month + 2, 1).month.toString().padLeft(2, '0')}",
    ];

    final periodosCanjeados = prefs.getStringList('licencia_periodos_canjeados') ?? [];

    for (final periodo in periodosCandidatos) {
      if (codigo == calcularClave(terminalId, periodo)) {
        // Antitrampas: Si este mes ya fue canjeado en esta terminal, se rechaza
        if (periodosCanjeados.contains(periodo)) {
          return false;
        }

        // Quema el periodo para que jamás puedan volverlo a meter
        periodosCanjeados.add(periodo);
        await prefs.setStringList('licencia_periodos_canjeados', periodosCanjeados);

        final actual = await obtenerFechaVencimiento();
        final base = actual.isAfter(DateTime.now()) ? actual : DateTime.now();
        final nuevaFecha = base.add(const Duration(days: 30));
        await prefs.setString('licencia_vencimiento', nuevaFecha.toIso8601String());
        await prefs.setBool('licencia_switch_activo', true);
        return true;
      }
    }

    return false;
  }
}