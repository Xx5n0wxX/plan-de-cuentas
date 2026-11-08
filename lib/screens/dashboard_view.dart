import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/export_options_dialog.dart';

/// Panel Ejecutivo / Dashboard Principal (Plan de Cuentas 3.0)
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

    // Calcular datos de vencimientos próximos (próximos 7 días)
    final upcomingItems = _getUpcomingMaturities(provider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. BARRA SUPERIOR: SELECTOR DE MES Y ACCIONES
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
                  runSpacing: 4,
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
                            fontSize: 16,
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
                        IconButton(
                          icon: const Icon(Icons.table_chart,
                              color: Color(0xFF0F9D58)),
                          tooltip: 'Exportar (Google Sheets / Excel)',
                          onPressed: () => ExportOptionsSheet.show(context),
                        ),
                        IconButton(
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. HERO CARD EJECUTIVO: SALDO DISPONIBLE Y FLUJO NETO
            _buildExecutiveHeroCard(context, provider, theme, isDark),
            const SizedBox(height: 24),

            // 3. PRÓXIMOS VENCIMIENTOS (CARRUSEL HORIZONTAL 7 DÍAS)
            _buildUpcomingSection(context, provider, upcomingItems, theme, isDark),
            const SizedBox(height: 24),

            // 4. DISTRIBUCIÓN DEL MES: GRÁFICO DONUT DE GASTOS
            if (provider.monthlyExpenses > 0) ...[
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pie_chart_outline,
                                  color: AppTheme.primaryTeal, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Distribución de Gastos del Mes',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            provider.maskedCurrency(provider.monthlyExpenses),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPieChart(context, provider, theme, isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 5. ACCESOS RÁPIDOS A LOS HUBS CONSOLIDADOS
            const Text(
              'Gestión Financiera Centralizada',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                      child: _buildHubNavigationCard(
                        title: 'Compromisos y Deudas',
                        subtitle:
                            'Préstamos bancarios, libretas de fiado, tarjetas y cuentas por cobrar.',
                        icon: Icons.account_balance_outlined,
                        color: Colors.indigo,
                        badge: '${provider.erikaLoans.where((l) => !l.isCompleted).length} Préstamo(s)',
                        onTap: () => onNavigateToModule?.call('debts_hub'),
                      ),
                    ),
                    SizedBox(
                      width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                      child: _buildHubNavigationCard(
                        title: 'Metas, Planes y Pareja',
                        subtitle:
                            'Metas de ahorro, división de gastos del hogar y calendario de suscripciones.',
                        icon: Icons.savings_outlined,
                        color: Colors.purple,
                        badge: '${provider.savingsGoals.length} Meta(s)',
                        onTap: () => onNavigateToModule?.call('plans_hub'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HERO: PANEL EJECUTIVO ---
  Widget _buildExecutiveHeroCard(
    BuildContext context,
    FinanceProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    final net = provider.monthlyNetBalance;
    final income = provider.monthlyIncome;
    final expense = provider.monthlyExpenses;
    final isDeficit = provider.isDeficit;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F2B2B),
                  const Color(0xFF0A1F1F),
                ]
              : [
                  const Color(0xFF0F766E),
                  const Color(0xFF134E4A),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF0F766E))
                .withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wallet,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Saldo Disponible Real',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDeficit
                      ? Colors.redAccent.withValues(alpha: 0.3)
                      : const Color(0xFF10B981).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDeficit ? Icons.warning_amber : Icons.check_circle,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDeficit ? 'Déficit del Mes' : 'Superávit Saludable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            provider.maskedCurrency(net),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDeficit
                ? 'Tus gastos superan tus ingresos por ${provider.maskedCurrency(expense - income)}'
                : 'Cuentas con liquidez a favor en este período',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),

          // BARRA BICOLOR COMPARATIVA (INGRESOS vs GASTOS)
          if (income > 0 || expense > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: income > 0 ? (income * 100).toInt() : 1,
                      child: Container(color: Colors.tealAccent.shade400),
                    ),
                    Expanded(
                      flex: expense > 0 ? (expense * 100).toInt() : 1,
                      child: Container(color: Colors.redAccent.shade100),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // FILA INFORMATIVA INGRESO vs GASTO
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ingresos del Mes: ${provider.maskedCurrency(income)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.shade100,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Gastos del Mes: ${provider.maskedCurrency(expense)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SECCIÓN: PRÓXIMOS VENCIMIENTOS (7 DÍAS) ---
  Widget _buildUpcomingSection(
    BuildContext context,
    FinanceProvider provider,
    List<_UpcomingItem> items,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_available,
                    color: AppTheme.primaryTeal, size: 20),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: const Text(
                    'Próximos Vencimientos (7 días)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length} pendiente(s)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Card(
            elevation: 0,
            color: isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                : const Color(0xFFECFDF5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF047857).withValues(alpha: 0.3)
                    : const Color(0xFFA7F3D0),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF10B981), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sin pagos ni cuotas pendientes para los próximos 7 días. ¡Todo al día! 🎉',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildUpcomingCard(context, provider, item, theme, isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingCard(
    BuildContext context,
    FinanceProvider provider,
    _UpcomingItem item,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.daysLeft <= 1
                      ? Colors.red.shade100
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.daysLeft == 0
                      ? 'Hoy'
                      : item.daysLeft == 1
                          ? 'Mañana'
                          : 'En ${item.daysLeft} días',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: item.daysLeft <= 1
                        ? Colors.red.shade800
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                provider.maskedCurrency(item.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primaryTeal,
                ),
              ),
              InkWell(
                onTap: item.onAction,
                child: const Text(
                  'Ver',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TARJETAS DE ACCESO A HUBS ---
  Widget _buildHubNavigationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- GRÁFICO DONUT DE GASTOS ---
  Widget _buildPieChart(
    BuildContext context,
    FinanceProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    final Map<String, double> categorySums = {};
    final expenses = provider.currentMonthTransactions
        .where((t) => t.type == TransactionType.expense);
    for (var tx in expenses) {
      categorySums[tx.category] =
          (categorySums[tx.category] ?? 0) + tx.amount;
    }

    if (categorySums.isEmpty) return const SizedBox.shrink();

    final colors = [
      AppTheme.primaryTeal,
      Colors.indigo,
      Colors.pink,
      Colors.amber.shade700,
      Colors.deepPurple,
      Colors.teal,
      Colors.orange,
      Colors.blue,
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: color,
        radius: 44,
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 32,
                sectionsSpace: 2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categorySums.entries.take(5).map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      provider.maskedCurrency(entry.value),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

  // --- DETECCIÓN DE VENCIMIENTOS PRÓXIMOS EN 7 DÍAS ---
  List<_UpcomingItem> _getUpcomingMaturities(FinanceProvider provider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));
    final List<_UpcomingItem> items = [];

    // 1. Préstamos bancarios
    for (final loan in provider.erikaLoans) {
      if (!loan.isCompleted && loan.nextDueDate != null) {
        final due = DateTime(
          loan.nextDueDate!.year,
          loan.nextDueDate!.month,
          loan.nextDueDate!.day,
        );
        if (due.isBefore(nextWeek.add(const Duration(days: 1)))) {
          final diff = due.difference(today).inDays;
          items.add(_UpcomingItem(
            title: loan.creditor,
            subtitle: 'Cuota ${loan.paidInstallments + 1}/${loan.totalInstallments}',
            amount: loan.installmentValue,
            dueDate: due,
            daysLeft: diff.clamp(0, 999),
            icon: Icons.account_balance,
            color: Colors.indigo,
            onAction: () => onNavigateToModule?.call('debts_hub'),
          ));
        }
      }
    }

    // 2. Suscripciones
    for (final sub in provider.subscriptions) {
      if (sub.isActive) {
        // Calcular fecha de corte este mes
        DateTime subDue = DateTime(today.year, today.month, sub.billingDay.clamp(1, 28));
        if (subDue.isBefore(today)) {
          subDue = DateTime(today.year, today.month + 1, sub.billingDay.clamp(1, 28));
        }
        if (subDue.isBefore(nextWeek.add(const Duration(days: 1)))) {
          final diff = subDue.difference(today).inDays;
          items.add(_UpcomingItem(
            title: sub.name,
            subtitle: 'Suscripción recurrente',
            amount: sub.amount,
            dueDate: subDue,
            daysLeft: diff.clamp(0, 999),
            icon: Icons.autorenew,
            color: Colors.teal,
            onAction: () => onNavigateToModule?.call('plans_hub'),
          ));
        }
      }
    }

    // 3. Tarjetas de crédito (fecha de vencimiento de pago)
    for (final card in provider.creditCards) {
      if (card.usedAmount > 0) {
        DateTime cardDue = DateTime(today.year, today.month, card.dueDay.clamp(1, 28));
        if (cardDue.isBefore(today)) {
          cardDue = DateTime(today.year, today.month + 1, card.dueDay.clamp(1, 28));
        }
        if (cardDue.isBefore(nextWeek.add(const Duration(days: 1)))) {
          final diff = cardDue.difference(today).inDays;
          items.add(_UpcomingItem(
            title: card.name,
            subtitle: 'Pago mensual tarjeta',
            amount: card.usedAmount,
            dueDate: cardDue,
            daysLeft: diff.clamp(0, 999),
            icon: Icons.credit_card,
            color: Colors.deepPurple,
            onAction: () => onNavigateToModule?.call('debts_hub'),
          ));
        }
      }
    }

    // Ordenar por días restantes más cercanos
    items.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return items;
  }
}

class _UpcomingItem {
  final String title;
  final String subtitle;
  final double amount;
  final DateTime dueDate;
  final int daysLeft;
  final IconData icon;
  final Color color;
  final VoidCallback onAction;

  _UpcomingItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.dueDate,
    required this.daysLeft,
    required this.icon,
    required this.color,
    required this.onAction,
  });
}
