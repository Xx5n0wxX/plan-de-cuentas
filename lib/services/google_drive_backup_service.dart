import 'dart:convert';
import 'package:http/http.dart' as http;

class DriveBackupMetadata {
  final String fileId;
  final String name;
  final DateTime modifiedTime;
  final int sizeBytes;

  DriveBackupMetadata({
    required this.fileId,
    required this.name,
    required this.modifiedTime,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}

class GoogleDriveBackupService {
  static const String backupFileName = 'plan_de_cuentas_backup.json';
  static const String driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  /// Busca si existe una copia de seguridad en el contenedor oculto (appDataFolder) de Google Drive
  Future<DriveBackupMetadata?> findLatestBackup(String accessToken) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
      '?spaces=appDataFolder'
      '&q=${Uri.encodeComponent("name = '$backupFileName' and trashed = false")}'
      '&fields=${Uri.encodeComponent("files(id,name,modifiedTime,size)")}'
      '&orderBy=modifiedTime%20desc'
      '&pageSize=1',
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Error al consultar Google Drive (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final files = (data['files'] as List<dynamic>?) ?? [];
    if (files.isEmpty) return null;

    final file = files.first as Map<String, dynamic>;
    return DriveBackupMetadata(
      fileId: file['id'] as String,
      name: (file['name'] as String?) ?? backupFileName,
      modifiedTime: file['modifiedTime'] != null
          ? DateTime.parse(file['modifiedTime'] as String).toLocal()
          : DateTime.now(),
      sizeBytes: int.tryParse(file['size']?.toString() ?? '0') ?? 0,
    );
  }

  /// Sube o sobrescribe el respaldo en el appDataFolder de Google Drive (estilo WhatsApp)
  Future<DriveBackupMetadata> uploadBackup({
    required String accessToken,
    required Map<String, dynamic> backupData,
  }) async {
    final jsonContent = jsonEncode(backupData);
    final contentBytes = utf8.encode(jsonContent);

    // 1. Verificar si ya existe un archivo previo para actualizarlo o crear uno nuevo
    final existing = await findLatestBackup(accessToken);

    if (existing != null) {
      // Actualizar el archivo existente (PATCH media)
      final updateUri = Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files/${existing.fileId}?uploadType=media&fields=id,name,modifiedTime,size',
      );
      final response = await http.patch(
        updateUri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: contentBytes,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Error actualizando copia en Google Drive (${response.statusCode}): ${response.body}');
      }

      final updated = jsonDecode(response.body) as Map<String, dynamic>;
      return DriveBackupMetadata(
        fileId: (updated['id'] as String?) ?? existing.fileId,
        name: (updated['name'] as String?) ?? backupFileName,
        modifiedTime: updated['modifiedTime'] != null
            ? DateTime.parse(updated['modifiedTime'] as String).toLocal()
            : DateTime.now(),
        sizeBytes:
            int.tryParse(updated['size']?.toString() ?? '') ?? contentBytes.length,
      );
    } else {
      // Crear el archivo por primera vez en appDataFolder usando multipart/related
      const boundary = '===plan_de_cuentas_backup_boundary===';
      final metaJson = jsonEncode({
        'name': backupFileName,
        'parents': ['appDataFolder'],
        'mimeType': 'application/json',
      });

      final multipartBody = StringBuffer()
        ..write('--$boundary\r\n')
        ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
        ..write('$metaJson\r\n')
        ..write('--$boundary\r\n')
        ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
        ..write('$jsonContent\r\n')
        ..write('--$boundary--');

      final createUri = Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,modifiedTime,size',
      );

      final response = await http.post(
        createUri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: utf8.encode(multipartBody.toString()),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            'Error creando copia en Google Drive (${response.statusCode}): ${response.body}');
      }

      final created = jsonDecode(response.body) as Map<String, dynamic>;
      return DriveBackupMetadata(
        fileId: created['id'] as String,
        name: (created['name'] as String?) ?? backupFileName,
        modifiedTime: created['modifiedTime'] != null
            ? DateTime.parse(created['modifiedTime'] as String).toLocal()
            : DateTime.now(),
        sizeBytes:
            int.tryParse(created['size']?.toString() ?? '') ?? contentBytes.length,
      );
    }
  }

  /// Descarga y decodifica la copia de seguridad desde Google Drive
  Future<Map<String, dynamic>> downloadBackup({
    required String accessToken,
    required String fileId,
  }) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Error descargando copia desde Google Drive (${response.statusCode}): ${response.body}');
    }

    final decoded = utf8.decode(response.bodyBytes);
    return jsonDecode(decoded) as Map<String, dynamic>;
  }
}
