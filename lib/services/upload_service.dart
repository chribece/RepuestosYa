import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  /// Sube una imagen al bucket `Repuestosya` bajo la ruta:
  /// `evidencias/solicitudes/{clienteId}/solicitud_{timestamp}.jpg`
  Future<String?> uploadRequestImage(File imageFile, String clienteId) async {
    try {
      AppLogger.debug(
        '[UPLOAD] Iniciando subida de imagen de solicitud...',
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

      // Generar nombre único
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'solicitud_$timestamp.jpg';
      final filePath = 'evidencias/solicitudes/$clienteId/$fileName';

      // Subir al bucket `Repuestosya`
      await supabase.storage
          .from('Repuestosya')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
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
}
