import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static const String _keyMacImpresora = 'impresora_mac_guardada';
  static const MethodChannel _zebraChannel = MethodChannel('com.example.pos_lite_app/zebra');

  /// Obtiene la dirección MAC de la impresora guardada en memoria
  static Future<String?> obtenerImpresoraGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMacImpresora) ?? 'F8:8A:5E:B7:B5:71';
  }

  /// Guarda la impresora favorita para reconectar en automático
  static Future<void> guardarImpresora(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMacImpresora, mac);
  }

  /// Lista los dispositivos Bluetooth ya vinculados al teléfono
  static Future<List<BluetoothInfo>> obtenerDispositivosVinculados() async {
    if (kIsWeb) return [];
    try {
      final bool bluetoothActivo = await PrintBluetoothThermal.bluetoothEnabled;
      if (!bluetoothActivo) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      debugPrint('Error al listar bluetooth: $e');
      return [];
    }
  }

  /// Envía el código ZPL directamente a través de Zebra PrintConnect
  static Future<bool> imprimirTicketZPL(String zpl) async {
    try {
      final res = await _zebraChannel.invokeMethod<bool>('imprimirZebra', {'zpl': zpl});
      return res ?? true;
    } catch (e) {
      debugPrint('Error enviando a PrintConnect: $e');
      return false;
    }
  }
}