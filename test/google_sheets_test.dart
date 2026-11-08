import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plan_de_cuentas/models/transaction_model.dart';
import 'package:plan_de_cuentas/providers/finance_provider.dart';
import 'package:plan_de_cuentas/services/excel_export_service.dart';
import 'package:plan_de_cuentas/services/google_sheets_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es_CL', null);
  });

  group('Google Sheets Export Service', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('GoogleSheetExportResult model holds valid properties', () {
      final res = GoogleSheetExportResult(
        fileId: 'sheet123',
        name: 'Plan de Cuentas - Test',
        webViewLink: 'https://docs.google.com/spreadsheets/d/sheet123/edit',
      );

      expect(res.fileId, 'sheet123');
      expect(res.name, 'Plan de Cuentas - Test');
      expect(res.webViewLink,
          'https://docs.google.com/spreadsheets/d/sheet123/edit');
    });

    test('Generates valid Excel binary data for Google Sheets conversion',
        () async {
      final provider = FinanceProvider();

      await provider.addTransaction(
        title: 'Ingreso Trabajo Remoto',
        amount: 1200000,
        type: TransactionType.income,
        category: 'Sueldo',
      );
      await provider.addTransaction(
        title: 'Arriendo',
        amount: 350000,
        type: TransactionType.expense,
        category: 'Vivienda',
      );

      final doc = ExcelExportService.buildExcelDocument(provider);
      final bytes = doc.save();

      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);

      // Verifies that sheets list contains the 11 modules
      expect(doc.sheets.containsKey('Resumen General'), isTrue);
      expect(doc.sheets.containsKey('Movimientos'), isTrue);
      expect(doc.sheets.containsKey('Libretas y Fiados'), isTrue);
      expect(doc.sheets.containsKey('Préstamos y Cuotas'), isTrue);
      expect(doc.sheets.containsKey('Gastos Compartidos'), isTrue);
      expect(doc.sheets.containsKey('Cuentas por Cobrar'), isTrue);
      expect(doc.sheets.containsKey('Metas de Ahorro'), isTrue);
      expect(doc.sheets.containsKey('Suscripciones'), isTrue);
      expect(doc.sheets.containsKey('Gastos Hormiga y Topes'), isTrue);
      expect(doc.sheets.containsKey('Tarjetas de Crédito'), isTrue);
      expect(doc.sheets.containsKey('Lista de Compras'), isTrue);
    });

    test('Multipart payload builds correct Drive API metadata for Google Sheets',
        () {
      const boundary = '===plan_de_cuentas_sheets_boundary===';
      final metadataJson = jsonEncode({
        'name': 'Plan de Cuentas - Prueba',
        'mimeType': 'application/vnd.google-apps.spreadsheet',
      });

      final header = '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$metadataJson\r\n'
          '--$boundary\r\n'
          'Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n';

      expect(header.contains('application/vnd.google-apps.spreadsheet'), isTrue);
      expect(header.contains('application/vnd.openxmlformats-officedocument'),
          isTrue);
      expect(header.contains('Plan de Cuentas - Prueba'), isTrue);
    });
  });
}
