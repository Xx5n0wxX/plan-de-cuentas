import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _clpFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );

  static String format(double amount) {
    return _clpFormat.format(amount);
  }

  static String formatInt(int amount) {
    return _clpFormat.format(amount);
  }

  /// Genera un comprobante de cuota a partir de la plantilla del préstamo o acreedor.
  /// Soporta variables: {ACREEDOR}, {ETIQUETA}, {CUOTA}, {TOTAL}, {MONTO}
  static String formatLoanReceipt({
    required String creditor,
    required String label,
    required int loanNumber,
    required int currentCuota,
    required int totalCuotas,
    required double amount,
    String? customTemplate,
  }) {
    final formattedAmount = _clpFormat.format(amount).replaceAll(' ', '');
    final cleanCreditor = creditor.trim().toUpperCase();

    // Si tiene plantilla personalizada o usa formato clásico PRESTAMO [ACREEDOR] [No X]
    if (customTemplate != null && customTemplate.trim().isNotEmpty) {
      return customTemplate
          .replaceAll('{ACREEDOR}', cleanCreditor)
          .replaceAll('{ETIQUETA}', label)
          .replaceAll('{NUMERO}', loanNumber.toString())
          .replaceAll('{CUOTA}', currentCuota.toString())
          .replaceAll('{TOTAL}', totalCuotas.toString())
          .replaceAll('\${MONTO}', formattedAmount)
          .replaceAll('{MONTO}', formattedAmount);
    }

    return 'PRESTAMO $cleanCreditor [No $loanNumber] CUOTA $currentCuota/$totalCuotas $formattedAmount.-';
  }

  /// Compatibilidad directa
  static String formatErikaReceipt({
    required int loanNumber,
    required int currentCuota,
    required int totalCuotas,
    required double amount,
    String creditor = 'ACREEDOR',
    String? label,
    String? customTemplate,
  }) {
    return formatLoanReceipt(
      creditor: creditor,
      label: label ?? 'No $loanNumber',
      loanNumber: loanNumber,
      currentCuota: currentCuota,
      totalCuotas: totalCuotas,
      amount: amount,
      customTemplate: customTemplate,
    );
  }
}
