import 'package:excel/excel.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../models/modular_models.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import 'excel_exporter.dart';

class ExcelExportService {
  static final CellStyle _headerStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0F766E'), // Teal oscuro
  );

  static final CellStyle _sectionHeaderStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#334155'), // Slate gris oscuro
  );

  static final CellStyle _metricLabelStyle = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
  );

  /// Genera y comparte el archivo Excel completo ordenado por pestañas/módulos
  static Future<String> exportFullWorkbook(FinanceProvider provider) async {
    try {
      await initializeDateFormatting('es_CL', null);
    } catch (_) {}

    final excel = Excel.createExcel();

    // Renombrar la primera hoja a 'Resumen General'
    excel.rename('Sheet1', 'Resumen General');

    _buildSummarySheet(excel['Resumen General'], provider);
    _buildTransactionsSheet(excel['Movimientos'], provider);
    _buildFiadoSheet(excel['Libretas y Fiados'], provider);
    _buildLoansSheet(excel['Préstamos y Cuotas'], provider);
    _buildSharedSheet(excel['Gastos Compartidos'], provider);
    _buildReceivablesSheet(excel['Cuentas por Cobrar'], provider);
    _buildSavingsSheet(excel['Metas de Ahorro'], provider);
    _buildSubscriptionsSheet(excel['Suscripciones'], provider);
    _buildDailyBudgetSheet(excel['Gastos Hormiga y Topes'], provider);
    _buildCreditCardsSheet(excel['Tarjetas de Crédito'], provider);
    _buildShoppingListSheet(excel['Lista de Compras'], provider);

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('No se pudieron generar los datos del libro Excel');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = 'Plan_de_Cuentas_$timestamp.xlsx';

    return await ExcelExporter.saveAndShare(
      bytes: bytes,
      filename: filename,
    );
  }

  // --- 1. RESUMEN GENERAL ---
  static void _buildSummarySheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 42.0);
    sheet.setColumnWidth(1, 26.0);

    int row = 0;

    void addRow(String label, CellValue val, {CellStyle? style}) {
      final cellA = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      final cellB = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      cellA.value = TextCellValue(label);
      cellB.value = val;
      if (style != null) {
        cellA.cellStyle = style;
        cellB.cellStyle = style;
      }
      row++;
    }

    // Cabecera Principal
    final headerA = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    final headerB = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    headerA.value = TextCellValue('PLAN DE CUENTAS - RESUMEN GENERAL');
    headerB.value = TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()));
    headerA.cellStyle = _headerStyle;
    headerB.cellStyle = _headerStyle;
    row += 2;

    final monthName = DateFormat('MMMM yyyy', 'es_CL').format(provider.selectedMonth);
    addRow('Mes de Referencia', TextCellValue(monthName[0].toUpperCase() + monthName.substring(1)), style: _metricLabelStyle);
    addRow('Ingresos del Mes (CLP)', DoubleCellValue(provider.monthlyIncome));
    addRow('Gastos del Mes (CLP)', DoubleCellValue(provider.monthlyExpenses));
    addRow('Balance Neto del Mes (CLP)', DoubleCellValue(provider.monthlyNetBalance));
    row++;

    final erikaPending = provider.activeErikaLoans.fold(0.0, (s, l) => s + l.remainingDebt);
    final cardUsed = provider.creditCards.fold(0.0, (s, c) => s + c.usedAmount);

    addRow('MÉTRICAS CONSOLIDADAS DE MÓDULOS', TextCellValue(''), style: _sectionHeaderStyle);
    addRow('Total Préstamos Pendientes (CLP)', DoubleCellValue(erikaPending));
    addRow('Total Deuda en Libretas / Fiados (CLP)', DoubleCellValue(provider.totalPendingFiado));
    addRow('Total Cuentas por Cobrar / Me Deben (CLP)', DoubleCellValue(provider.totalPendingReceivables));
    addRow('Total Ahorros Acumulados (CLP)', DoubleCellValue(provider.totalSavedInGoals));
    addRow('Gasto Mensual en Suscripciones (CLP)', DoubleCellValue(provider.totalMonthlySubscriptions));
    addRow('Facturación Tarjetas Próximo Mes (CLP)', DoubleCellValue(provider.totalNextCreditCardBilling));
    addRow('Cupo Utilizado en Tarjetas (CLP)', DoubleCellValue(cardUsed));
    row++;

    addRow('MÓDULOS ACTIVOS EN TU PERFIL', TextCellValue('${provider.activeModules.length + 1} de 10'), style: _sectionHeaderStyle);
    for (final meta in AppModuleMeta.catalog) {
      final active = provider.isModuleActive(meta.id);
      addRow(meta.title, TextCellValue(active ? '✓ Activo' : 'Desactivado'));
    }
  }

  // --- 2. MOVIMIENTOS ---
  static void _buildTransactionsSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 14.0);
    sheet.setColumnWidth(1, 14.0);
    sheet.setColumnWidth(2, 24.0);
    sheet.setColumnWidth(3, 35.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 30.0);

    final headers = ['Fecha', 'Tipo', 'Categoría', 'Glosa / Título', 'Monto (CLP)', 'Nota'];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;
    final sortedTx = List<TransactionModel>.from(provider.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final tx in sortedTx) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(DateFormat('dd/MM/yyyy').format(tx.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(tx.type == TransactionType.income ? 'Ingreso' : 'Gasto');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(tx.category);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(tx.title);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(tx.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue(tx.note ?? '');
      row++;
    }
  }

  // --- 3. LIBRETAS Y FIADOS ---
  static void _buildFiadoSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 22.0);
    sheet.setColumnWidth(1, 14.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 32.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 16.0);

    final headers = ['Libreta / Comercio', 'Fecha', 'Tipo', 'Detalle / Glosa', 'Monto (CLP)', 'Estado'];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;

    for (final entry in provider.fiadoEntries) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(entry.accountName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(DateFormat('dd/MM/yyyy').format(entry.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue('Cargo (Anotado)');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(entry.note);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(entry.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue(entry.isSettled ? 'Saldado' : 'Pendiente');
      row++;
    }

    for (final payment in provider.fiadoPayments) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(payment.accountName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(DateFormat('dd/MM/yyyy').format(payment.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue('Abono / Pago');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(payment.note.isNotEmpty ? payment.note : 'Abono realizado');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(payment.amountPaid);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue('Abonado');
      row++;
    }
  }

  // --- 4. PRÉSTAMOS Y DEUDAS EN CUOTAS ---
  static void _buildLoansSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 14.0);
    sheet.setColumnWidth(1, 26.0);
    sheet.setColumnWidth(2, 14.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 18.0);
    sheet.setColumnWidth(6, 14.0);
    sheet.setColumnWidth(7, 14.0);
    sheet.setColumnWidth(8, 14.0);
    sheet.setColumnWidth(9, 18.0);
    sheet.setColumnWidth(10, 18.0);
    sheet.setColumnWidth(11, 14.0);
    sheet.setColumnWidth(12, 16.0);

    final headers = [
      'N° / Etiqueta',
      'Acreedor / Entidad',
      'Fecha Otorgado',
      'Capital (CLP)',
      'Total a Pagar (CLP)',
      'Valor Cuota (CLP)',
      'Cuotas Totales',
      'Cuotas Pagadas',
      'Cuotas Restantes',
      'Total Pagado (CLP)',
      'Deuda Restante (CLP)',
      'Estado',
      'Próximo Vencimiento',
    ];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;
    for (final loan in provider.erikaLoans) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(loan.label);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(loan.creditor);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(DateFormat('dd/MM/yyyy').format(loan.grantDate));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          DoubleCellValue(loan.principalAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(loan.totalToPay);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          DoubleCellValue(loan.installmentValue);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          IntCellValue(loan.totalInstallments);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value =
          IntCellValue(loan.paidInstallments);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value =
          IntCellValue(loan.remainingInstallments);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value =
          DoubleCellValue(loan.totalPaid);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value =
          DoubleCellValue(loan.remainingDebt);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value =
          TextCellValue(loan.isCompleted ? 'Completado' : 'Activo');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value =
          TextCellValue(loan.nextDueDate != null
              ? DateFormat('dd/MM/yyyy').format(loan.nextDueDate!)
              : 'N/A');
      row++;
    }
  }

  // --- 5. GASTOS COMPARTIDOS ---
  static void _buildSharedSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 14.0);
    sheet.setColumnWidth(1, 30.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 22.0);
    sheet.setColumnWidth(5, 22.0);

    final cfg = provider.sharedConfig;
    final headers = [
      'Fecha',
      'Concepto',
      'Categoría',
      'Total (CLP)',
      'Mi Parte (${cfg.myPercentage.toInt()}%) (CLP)',
      'Parte ${cfg.partnerName} (${cfg.partnerPercentage.toInt()}%) (CLP)',
    ];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;
    final sharedTx = provider.transactions.where((t) =>
        t.isShared ||
        t.category.toLowerCase().contains('compartid') ||
        (t.note?.toLowerCase().contains('compartid') ?? false));

    for (final tx in sharedTx) {
      final myPart = tx.amount * (cfg.myPercentage / 100);
      final partnerPart = tx.amount * (cfg.partnerPercentage / 100);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(DateFormat('dd/MM/yyyy').format(tx.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(tx.title);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(tx.category);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          DoubleCellValue(tx.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(myPart);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          DoubleCellValue(partnerPart);
      row++;
    }
  }

  // --- 6. ME DEBEN / CUENTAS POR COBRAR ---
  static void _buildReceivablesSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 24.0);
    sheet.setColumnWidth(1, 30.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 16.0);
    sheet.setColumnWidth(6, 16.0);

    final headers = [
      'Deudor / Contacto',
      'Concepto / Motivo',
      'Monto Total (CLP)',
      'Monto Cobrado (CLP)',
      'Saldo Pendiente (CLP)',
      'Fecha Límite',
      'Estado',
    ];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;
    for (final r in provider.receivables) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(r.debtorName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(r.concept);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          DoubleCellValue(r.totalAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          DoubleCellValue(r.paidAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(r.remainingAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue(r.dueDate != null
              ? DateFormat('dd/MM/yyyy').format(r.dueDate!)
              : 'Sin fecha límite');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          TextCellValue(r.isSettled ? 'Cobrado Total' : 'Pendiente');
      row++;
    }
  }

  // --- 7. METAS DE AHORRO Y SOBRES ---
  static void _buildSavingsSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 30.0);
    sheet.setColumnWidth(1, 18.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 14.0);
    sheet.setColumnWidth(4, 22.0);
    sheet.setColumnWidth(5, 18.0);

    final headers = [
      'Meta de Ahorro / Sobre',
      'Monto Objetivo (CLP)',
      'Ahorrado Actual (CLP)',
      'Progreso (%)',
      'Aporte Mensual Sugerido (CLP)',
      'Reserva Liquidez',
    ];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;
    for (final g in provider.savingsGoals) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(g.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          DoubleCellValue(g.targetAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          DoubleCellValue(g.currentAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue('${(g.progress * 100).toInt()}%');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(g.monthlyContribution);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue(g.reserveFromLiquidity ? 'Sí' : 'No');
      row++;
    }
  }

  // --- 8. SUSCRIPCIONES Y COBROS AUTOMÁTICOS ---
  static void _buildSubscriptionsSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 26.0);
    sheet.setColumnWidth(1, 18.0);
    sheet.setColumnWidth(2, 14.0);
    sheet.setColumnWidth(3, 24.0);
    sheet.setColumnWidth(4, 20.0);
    sheet.setColumnWidth(5, 14.0);
    sheet.setColumnWidth(6, 16.0);

    final headers = [
      'Suscripción / Servicio',
      'Monto Mensual (CLP)',
      'Día de Cobro',
      'Categoría',
      'Costo Anualizado (CLP)',
      'Estado',
      'Pagado este Mes',
    ];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;
    for (final s in provider.subscriptions) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(s.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          DoubleCellValue(s.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          IntCellValue(s.billingDay);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(s.category);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(s.annualCost);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue(s.isActive ? 'Activa' : 'Pausada');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          TextCellValue(s.paidThisMonth ? 'Sí' : 'No');
      row++;
    }
  }

  // --- 9. GASTOS HORMIGA Y PRESUPUESTOS ---
  static void _buildDailyBudgetSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 24.0);
    sheet.setColumnWidth(1, 18.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 18.0);

    // Tabla 1: Topes de Categoría
    final headersCat = ['Categoría', 'Tope Mensual (CLP)', 'Gastado este Mes (CLP)', 'Saldo Restante (CLP)', 'Semáforo'];
    _writeHeaderRow(sheet, 0, headersCat);

    int row = 1;
    for (final cat in provider.budgetCategories) {
      final spent = provider.spentInCategory(cat.id);
      final remaining = (cat.monthlyLimit - spent).clamp(0.0, double.infinity);
      final ratio = cat.monthlyLimit > 0 ? (spent / cat.monthlyLimit) : 0.0;
      final status = ratio >= 1.0 ? 'Excedido' : (ratio >= 0.8 ? 'Alerta (>80%)' : 'Normal');

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(cat.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          DoubleCellValue(cat.monthlyLimit);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          DoubleCellValue(spent);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          DoubleCellValue(remaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          TextCellValue(status);
      row++;
    }

    row += 2;
    // Tabla 2: Detalle de Gastos Diarios / Hormiga
    final headerSubA = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    final headerSubB = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    headerSubA.value = TextCellValue('DETALLE DE GASTOS HORMIGA REGISTRADOS');
    headerSubB.value = TextCellValue('');
    headerSubA.cellStyle = _sectionHeaderStyle;
    headerSubB.cellStyle = _sectionHeaderStyle;
    row++;

    final headersAnt = ['Fecha', 'Categoría', 'Glosa / Detalle', 'Monto (CLP)', ''];
    _writeHeaderRow(sheet, row, headersAnt);
    row++;

    for (final ant in provider.antExpenses) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(DateFormat('dd/MM/yyyy').format(ant.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(ant.categoryName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(ant.title);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          DoubleCellValue(ant.amount);
      row++;
    }
  }

  // --- 10. TARJETAS DE CRÉDITO ---
  static void _buildCreditCardsSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 26.0);
    sheet.setColumnWidth(1, 18.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 24.0);
    sheet.setColumnWidth(5, 14.0);
    sheet.setColumnWidth(6, 14.0);

    final headers = [
      'Tarjeta / Banco',
      'Cupo Total (CLP)',
      'Cupo Utilizado (CLP)',
      'Cupo Disponible (CLP)',
      'Facturación Próximo Mes (CLP)',
      'Día de Cierre',
      'Día de Pago',
    ];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;
    for (final card in provider.creditCards) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(card.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          DoubleCellValue(card.creditLimit);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          DoubleCellValue(card.usedAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          DoubleCellValue(card.availableCredit);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(card.nextBillingAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          IntCellValue(card.closingDay);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          IntCellValue(card.dueDay);
      row++;
    }
  }

  // --- 11. LISTA DE COMPRAS / SUPERMERCADO ---
  static void _buildShoppingListSheet(Sheet sheet, FinanceProvider provider) {
    sheet.setColumnWidth(0, 30.0);
    sheet.setColumnWidth(1, 12.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 22.0);
    sheet.setColumnWidth(4, 14.0);

    final headers = [
      'Artículo / Producto',
      'Cantidad',
      'Precio Estimado Unitario (CLP)',
      'Total Estimado (CLP)',
      'Comprado',
    ];
    _writeHeaderRow(sheet, 0, headers);

    int row = 1;
    for (final item in provider.shoppingItems) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(item.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          IntCellValue(item.quantity);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          DoubleCellValue(item.estimatedPrice);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          DoubleCellValue(item.subtotal);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          TextCellValue(item.isChecked ? 'Sí' : 'No');
      row++;
    }
  }

  static void _writeHeaderRow(Sheet sheet, int rowIndex, List<String> headers) {
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }
  }
}
