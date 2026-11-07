import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class PayFiadoDialog extends StatefulWidget {
  const PayFiadoDialog({super.key});

  @override
  State<PayFiadoDialog> createState() => _PayFiadoDialogState();
}

class _PayFiadoDialogState extends State<PayFiadoDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  double _pendingBalance = 0;

  @override
  void initState() {
    super.initState();
    final provider = context.read<FinanceProvider>();
    _pendingBalance = provider.pendingForOpenAccount(provider.selectedOpenAccount);
    if (_pendingBalance > 0) {
      _amountController.text = _pendingBalance.toInt().toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enteredAmount = double.tryParse(_amountController.text) ?? 0;
    final remainingAfterPayment = (_pendingBalance - enteredAmount).clamp(0.0, double.infinity);
    final isFullPayment = enteredAmount >= _pendingBalance && _pendingBalance > 0;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.incomeDark.withValues(alpha: 0.25) : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.payments, color: isDark ? AppTheme.incomeDark : AppTheme.incomeLight, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Abonar a ${context.watch<FinanceProvider>().selectedOpenAccount}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumen de deuda actual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.fiadoBgDark : AppTheme.fiadoBgLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.fiadoDark.withValues(alpha: 0.4) : AppTheme.fiadoLight.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo pendiente en esta libreta:',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(_pendingBalance),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFFBBF24) : AppTheme.fiadoLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Cuánto vas a pagar hoy?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '\$ ',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppTheme.primaryTealDark : AppTheme.primaryTeal,
                      side: BorderSide(
                        color: isDark ? AppTheme.primaryTealDark : AppTheme.primaryTeal,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _amountController.text = _pendingBalance.toInt().toString();
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Pagar Totalidad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Indicador de saldo restante tras el pago
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFullPayment
                    ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFullPayment
                      ? (isDark ? AppTheme.incomeDark.withValues(alpha: 0.4) : AppTheme.incomeLight.withValues(alpha: 0.3))
                      : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isFullPayment ? Icons.verified : Icons.info_outline,
                    color: isFullPayment
                        ? (isDark ? AppTheme.incomeDark : AppTheme.incomeLight)
                        : (isDark ? AppTheme.primaryTealDark : AppTheme.primaryTeal),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFullPayment
                          ? '¡Cuenta completamente saldada!'
                          : 'Te quedará debiendo: ${CurrencyFormatter.format(remainingAfterPayment)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isFullPayment
                            ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857))
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Nota o detalle (opcional)',
                hintText: 'Ej: Pago quincena, abono efectivo...',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? AppTheme.incomeDark : AppTheme.incomeLight,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final amount = double.tryParse(_amountController.text);
            if (amount == null || amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingresa un monto de pago válido')),
              );
              return;
            }
            context.read<FinanceProvider>().payFiado(
                  amount,
                  note: _noteController.text.trim(),
                );
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFullPayment
                      ? '✓ Cuenta del negocio saldada por completo'
                      : '✓ Abono de ${CurrencyFormatter.format(amount)} registrado. Saldo restante: ${CurrencyFormatter.format(remainingAfterPayment)}',
                ),
                backgroundColor: isDark ? AppTheme.incomeDark : AppTheme.incomeLight,
                duration: const Duration(seconds: 3),
              ),
            );
          },
          icon: const Icon(Icons.done_all),
          label: const Text('Confirmar Pago'),
        ),
      ],
    );
  }
}
