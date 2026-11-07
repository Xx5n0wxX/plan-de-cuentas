import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/erika_loan_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/erika_payment_success_dialog.dart';
import '../widgets/whatsapp_template_editor.dart';

class ErikaView extends StatelessWidget {
  const ErikaView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Préstamos y Deudas en Cuotas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Préstamo / Crédito',
            onPressed: () => _showAddLoanDialog(context, provider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.erikaBgDark : AppTheme.erikaBgLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppTheme.erikaDark.withValues(alpha: 0.4)
                      : AppTheme.erikaLight.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    color: isDark ? AppTheme.erikaDark : AppTheme.erikaLight,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Controla créditos bancarios, compras en cuotas o préstamos personales y genera comprobantes listos para enviar por WhatsApp.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFDDD6FE)
                            : const Color(0xFF5B21B6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Préstamos y Créditos Activos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (provider.activeErikaLoans.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.handshake_outlined,
                        size: 46,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No tienes préstamos o deudas en cuotas registradas.',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showAddLoanDialog(context, provider),
                        icon: const Icon(Icons.add),
                        label: const Text('Registrar Primer Préstamo'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...provider.activeErikaLoans.map((loan) {
                return _buildActiveLoanCard(
                    context, provider, loan, isDark, theme);
              }),
            const SizedBox(height: 28),
            if (provider.completedErikaLoans.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Historial de Préstamos Finalizados',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${provider.completedErikaLoans.length} pagados',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? AppTheme.incomeDark : AppTheme.incomeLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...provider.completedErikaLoans.map((loan) {
                final dateStr = DateFormat('dd/MM/yyyy').format(loan.grantDate);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isDark
                              ? AppTheme.incomeDark.withValues(alpha: 0.25)
                              : const Color(0xFFD1FAE5),
                          child: Icon(
                            Icons.check,
                            color: isDark ? AppTheme.incomeDark : AppTheme.incomeLight,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${loan.creditor} (${loan.label}) • $dateStr',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Capital: ${CurrencyFormatter.format(loan.principalAmount)} • Pagado: ${CurrencyFormatter.format(loan.totalToPay)} (${loan.totalInstallments}/${loan.totalInstallments} cuotas)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Editar',
                              onPressed: () => _showEditLoanDialog(context, provider, loan),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Eliminar',
                              onPressed: () => provider.deleteErikaLoan(loan.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppTheme.erikaDark : AppTheme.erikaLight,
        foregroundColor: Colors.white,
        onPressed: () => _showAddLoanDialog(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Préstamo / Cuota'),
      ),
    );
  }

  Widget _buildActiveLoanCard(
    BuildContext context,
    FinanceProvider provider,
    ErikaLoan loan,
    bool isDark,
    ThemeData theme,
  ) {
    final grantDateStr = DateFormat('dd/MM/yyyy').format(loan.grantDate);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.erikaBgDark : AppTheme.erikaBgLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark
              ? AppTheme.erikaDark.withValues(alpha: 0.4)
              : AppTheme.erikaLight.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: isDark
                      ? AppTheme.erikaDark.withValues(alpha: 0.25)
                      : const Color(0xFFEDE9FE),
                  child: Text(
                    '#${loan.loanNumber}',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFDDD6FE)
                          : const Color(0xFF5B21B6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loan.creditor} • ${loan.label}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Registrado el $grantDateStr',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3B0764)
                        : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Cuota ${loan.paidInstallments}/${loan.totalInstallments}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFDDD6FE)
                          : const Color(0xFF5B21B6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showEditLoanDialog(context, provider, loan),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Eliminar préstamo?'),
                        content: Text(
                          'Se eliminará el registro de "${loan.creditor} (${loan.label})".',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      provider.deleteErikaLoan(loan.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  _buildLoanMetric('Capital',
                      CurrencyFormatter.format(loan.principalAmount), theme),
                  _buildLoanMetric('Valor Cuota',
                      CurrencyFormatter.format(loan.installmentValue), theme,
                      isBold: true),
                  _buildLoanMetric('Total a Pagar',
                      CurrencyFormatter.format(loan.totalToPay), theme),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso: ${(loan.progressPercentage * 100).toInt()}% pagado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Saldo pendiente: ${CurrencyFormatter.format(loan.remainingDebt)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFDDD6FE)
                        : AppTheme.erikaLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: loan.progressPercentage,
                minHeight: 10,
                backgroundColor:
                    isDark ? const Color(0xFF3B0764) : const Color(0xFFDDD6FE),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppTheme.erikaDark : AppTheme.erikaLight,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loan.paidInstallments > 0) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(
                          color: Color(0xFF25D366), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final receipt = CurrencyFormatter.formatLoanReceipt(
                        creditor: loan.creditor,
                        label: loan.label,
                        loanNumber: loan.loanNumber,
                        currentCuota: loan.paidInstallments,
                        totalCuotas: loan.totalInstallments,
                        amount: loan.installmentValue,
                        customTemplate: loan.receiptTemplate,
                      );
                      await Clipboard.setData(ClipboardData(text: receipt));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('✓ Copiado para WhatsApp: "$receipt"'),
                            backgroundColor: const Color(0xFF059669),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(
                      'Copiar comprobante cuota ${loan.paidInstallments}/${loan.totalInstallments} (WhatsApp)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isDark ? AppTheme.erikaDark : AppTheme.erikaLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () {
                    final nextCuota = loan.paidInstallments + 1;
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title:
                            Text('Pagar Cuota • ${loan.creditor} (${loan.label})'),
                        content: Text(
                          'Se registrará el pago de la cuota $nextCuota de ${loan.totalInstallments} por ${CurrencyFormatter.format(loan.installmentValue)}.\n\nAl confirmar podrás copiar el comprobante listo para WhatsApp.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await provider.payErikaInstallment(loan.id);
                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                                showDialog(
                                  context: context,
                                  builder: (_) => ErikaPaymentSuccessDialog(
                                    loan: loan,
                                    paidInstallmentNumber: nextCuota,
                                  ),
                                );
                              }
                            },
                            child: const Text('Confirmar Pago'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    'Pagar Cuota ${loan.paidInstallments + 1} (${CurrencyFormatter.format(loan.installmentValue)})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanMetric(String label, String value, ThemeData theme,
      {bool isBold = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditLoanDialog(
      BuildContext context, FinanceProvider provider, ErikaLoan loan) {
    final creditorCtrl = TextEditingController(text: loan.creditor);
    final labelCtrl = TextEditingController(text: loan.label);
    final principalCtrl = TextEditingController(
        text: loan.principalAmount % 1 == 0
            ? loan.principalAmount.toInt().toString()
            : loan.principalAmount.toString());
    final totalCtrl = TextEditingController(
        text: loan.totalToPay % 1 == 0
            ? loan.totalToPay.toInt().toString()
            : loan.totalToPay.toString());
    final installmentsCountCtrl =
        TextEditingController(text: loan.totalInstallments.toString());
    final paidInstallmentsCtrl =
        TextEditingController(text: loan.paidInstallments.toString());
    final installmentCtrl = TextEditingController(
        text: loan.installmentValue % 1 == 0
            ? loan.installmentValue.toInt().toString()
            : loan.installmentValue.toString());
    final templateCtrl = TextEditingController(text: loan.receiptTemplate);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          actionsOverflowButtonSpacing: 8,
          actionsOverflowDirection: VerticalDirection.down,
          title: Text('Editar Préstamo • ${loan.creditor}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: creditorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Acreedor / Entidad / Persona',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta / N° Identificador',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: paidInstallmentsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cuotas Pagadas',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: installmentsCountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Cuotas',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: principalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capital Recibido',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total a Pagar (con interés)',
                    prefixText: '\$ ',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: installmentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor Cuota Mensual',
                    prefixText: '\$ ',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                WhatsAppTemplateEditor(
                  controller: templateCtrl,
                  creditor: creditorCtrl.text,
                  label: labelCtrl.text,
                  loanNumber: loan.loanNumber,
                  currentCuota: (int.tryParse(paidInstallmentsCtrl.text) ?? loan.paidInstallments) + 1,
                  totalCuotas: int.tryParse(installmentsCountCtrl.text) ?? loan.totalInstallments,
                  amount: double.tryParse(installmentCtrl.text) ?? loan.installmentValue,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
            onPressed: () {
              final creditor = creditorCtrl.text.trim().isEmpty
                  ? loan.creditor
                  : creditorCtrl.text.trim();
              final label = labelCtrl.text.trim().isEmpty
                  ? loan.label
                  : labelCtrl.text.trim();
              final paid = int.tryParse(paidInstallmentsCtrl.text) ??
                  loan.paidInstallments;
              final count = int.tryParse(installmentsCountCtrl.text) ??
                  loan.totalInstallments;
              final installment =
                  double.tryParse(installmentCtrl.text) ?? loan.installmentValue;
              final total =
                  double.tryParse(totalCtrl.text) ?? loan.totalToPay;
              final principal =
                  double.tryParse(principalCtrl.text) ?? loan.principalAmount;

              final updated = loan.copyWith(
                creditor: creditor,
                label: label,
                paidInstallments: paid.clamp(0, count),
                totalInstallments: count,
                installmentValue: installment,
                totalToPay: total,
                principalAmount: principal,
                receiptTemplate: templateCtrl.text.trim().isEmpty
                    ? loan.receiptTemplate
                    : templateCtrl.text.trim(),
              );

              provider.updateErikaLoan(updated);
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    ),
  );
}

  void _showAddLoanDialog(BuildContext context, FinanceProvider provider) {
    final nextNum = provider.erikaLoans.length + 1;
    final creditorCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'No $nextNum');
    final loanNumberCtrl = TextEditingController(text: nextNum.toString());
    final principalCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final installmentsCountCtrl = TextEditingController(text: '5');
    final installmentCtrl = TextEditingController();
    final templateCtrl = TextEditingController(
      text: 'PRESTAMO {ACREEDOR} [{ETIQUETA}] CUOTA {CUOTA}/{TOTAL} {MONTO}.-',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          actionsOverflowButtonSpacing: 8,
          actionsOverflowDirection: VerticalDirection.down,
          title: const Text('Nuevo Préstamo o Deuda en Cuotas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: creditorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Acreedor / Entidad / Persona',
                    hintText: 'Ej: Banco, Tarjeta, Familiar, Prestamista...',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: labelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Etiqueta / N°',
                          hintText: 'Ej: No 1, Auto',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: installmentsCountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total de Cuotas',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: principalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capital Recibido / Monto Original',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total a Pagar (con interés)',
                    prefixText: '\$ ',
                  ),
                  onChanged: (val) {
                    final total = double.tryParse(val);
                    final count = int.tryParse(installmentsCountCtrl.text) ?? 5;
                    if (total != null && count > 0) {
                      installmentCtrl.text = (total / count).round().toString();
                    }
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: installmentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor Cuota Mensual',
                    prefixText: '\$ ',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                WhatsAppTemplateEditor(
                  controller: templateCtrl,
                  creditor: creditorCtrl.text,
                  label: labelCtrl.text,
                  loanNumber: int.tryParse(loanNumberCtrl.text) ?? nextNum,
                  currentCuota: 1,
                  totalCuotas: int.tryParse(installmentsCountCtrl.text) ?? 5,
                  amount: double.tryParse(installmentCtrl.text) ?? 0,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final creditor = creditorCtrl.text.trim().isEmpty
                    ? 'Acreedor'
                    : creditorCtrl.text.trim();
                final numLoan = int.tryParse(loanNumberCtrl.text) ?? nextNum;
                final count = int.tryParse(installmentsCountCtrl.text) ?? 5;
                final installment = double.tryParse(installmentCtrl.text) ?? 0;
                final total =
                    double.tryParse(totalCtrl.text) ?? (installment * count);
                final principal = double.tryParse(principalCtrl.text) ?? total;

                if (installment <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ingresa un valor de cuota válido')),
                  );
                  return;
                }

                provider.addErikaLoan(
                  loanNumber: numLoan,
                  creditor: creditor,
                  label: labelCtrl.text.trim(),
                  receiptTemplate: templateCtrl.text.trim(),
                  grantDate: DateTime.now(),
                  principalAmount: principal,
                  totalToPay: total,
                  installmentValue: installment,
                  totalInstallments: count,
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Crear Préstamo'),
            ),
          ],
        ),
      ),
    );
  }
}
