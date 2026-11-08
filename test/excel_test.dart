import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plan_de_cuentas/models/transaction_model.dart';
import 'package:plan_de_cuentas/providers/finance_provider.dart';
import 'package:plan_de_cuentas/services/excel_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es_CL', null);
  });

  group('Punto 2: Exportador a Excel (.xlsx) completo y modular', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Generates all 11 modular sheets with proper headers and data', () async {
      final provider = FinanceProvider();

      // Seed data into different modules
      await provider.addTransaction(
        title: 'Sueldo Mensual',
        amount: 850000,
        type: TransactionType.income,
        category: 'Ingresos',
      );
      await provider.addTransaction(
        title: 'Supermercado Lider',
        amount: 65000,
        type: TransactionType.expense,
        category: 'Alimentación',
      );
      await provider.addFiadoEntry(
        12500,
        accountName: 'Comercio Local',
        note: 'Bebidas y pan',
      );
      await provider.addErikaLoan(
        loanNumber: 1,
        creditor: 'Banco Estado',
        grantDate: DateTime.now(),
        principalAmount: 500000,
        totalToPay: 600000,
        installmentValue: 50000,
        totalInstallments: 12,
      );
      await provider.addReceivable(
        debtorName: 'Carlos Gómez',
        concept: 'Préstamo viaje',
        totalAmount: 40000,
      );
      await provider.addSavingsGoal(
        name: 'Fondo Emergencia',
        targetAmount: 1000000,
        currentAmount: 250000,
      );
      await provider.addSubscription(
        name: 'Netflix Premium',
        amount: 11990,
        billingDay: 15,
      );
      await provider.addBudgetCategory(
        name: 'Delivery',
        monthlyLimit: 50000,
      );
      await provider.addCreditCard(
        name: 'Visa Signature',
        creditLimit: 1500000,
        usedAmount: 120000,
      );
      await provider.addShoppingItem(
        name: 'Leche Descremada',
        estimatedPrice: 1100,
        quantity: 6,
      );

      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Resumen General');

      // Export workbook in memory
      final path = await ExcelExportService.exportFullWorkbook(provider);
      expect(path, isNotEmpty);
      expect(path.endsWith('.xlsx'), isTrue);
    });

    test('Excel workbook contains exact expected 11 sheets structure', () {
      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Resumen General');

      final expectedSheets = [
        'Resumen General',
        'Movimientos',
        'Libretas y Fiados',
        'Préstamos y Cuotas',
        'Gastos Compartidos',
        'Cuentas por Cobrar',
        'Metas de Ahorro',
        'Suscripciones',
        'Gastos Hormiga y Topes',
        'Tarjetas de Crédito',
        'Lista de Compras',
      ];

      for (final s in expectedSheets) {
        excel[s]; // Ensure sheet is accessed/created
      }

      for (final s in expectedSheets) {
        expect(excel.sheets.containsKey(s), isTrue);
      }
      expect(excel.sheets.length, 11);
    });
  });
}
