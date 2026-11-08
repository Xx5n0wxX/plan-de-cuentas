import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/erika_loan_model.dart';
import '../models/modular_models.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/add_fiado_dialog.dart';
import '../widgets/add_transaction_dialog.dart';
import '../widgets/erika_payment_success_dialog.dart';
import '../widgets/export_options_dialog.dart';
import '../widgets/pay_fiado_dialog.dart';

class DashboardView extends StatelessWidget {
  final ValueChanged<String>? onNavigateToModule;

  const DashboardView({super.key, this.onNavigateToModule});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final monthName =
        DateFormat('MMMM yyyy', 'es_CL').format(provider.selectedMonth);
    final capitalizedMonth =
        monthName[0].toUpperCase() + monthName.substring(1);

    final isCompletelyEmpty = provider.transactions.isEmpty &&
        provider.fiadoEntries.isEmpty &&
        provider.erikaLoans.isEmpty &&
        provider.receivables.isEmpty &&
        provider.savingsGoals.isEmpty &&
        provider.subscriptions.isEmpty;

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 28 : 16,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BARRA DE SELECCIÓN DE MES + BOTÓN DE MÓDULOS
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          tooltip: 'Mes anterior',
                          onPressed: () {
                            final current = provider.selectedMonth;
                            provider.setSelectedMonth(
                                DateTime(current.year, current.month - 1));
                          },
                        ),
                        Icon(
                          Icons.calendar_month,
                          size: 20,
                          color: isDark
                              ? AppTheme.primaryTealDark
                              : AppTheme.primaryTeal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          capitalizedMonth,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          tooltip: 'Mes siguiente',
                          onPressed: () {
                            final current = provider.selectedMonth;
                            provider.setSelectedMonth(
                                DateTime(current.year, current.month + 1));
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          icon: Icon(
                            provider.isPrivacyMode
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: provider.isPrivacyMode
                                ? Colors.amber.shade700
                                : null,
                          ),
                          tooltip: provider.isPrivacyMode
                              ? 'Mostrar montos'
                              : 'Ocultar montos (Modo Privacidad)',
                          onPressed: () => provider.togglePrivacyMode(),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.table_chart,
                              color: Color(0xFF0F9D58)),
                          tooltip: 'Exportar (Google Sheets / Excel)',
                          onPressed: () => ExportOptionsSheet.show(context),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          onNavigateToModule?.call('modules_hub'),
                      icon: const Icon(Icons.widgets_outlined, size: 18),
                      label: Text(
                          'Módulos (${provider.activeModules.length + 1}/10)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // BANNER DE BIENVENIDA DESDE CERO (SIN DATOS PERSONALES)
            if (isCompletelyEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF134E4A).withValues(alpha: 0.35)
                      : const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppTheme.primaryTeal),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '¡Tu Plan de Cuentas está en 0 y listo para personalizar!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Activa o desactiva cualquiera de los 10 módulos según lo que necesites controlar (Préstamos, Libretas Abiertas, Gastos Compartidos, Me Deben, Ahorro, Suscripciones, Presupuesto Diario, Tarjetas o Lista de Compras).',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const AddTransactionDialog(
                                initialType: TransactionType.income,
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Registrar Primer Ingreso'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              onNavigateToModule?.call('modules_hub'),
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('Elegir mis Módulos Activos'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ALERTA DE DÉFICIT FINANCIERO
            if (provider.isDeficit)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppTheme.expenseBgDark : AppTheme.expenseBgLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isDark ? AppTheme.expenseDark : AppTheme.expenseLight,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color:
                          isDark ? AppTheme.expenseDark : AppTheme.expenseLight,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Tus compromisos y gastos superan los ingresos disponibles por ${CurrencyFormatter.format(provider.monthlyNetBalance.abs())}.',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFFECDD3)
                              : const Color(0xFF881337),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // TARJETAS DE BALANCE PRINCIPALES (MÓDULO 1 BASE)
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = isDesktop
                    ? (constraints.maxWidth - 32) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        context: context,
                        title: 'Ingresos del Mes',
                        amount: provider.monthlyIncome,
                        icon: Icons.arrow_upward,
                        iconColor:
                            isDark ? AppTheme.incomeDark : AppTheme.incomeLight,
                        bgColor: isDark
                            ? AppTheme.incomeBgDark.withValues(alpha: 0.3)
                            : AppTheme.incomeBgLight,
                        borderColor: isDark
                            ? AppTheme.incomeDark.withValues(alpha: 0.3)
                            : AppTheme.incomeLight.withValues(alpha: 0.2),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        context: context,
                        title: 'Gastos y Pagos del Mes',
                        amount: provider.monthlyExpenses,
                        icon: Icons.arrow_downward,
                        iconColor: isDark
                            ? AppTheme.expenseDark
                            : AppTheme.expenseLight,
                        bgColor: isDark
                            ? AppTheme.expenseBgDark.withValues(alpha: 0.3)
                            : AppTheme.expenseBgLight,
                        borderColor: isDark
                            ? AppTheme.expenseDark.withValues(alpha: 0.3)
                            : AppTheme.expenseLight.withValues(alpha: 0.2),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        context: context,
                        title: provider.reservedSavingsThisMonth > 0
                            ? 'Liquidez Libre (descontando ahorro)'
                            : 'Liquidez Disponible',
                        amount: provider.monthlyNetBalance,
                        icon: provider.isDeficit
                            ? Icons.trending_down
                            : Icons.account_balance_wallet,
                        iconColor: provider.isDeficit
                            ? (isDark
                                ? AppTheme.expenseDark
                                : AppTheme.expenseLight)
                            : (isDark
                                ? AppTheme.primaryTealDark
                                : AppTheme.primaryTeal),
                        bgColor: provider.isDeficit
                            ? (isDark
                                ? AppTheme.expenseBgDark.withValues(alpha: 0.4)
                                : AppTheme.expenseBgLight)
                            : (isDark
                                ? const Color(0xFF134E4A).withValues(alpha: 0.3)
                                : const Color(0xFFF0FDFA)),
                        borderColor: provider.isDeficit
                            ? (isDark
                                ? AppTheme.expenseDark
                                : AppTheme.expenseLight)
                            : (isDark
                                ? AppTheme.primaryTealDark
                                    .withValues(alpha: 0.4)
                                : AppTheme.primaryTeal.withValues(alpha: 0.3)),
                        isHighlight: true,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // SECCIÓN DINÁMICA: TARJETA MÓDULO LIBRETAS ABIERTAS (SI ESTÁ ACTIVO)
            if (provider.isModuleActive(AppModuleId.openAccounts)) ...[
              Card(
                elevation: 0,
                color: isDark ? AppTheme.fiadoBgDark : AppTheme.fiadoBgLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? AppTheme.fiadoDark.withValues(alpha: 0.4)
                        : AppTheme.fiadoLight.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront,
                                  color: isDark
                                      ? AppTheme.fiadoDark
                                      : AppTheme.fiadoLight,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Libretas / Cuentas Abiertas (${provider.selectedOpenAccount})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => onNavigateToModule
                                ?.call(AppModuleId.openAccounts),
                            child: const Text('Ver libretas'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saldo Pendiente Total:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                    provider.totalPendingFiado),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFFBBF24)
                                      : AppTheme.fiadoLight,
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const AddFiadoDialog(),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('+ Anotar a Cuenta'),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppTheme.fiadoDark
                                      : AppTheme.fiadoLight,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const PayFiadoDialog(),
                                  );
                                },
                                icon: const Icon(Icons.payment, size: 18),
                                label: const Text('Abonar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // SECCIÓN DINÁMICA: PRÉSTAMOS Y DEUDAS EN CUOTAS (SI ESTÁ ACTIVO)
            if (provider.isModuleActive(AppModuleId.loans) &&
                provider.activeErikaLoans.isNotEmpty) ...[
              ...provider.activeErikaLoans.map((loan) {
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isDark ? AppTheme.erikaBgDark : AppTheme.erikaBgLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? AppTheme.erikaDark.withValues(alpha: 0.4)
                          : AppTheme.erikaLight.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${loan.creditor} • ${loan.label}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              'Cuota ${loan.paidInstallments}/${loan.totalInstallments}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: loan.progressPercentage,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Cuota: ${CurrencyFormatter.format(loan.installmentValue)} • Restante: ${CurrencyFormatter.format(loan.remainingDebt)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (loan.paidInstallments > 0)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final receipt =
                                          CurrencyFormatter.formatLoanReceipt(
                                        creditor: loan.creditor,
                                        label: loan.label,
                                        loanNumber: loan.loanNumber,
                                        currentCuota: loan.paidInstallments,
                                        totalCuotas: loan.totalInstallments,
                                        amount: loan.installmentValue,
                                        customTemplate: loan.receiptTemplate,
                                      );
                                      await Clipboard.setData(
                                          ClipboardData(text: receipt));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  '✓ Copiado: "$receipt"')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('WhatsApp'),
                                  ),
                                FilledButton(
                                  onPressed: () => _confirmPayLoanInstallment(
                                      context, provider, loan),
                                  child: const Text('Pagar Cuota'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            // RESUMEN COMPACTO DE TODOS LOS MÓDULOS ACTIVOS (BENTO GRID)
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Tus Módulos Activos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onNavigateToModule?.call('modules_hub'),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Activar / Quitar Módulos'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppModuleMeta.catalog
                  .where((m) => provider.isModuleActive(m.id))
                  .map((meta) {
                return SizedBox(
                  width: isDesktop ? 260 : double.infinity,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                          color: meta.accentColor.withValues(alpha: 0.3)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onNavigateToModule?.call(meta.id),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  meta.accentColor.withValues(alpha: 0.15),
                              child: Icon(meta.selectedIcon,
                                  color: meta.accentColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meta.shortLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    _moduleStatusMetric(provider, meta.id),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // GRÁFICO DE DISTRIBUCIÓN DE GASTOS
            if (provider.monthlyExpenses > 0) ...[
              Text(
                'Distribución de Gastos del Mes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 200,
                    child: _buildExpenseChart(provider, isDark, theme),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor:
            isDark ? AppTheme.primaryTealDark : AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddTransactionDialog(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Movimiento'),
      ),
    );
  }

  String _moduleStatusMetric(FinanceProvider provider, String moduleId) {
    switch (moduleId) {
      case AppModuleId.monthlyFlow:
        return '${provider.currentMonthTransactions.length} movs este mes';
      case AppModuleId.loans:
        return '${provider.activeErikaLoans.length} préstamos activos';
      case AppModuleId.openAccounts:
        return 'Saldo: ${CurrencyFormatter.format(provider.totalPendingFiado)}';
      case AppModuleId.sharedExpenses:
        return 'Mes: ${CurrencyFormatter.format(provider.totalSharedExpensesMonth)}';
      case AppModuleId.receivables:
        return 'Por cobrar: ${CurrencyFormatter.format(provider.totalPendingReceivables)}';
      case AppModuleId.savingsGoals:
        return 'Ahorrado: ${CurrencyFormatter.format(provider.totalSavedInGoals)}';
      case AppModuleId.subscriptions:
        return '${CurrencyFormatter.format(provider.totalMonthlySubscriptions)}/mes';
      case AppModuleId.dailyBudget:
        return '${provider.budgetCategories.length} categorías activas';
      case AppModuleId.creditCards:
        return 'Próxima fact.: ${CurrencyFormatter.format(provider.totalNextCreditCardBilling)}';
      case AppModuleId.shoppingList:
        return 'Carrito: ${CurrencyFormatter.format(provider.shoppingCartEstimatedTotal)}';
      default:
        return 'Activo';
    }
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required double amount,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: iconColor, size: 22),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyFormatter.format(amount),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? iconColor : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseChart(
      FinanceProvider provider, bool isDark, ThemeData theme) {
    final Map<String, double> categorySums = {};
    for (final tx in provider.currentMonthTransactions) {
      if (tx.type == TransactionType.expense) {
        categorySums[tx.category] =
            (categorySums[tx.category] ?? 0) + tx.amount;
      }
    }

    final colors = isDark
        ? [
            const Color(0xFFA78BFA),
            const Color(0xFFFBBF24),
            const Color(0xFF818CF8),
            const Color(0xFF2DD4BF),
            const Color(0xFFFB923C),
            const Color(0xFFF87171),
            const Color(0xFF60A5FA),
          ]
        : [
            AppTheme.erikaLight,
            AppTheme.fiadoLight,
            AppTheme.debtLight,
            AppTheme.primaryTeal,
            Colors.orange.shade700,
            AppTheme.expenseLight,
            Colors.blue.shade700,
          ];

    int colorIndex = 0;
    final sections = categorySums.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      final percent = (entry.value / provider.monthlyExpenses) * 100;
      return PieChartSectionData(
        value: entry.value,
        title: '${percent.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: color,
        radius: 50,
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 2,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: ListView(
            shrinkWrap: true,
            children: categorySums.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(entry.value),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _confirmPayLoanInstallment(
      BuildContext context, FinanceProvider provider, ErikaLoan loan) {
    final nextCuota = loan.paidInstallments + 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar Pago • ${loan.creditor} (${loan.label})'),
        content: Text(
          '¿Confirmas el pago de la cuota $nextCuota de ${loan.totalInstallments} por ${CurrencyFormatter.format(loan.installmentValue)}?',
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
            child: const Text('Confirmar y Generar Recibo'),
          ),
        ],
      ),
    );
  }
}
