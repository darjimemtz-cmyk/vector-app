import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';

class ActualizacionService {
  // Versión actual instalada en esta compilación
  static const int versionCodigoActual = 2;

  static const String _urlFirebase =
      'https://vektor-pos-default-rtdb.firebaseio.com/actualizacion.json';

  /// Consulta Firebase y retorna la información si hay una versión superior
  static Future<Map<String, dynamic>?> verificarActualizacion() async {
    try {
      final respuesta = await http.get(Uri.parse(_urlFirebase));
      if (respuesta.statusCode == 200 && respuesta.body != 'null') {
        final Map<String, dynamic> datos = jsonDecode(respuesta.body);
        final int versionRemota = datos['version_codigo'] ?? 0;

        if (versionRemota > versionCodigoActual) {
          return datos;
        }
      }
    } catch (_) {
      // Si no hay conexión o falla la nube, continúa la venta normal
    }
    return null;
  }

  /// Descarga el APK desde GitHub y ejecuta el instalador nativo de Android
  static Stream<OtaEvent> descargarEInstalar(String urlDescarga) {
    if (!urlDescarga.startsWith('https://')) {
      throw ArgumentError('URL insegura: se requiere HTTPS');
    }
    return OtaUpdate().execute(
      urlDescarga,
      destinationFilename: 'Vector.apk',
    );
  }
}