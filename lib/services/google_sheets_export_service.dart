import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../providers/finance_provider.dart';
import 'excel_export_service.dart';

class GoogleSheetsPermissionException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  GoogleSheetsPermissionException(
    this.message, {
    this.statusCode = 403,
    this.responseBody = '',
  });

  @override
  String toString() => message;
}

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

    // 1. Generar libro de trabajo estructurado con los 11 módulos
    final excel = ExcelExportService.buildExcelDocument(provider);

    // Estrategia 1: API nativa de Google Sheets v4 (evita restricciones de carpeta en Drive)
    try {
      final result = await _exportViaGoogleSheetsApi(
        excel: excel,
        title: title,
        accessToken: accessToken,
      );
      if (result != null) return result;
    } catch (e) {
      debugPrint('Exportación vía Sheets API v4 falló o requiere permisos: $e');
      if (e is GoogleSheetsPermissionException) {
        // Intentar fallback multipart antes de lanzar excepción definitiva
      }
    }

    // Estrategia 2: Subida multipart a Google Drive con conversión a hoja de cálculo
    return await _exportViaGoogleDriveMultipart(
      excel: excel,
      title: title,
      accessToken: accessToken,
    );
  }

  /// Estrategia nativa mediante Google Sheets API v4
  Future<GoogleSheetExportResult?> _exportViaGoogleSheetsApi({
    required Excel excel,
    required String title,
    required String accessToken,
  }) async {
    // 1. Crear la hoja con las pestañas de los módulos
    final sheetsMeta = <Map<String, dynamic>>[];
    for (final sheetName in excel.tables.keys) {
      sheetsMeta.add({
        'properties': {
          'title': sheetName,
        }
      });
    }

    final createUri =
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets');
    final createRes = await http.post(
      createUri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'properties': {'title': title},
        'sheets': sheetsMeta,
      }),
    );

    if (createRes.statusCode == 401 || createRes.statusCode == 403) {
      debugPrint('Sheets API v4 403: ${createRes.body}');
      throw GoogleSheetsPermissionException(
        'Tu cuenta de Google requiere autorizar el permiso para crear hojas de cálculo en Google Sheets.',
        statusCode: createRes.statusCode,
        responseBody: createRes.body,
      );
    }

    if (createRes.statusCode != 200 && createRes.statusCode != 201) {
      debugPrint('Sheets API create error (${createRes.statusCode}): ${createRes.body}');
      return null;
    }

    final data = jsonDecode(createRes.body) as Map<String, dynamic>;
    final spreadsheetId = (data['spreadsheetId'] as String?) ?? '';
    final spreadsheetUrl = (data['spreadsheetUrl'] as String?) ??
        'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';

    if (spreadsheetId.isEmpty) return null;

    // 2. Poblar datos por cada pestaña usando batchUpdate de valores
    final valueData = <Map<String, dynamic>>[];
    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      final rowsData = <List<dynamic>>[];
      for (final row in sheet.rows) {
        final rowValues = <dynamic>[];
        for (final cell in row) {
          rowValues.add(_extractCellValue(cell?.value));
        }
        rowsData.add(rowValues);
      }

      if (rowsData.isNotEmpty) {
        valueData.add({
          'range': "'$sheetName'!A1",
          'values': rowsData,
        });
      }
    }

    if (valueData.isNotEmpty) {
      final updateUri = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchUpdate',
      );
      final updateRes = await http.post(
        updateUri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'valueInputOption': 'USER_ENTERED',
          'data': valueData,
        }),
      );

      if (updateRes.statusCode != 200 && updateRes.statusCode != 201) {
        debugPrint(
            'Sheets API batchUpdate warning: ${updateRes.statusCode} - ${updateRes.body}');
      }
    }

    return GoogleSheetExportResult(
      fileId: spreadsheetId,
      name: title,
      webViewLink: spreadsheetUrl,
    );
  }

  /// Estrategia multipart mediante Google Drive API v3
  Future<GoogleSheetExportResult> _exportViaGoogleDriveMultipart({
    required Excel excel,
    required String title,
    required String accessToken,
  }) async {
    final excelBytes = Uint8List.fromList(excel.save() ?? []);
    if (excelBytes.isEmpty) {
      throw Exception('No se pudieron generar los datos para Google Sheets');
    }

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

    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.body.contains('insufficientFilePermissions') ||
        response.body.contains('insufficientPermissions')) {
      debugPrint('Google Sheets upload permission error 403: ${response.body}');
      throw GoogleSheetsPermissionException(
        'Tu cuenta de Google requiere autorizar el permiso para crear hojas de cálculo en Google Drive.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint(
          'Google Sheets upload error: ${response.statusCode} - ${response.body}');
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

  dynamic _extractCellValue(CellValue? val) {
    if (val == null) return '';
    if (val is TextCellValue) return val.value.text ?? '';
    if (val is IntCellValue) return val.value;
    if (val is DoubleCellValue) return val.value;
    if (val is BoolCellValue) return val.value;
    if (val is DateCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    }
    if (val is DateTimeCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')} '
          '${val.hour.toString().padLeft(2, '0')}:${val.minute.toString().padLeft(2, '0')}';
    }
    if (val is TimeCellValue) {
      return '${val.hour.toString().padLeft(2, '0')}:${val.minute.toString().padLeft(2, '0')}:${val.second.toString().padLeft(2, '0')}';
    }
    if (val is FormulaCellValue) {
      return val.formula;
    }
    return val.toString();
  }
}

