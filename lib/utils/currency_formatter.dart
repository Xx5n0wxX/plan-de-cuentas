import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Formato numérico chileno (separador de miles con punto, sin decimales).
  /// El signo $ se antepone manualmente porque el locale es_CL lo ubica al final.
  static final NumberFormat _clpNumber = NumberFormat('#,##0', 'es_CL');

  static bool isPrivacyMode = false;
  static const String maskedCurrency = '\$ ••••••';

  /// Devuelve el monto con el signo $ antes de los números: $190.000 / -$190.000
  static String _formatClp(num amount) {
    final rounded = amount.round();
    final digits = _clpNumber.format(rounded.abs());
    return rounded < 0 ? '-\$$digits' : '\$$digits';
  }

  static String format(double amount, {bool allowPrivacy = true}) {
    if (allowPrivacy && isPrivacyMode) {
      return maskedCurrency;
    }
    return _formatClp(amount);
  }

  static String formatInt(int amount, {bool allowPrivacy = true}) {
    if (allowPrivacy && isPrivacyMode) {
      return maskedCurrency;
    }
    return _formatClp(amount);
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
    final formattedAmount = _formatClp(amount);
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
