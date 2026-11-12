import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
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

  /// Descarga el APK desde GitHub de forma segura y abre el instalador nativo
  /// - Sigue redirecciones HTTPS
  /// - Valida statusCode == 200
  /// - Verifica que el archivo pese > 1,000,000 bytes
  /// - Guarda en directorio temporal
  /// - Abre con MIME type explícito 'application/vnd.android.package-archive'
  /// - Emite eventos de progreso compatibles con OtaEvent (DOWNLOADING, INSTALLING, DONE, ERROR)
  static Stream<OtaEvent> descargarEInstalar(String urlDescarga) {
    if (!urlDescarga.startsWith('https://')) {
      throw ArgumentError('URL insegura: se requiere HTTPS');
    }

    final controller = StreamController<OtaEvent>();

    // Ejecutar descarga en background
    Future.microtask(() async {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(urlDescarga));
        request.followRedirects = true;

        final streamedResponse = await client.send(request);

        // Validar statusCode
        if (streamedResponse.statusCode != 200) {
          controller.addError(Exception(
            'Error HTTP ${streamedResponse.statusCode} al descargar el APK',
          ));
          await controller.close();
          return;
        }

        // Validar content-length > 1MB (evita guardar HTML de error)
        final contentLength = streamedResponse.contentLength ?? 0;
        if (contentLength <= 1000000) {
          controller.addError(FormatException(
            'Archivo descargado demasiado pequeño ($contentLength bytes). '
            'Posible página de error en lugar del APK.',
          ));
          await controller.close();
          return;
        }

        // Guardar en directorio temporal
        final tempDir = await getTemporaryDirectory();
        final apkFile = File('${tempDir.path}/vektor_update.apk');

        final sink = apkFile.openWrite();
        int downloaded = 0;

        // Emitir progreso de descarga
        await for (final chunk in streamedResponse.stream) {
          downloaded += chunk.length;
          sink.add(chunk);
          
          if (contentLength > 0) {
            final progress = (downloaded / contentLength * 100).round();
            controller.add(OtaEvent(OtaStatus.DOWNLOADING, progress.toString()));
          }
        }

        await sink.flush();
        await sink.close();

        // Verificar tamaño real del archivo guardado
        final fileStat = await apkFile.stat();
        if (fileStat.size <= 1000000) {
          await apkFile.delete();
          controller.addError(FormatException(
            'Archivo guardado demasiado pequeño (${fileStat.size} bytes). '
            'Descarta posible archivo corrupto o HTML de error.',
          ));
          await controller.close();
          return;
        }

        // Emitir evento de instalación
        controller.add(OtaEvent(OtaStatus.INSTALLING, '100'));

        // Abrir instalador con MIME type explícito
        final result = await OpenFile.open(
          apkFile.path,
          type: 'application/vnd.android.package-archive',
        );

        // Validar resultado de apertura
        if (result.type != ResultType.done) {
          final errorMsg = result.message.isNotEmpty
              ? result.message
              : 'Error desconocido al abrir el instalador';
          controller.addError(Exception('No se pudo abrir el instalador: $errorMsg'));
          await controller.close();
          return;
        }

        // Éxito
        controller.add(OtaEvent(OtaStatus.INSTALLATION_DONE, '100'));
        await controller.close();
      } catch (e, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(e, stackTrace);
          await controller.close();
        }
      } finally {
        client.close();
      }
    });

    return controller.stream;
  }
}