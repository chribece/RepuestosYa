import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  /// Sube una imagen al bucket `Repuestosya` bajo la ruta:
  /// `evidencias/solicitudes/{clienteId}/solicitud_{key}.{ext}`
  ///
  /// [idempotencyKey] (UUID del Outbox) determina el nombre del objeto: un
  /// reintento con la misma key sobrescribe el MISMO objeto (upsert) en vez
  /// de crear un duplicado (corrige el hallazgo [12]). Sin key se usa un
  /// timestamp y `upsert: false`.
  Future<String?> uploadRequestImage(
    File imageFile,
    String clienteId, {
    String? idempotencyKey,
  }) {
    return _upload(
      imageFile,
      folder: 'solicitudes',
      ownerId: clienteId,
      prefix: 'solicitud',
      idempotencyKey: idempotencyKey,
    );
  }

  /// Sube una imagen al bucket `Repuestosya` bajo la ruta:
  /// `evidencias/cotizaciones/{almacenId}/cotizacion_{key}.{ext}`
  ///
  /// Mismo patrón que [uploadRequestImage], segmentado por dominio funcional.
  Future<String?> uploadQuotationImage(
    File imageFile,
    String almacenId, {
    String? idempotencyKey,
  }) {
    return _upload(
      imageFile,
      folder: 'cotizaciones',
      ownerId: almacenId,
      prefix: 'cotizacion',
      idempotencyKey: idempotencyKey,
    );
  }

  Future<String?> _upload(
    File imageFile, {
    required String folder,
    required String ownerId,
    required String prefix,
    String? idempotencyKey,
  }) async {
    try {
      AppLogger.debug(
        '[UPLOAD] Iniciando subida de imagen ($folder)...',
        name: 'UploadService',
      );

      final supabase = Supabase.instance.client;

      // Verificar sesión de autenticación
      final session = supabase.auth.currentSession;
      if (session == null) {
        AppLogger.warning(
          '[UPLOAD] No hay sesión activa. Intentando refrescar...',
          name: 'UploadService',
        );
        try {
          await supabase.auth.refreshSession();
          AppLogger.info('[UPLOAD] Sesión refrescada', name: 'UploadService');
        } catch (e) {
          AppLogger.error(
            '[UPLOAD] Error al refrescar sesión',
            name: 'UploadService',
            error: e,
          );
          return null;
        }
      }

      // Nombre determinista con la key de idempotencia (reintentos → mismo
      // objeto, sin duplicados) o timestamp como fallback. Se conserva la
      // extensión real del archivo y el contentType correspondiente en vez de
      // forzar siempre .jpg/image/jpeg.
      final ext = _extensionFor(imageFile);
      final namePart = idempotencyKey ?? '${DateTime.now().millisecondsSinceEpoch}';
      final fileName = '${prefix}_$namePart.$ext';
      final filePath = 'evidencias/$folder/$ownerId/$fileName';

      // Subir al bucket `Repuestosya`
      await supabase.storage
          .from('Repuestosya')
          .upload(
            filePath,
            imageFile,
            fileOptions: FileOptions(
              cacheControl: '3600',
              // Con key determinista, un reintento sobrescribe el mismo
              // objeto; sin key, los nombres por timestamp nunca chocan.
              upsert: idempotencyKey != null,
              contentType: _contentTypeFor(ext),
            ),
          );

      // Obtener URL pública
      final publicUrl = supabase.storage
          .from('Repuestosya')
          .getPublicUrl(filePath);

      AppLogger.info(
        '[UPLOAD] URL pública obtenida: $publicUrl',
        name: 'UploadService',
      );

      return publicUrl;
    } catch (e, stackTrace) {
      AppLogger.error(
        '[UPLOAD] Error al subir imagen',
        name: 'UploadService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Extensión real del archivo sin el punto (p. ej. `jpg`, `png`, `heic`).
  /// Fallback a `jpg` si no se puede determinar.
  String _extensionFor(File file) {
    final ext = p.extension(file.path).toLowerCase();
    if (ext.isEmpty) return 'jpg';
    return ext.substring(1);
  }

  /// Mapea la extensión real al `contentType` correcto para Storage.
  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
