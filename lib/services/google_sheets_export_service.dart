import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../providers/finance_provider.dart';
import 'excel_export_service.dart';

class GoogleSheetExportResult {
  final String fileId;
  final String name;
  final String webViewLink;

  GoogleSheetExportResult({
    required this.fileId,
    required this.name,
    required this.webViewLink,
  });
}

class GoogleSheetsExportService {
  static final GoogleSheetsExportService _instance =
      GoogleSheetsExportService._internal();
  static GoogleSheetsExportService get instance => _instance;

  GoogleSheetsExportService._internal();

  /// Convierte y sube el modelo financiero de 11 módulos a una hoja de cálculo nativa de Google Sheets
  Future<GoogleSheetExportResult> exportToGoogleSheets({
    required FinanceProvider provider,
    required String accessToken,
    String? customTitle,
  }) async {
    final title = customTitle ??
        'Plan de Cuentas - ${DateFormat("dd/MM/yyyy HH:mm", 'es_CL').format(DateTime.now())}';

    // 1. Generar libro de trabajo Excel estructurado con los 11 módulos
    final excel = ExcelExportService.buildExcelDocument(provider);
    final excelBytes = Uint8List.fromList(excel.save() ?? []);
    if (excelBytes.isEmpty) {
      throw Exception('No se pudieron generar los datos para Google Sheets');
    }

    // 2. Preparar subida multipart a Google Drive con conversión automática a hoja de cálculo de Google
    const boundary = '===plan_de_cuentas_sheets_boundary===';
    final metadataJson = jsonEncode({
      'name': title,
      'mimeType': 'application/vnd.google-apps.spreadsheet',
    });

    final headerBytes = utf8.encode(
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$metadataJson\r\n'
      '--$boundary\r\n'
      'Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n',
    );
    final footerBytes = utf8.encode('\r\n--$boundary--');

    final bb = BytesBuilder();
    bb.add(headerBytes);
    bb.add(excelBytes);
    bb.add(footerBytes);
    final fullBody = bb.toBytes();

    final uploadUri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files'
      '?uploadType=multipart'
      '&fields=id,name,webViewLink',
    );

    final response = await http.post(
      uploadUri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
        'Accept': 'application/json',
      },
      body: fullBody,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('Google Sheets upload error: ${response.statusCode} - ${response.body}');
      throw Exception(
        'Error creando hoja de cálculo (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final fileId = (data['id'] as String?) ?? '';
    final name = (data['name'] as String?) ?? title;
    final webViewLink = (data['webViewLink'] as String?) ??
        'https://docs.google.com/spreadsheets/d/$fileId/edit';

    return GoogleSheetExportResult(
      fileId: fileId,
      name: name,
      webViewLink: webViewLink,
    );
  }
}
