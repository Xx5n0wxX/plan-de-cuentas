import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/erika_loan_model.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class ErikaPaymentSuccessDialog extends StatefulWidget {
  final ErikaLoan loan;
  final int paidInstallmentNumber;

  const ErikaPaymentSuccessDialog({
    super.key,
    required this.loan,
    required this.paidInstallmentNumber,
  });

  @override
  State<ErikaPaymentSuccessDialog> createState() =>
      _ErikaPaymentSuccessDialogState();
}

class _ErikaPaymentSuccessDialogState extends State<ErikaPaymentSuccessDialog> {
  bool _isCopied = false;

  String get _receiptText => CurrencyFormatter.formatLoanReceipt(
        creditor: widget.loan.creditor,
        label: widget.loan.label,
        loanNumber: widget.loan.loanNumber,
        currentCuota: widget.paidInstallmentNumber,
        totalCuotas: widget.loan.totalInstallments,
        amount: widget.loan.installmentValue,
        customTemplate: widget.loan.receiptTemplate,
      );

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _receiptText));
    setState(() => _isCopied = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✓ Comprobante copiado al portapapeles. Listo para enviar por WhatsApp.'),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: isDark ? AppTheme.incomeDark : AppTheme.incomeLight,
                size: 52,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Cuota Pagada con Éxito!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Se registró el pago de la cuota ${widget.paidInstallmentNumber} de ${widget.loan.totalInstallments} (${widget.loan.creditor}).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 16, color: Color(0xFF25D366)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Comprobante para ${widget.loan.creditor} (WhatsApp):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _receiptText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _isCopied
                      ? const Color(0xFF059669)
                      : const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _copyToClipboard,
                icon: Icon(_isCopied ? Icons.done_all : Icons.copy),
                label: Text(
                  _isCopied
                      ? '¡Copiado al Portapapeles! ✓'
                      : 'Copiar para WhatsApp',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar / Listo'),
          ),
        ),
      ],
    );
  }
}
