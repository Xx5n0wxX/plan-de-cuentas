import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/erika_loan_model.dart';
import '../models/modular_models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_fiado_dialog.dart';
import '../widgets/erika_payment_success_dialog.dart';
import '../widgets/export_options_dialog.dart';
import '../widgets/pay_fiado_dialog.dart';

/// Hub Unificado de Compromisos, Deudas y Cuentas por Cobrar (Plan de Cuentas 3.0)
class DebtsHubView extends StatefulWidget {
  final ValueChanged<String>? onOpenModule;

  const DebtsHubView({super.key, this.onOpenModule});

  @override
  State<DebtsHubView> createState() => _DebtsHubViewState();
}

class _DebtsHubViewState extends State<DebtsHubView> {
  // 0: Por Pagar (Mis Deudas), 1: Por Cobrar (Me Deben)
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compromisos y Deudas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar (Sheets / Excel)',
            onPressed: () => ExportOptionsSheet.show(context),
          ),
          IconButton(
            icon: Icon(
              provider.isPrivacyMode ? Icons.visibility_off : Icons.visibility,
              color: provider.isPrivacyMode ? Colors.amber.shade700 : null,
            ),
            tooltip: provider.isPrivacyMode
                ? 'Mostrar montos'
                : 'Ocultar montos (Modo Privacidad)',
            onPressed: () => provider.togglePrivacyMode(),
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
            // SELECTOR SUPERIOR SEGMENTADO: POR PAGAR vs POR COBRAR
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.outbond_outlined),
                    label: Text('Por Pagar (Mis Deudas)'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.inbox_outlined),
                    label: Text('Por Cobrar (Me Deben)'),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (set) {
                  setState(() => _selectedTab = set.first);
                },
              ),
            ),
            const SizedBox(height: 20),

            if (_selectedTab == 0)
              _buildPayableDebtsContent(context, provider, theme, isDark)
            else
              _buildReceivablesContent(context, provider, theme, isDark),
          ],
        ),
      ),
    );
  }

  // --- CONTENIDO: POR PAGAR (MIS DEUDAS) ---
  Widget _buildPayableDebtsContent(
    BuildContext context,
    FinanceProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    // Cálculo de deuda consolidada (solo módulos activos)
    final loansActive = provider.isModuleActive(AppModuleId.loans);
    final openAccountsActive = provider.isModuleActive(AppModuleId.openAccounts);
    final creditCardsActive = provider.isModuleActive(AppModuleId.creditCards);
    if (!loansActive && !openAccountsActive && !creditCardsActive) {
      return _buildAllInactiveState(context, theme, 'Compromisos y Deudas');
    }

    final activeLoans =
        provider.erikaLoans.where((l) => !l.isCompleted).toList();
    final loansDebt = loansActive
        ? activeLoans.fold(0.0, (acc, loan) => acc + loan.remainingDebt)
        : 0.0;
    final fiadoDebt = openAccountsActive
        ? provider.openAccountNames.fold(
            0.0, (acc, name) => acc + provider.pendingForOpenAccount(name))
        : 0.0;
    final creditCardsDebt = creditCardsActive
        ? provider.creditCards
            .fold(0.0, (acc, card) => acc + card.usedAmount)
        : 0.0;
    final totalOwed = loansDebt + fiadoDebt + creditCardsDebt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TARJETA HERO: DEUDA TOTAL CONSOLIDADA
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF1E293B),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      const Color(0xFF0F766E),
                      const Color(0xFF115E59),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF0F766E))
                    .withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_outlined,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Deuda Total Consolidada',
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
                      color: totalOwed == 0
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      totalOwed == 0 ? 'Al día 🎉' : 'Compromisos Activos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                provider.maskedCurrency(totalOwed),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              // Desglose rápido en chips
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (loansActive)
                    _buildHeroChip(
                      'Préstamos: ${provider.maskedCurrency(loansDebt)}',
                      Icons.account_balance,
                    ),
                  if (openAccountsActive)
                    _buildHeroChip(
                      'Libretas: ${provider.maskedCurrency(fiadoDebt)}',
                      Icons.storefront,
                    ),
                  if (creditCardsActive)
                    _buildHeroChip(
                      'Tarjetas: ${provider.maskedCurrency(creditCardsDebt)}',
                      Icons.credit_card,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // SECCIÓN 1: PRÉSTAMOS BANCARIOS Y CRÉDITOS (solo si el módulo está activo)
        if (loansActive) ...[
          _buildSectionHeader(
            title: 'Préstamos y Créditos Bancarios',
            icon: Icons.account_balance,
            color: Colors.indigo,
            count: activeLoans.length,
            onManage: () => widget.onOpenModule?.call(AppModuleId.loans),
          ),
          const SizedBox(height: 10),
          if (activeLoans.isEmpty)
            _buildEmptyCard('No tienes préstamos pendientes de pago. ¡Excelente!')
          else
            ...activeLoans.map((loan) => _buildLoanCard(context, provider, loan, theme)),
          const SizedBox(height: 24),
        ],

        // SECCIÓN 2: LIBRETAS DE BARRIO / FIADOS (solo si el módulo está activo)
        if (openAccountsActive) ...[
          _buildSectionHeader(
            title: 'Libretas y Fiados de Barrio',
            icon: Icons.storefront,
            color: Colors.amber.shade800,
            count: provider.openAccountNames.length,
            onManage: () => widget.onOpenModule?.call(AppModuleId.openAccounts),
          ),
          const SizedBox(height: 10),
          _buildFiadoSummaryCard(context, provider, theme),
          const SizedBox(height: 24),
        ],

        // SECCIÓN 3: TARJETAS DE CRÉDITO (solo si el módulo está activo)
        if (creditCardsActive) ...[
          _buildSectionHeader(
            title: 'Tarjetas de Crédito',
            icon: Icons.credit_card,
            color: Colors.deepPurple,
            count: provider.creditCards.length,
            onManage: () => widget.onOpenModule?.call(AppModuleId.creditCards),
          ),
          const SizedBox(height: 10),
          if (provider.creditCards.isEmpty)
            _buildEmptyCard('No tienes tarjetas de crédito registradas.')
          else
            ...provider.creditCards.map(
                (card) => _buildCreditCardItem(context, provider, card, theme)),
        ],
      ],
    );
  }

  // --- CONTENIDO: POR COBRAR (ME DEBEN) ---
  Widget _buildReceivablesContent(
    BuildContext context,
    FinanceProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    final receivablesActive = provider.isModuleActive(AppModuleId.receivables);
    if (!receivablesActive) {
      return _buildAllInactiveState(context, theme, 'Cuentas por Cobrar');
    }

    final pendingReceivables =
        provider.receivables.where((r) => !r.isSettled).toList();
    final totalToCollect = pendingReceivables.fold(
        0.0, (acc, item) => acc + item.remainingAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HERO CARD: TOTAL POR COBRAR
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF064E3B),
                      const Color(0xFF022C22),
                    ]
                  : [
                      const Color(0xFF047857),
                      const Color(0xFF065F46),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF047857))
                    .withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.savings_outlined,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Total por Cobrar',
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingReceivables.length} persona(s)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                provider.maskedCurrency(totalToCollect),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dinero prestado a terceros o cobros pendientes',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildSectionHeader(
          title: 'Detalle de Cuentas por Cobrar',
          icon: Icons.people_outline,
          color: AppTheme.primaryTeal,
          count: pendingReceivables.length,
          onManage: () => widget.onOpenModule?.call(AppModuleId.receivables),
        ),
        const SizedBox(height: 10),

        if (pendingReceivables.isEmpty)
          _buildEmptyCard(
              'No tienes cuentas pendientes por cobrar. ¡Todo saldado!')
        else
          ...pendingReceivables.map(
              (rec) => _buildReceivableItemCard(context, provider, rec, theme)),
      ],
    );
  }

  // --- SUBWIDGETS REUTILIZABLES ---

  Widget _buildHeroChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onManage,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onManage,
          child: const Text('Gestionar', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildLoanCard(
    BuildContext context,
    FinanceProvider provider,
    ErikaLoan loan,
    ThemeData theme,
  ) {
    final progress = loan.progressPercentage;
    final nextCuota = loan.paidInstallments + 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.creditor,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        loan.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Cuota ${loan.paidInstallments}/${loan.totalInstallments}',
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valor cuota mensual',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      provider.maskedCurrency(loan.installmentValue),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Deuda restante',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      provider.maskedCurrency(loan.remainingDebt),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (loan.nextDueDate != null)
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Vence: ${DateFormat('dd/MM/yyyy').format(loan.nextDueDate!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    await provider.payErikaInstallment(loan.id);
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => ErikaPaymentSuccessDialog(
                          loan: loan,
                          paidInstallmentNumber: nextCuota,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text('Pagar Cuota $nextCuota'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiadoSummaryCard(
    BuildContext context,
    FinanceProvider provider,
    ThemeData theme,
  ) {
    final accounts = provider.openAccountNames;
    final totalPending = accounts.fold(
        0.0, (acc, name) => acc + provider.pendingForOpenAccount(name));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo Total Pendiente en Libretas',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.maskedCurrency(totalPending),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: totalPending > 0
                            ? Colors.red.shade700
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${accounts.length} Almacén(es)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Chips de negocios con sus saldos
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: accounts.map((acc) {
                final balance = provider.pendingForOpenAccount(acc);
                return Chip(
                  avatar: const Icon(Icons.storefront, size: 16),
                  label: Text(
                    '$acc: ${provider.maskedCurrency(balance)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          balance > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const PayFiadoDialog(),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Abonar / Saldar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddFiadoDialog(),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Anotar Compra'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCardItem(
    BuildContext context,
    FinanceProvider provider,
    CreditCardModel card,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.credit_card,
                          color: Colors.deepPurple, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      card.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Corte: día ${card.closingDay} • Vence: día ${card.dueDay}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: card.usageRatio,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  card.usageRatio > 0.8 ? Colors.red : Colors.deepPurple,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cupo Utilizado',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      provider.maskedCurrency(card.usedAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Cupo Disponible',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      provider.maskedCurrency(card.availableCredit),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivableItemCard(
    BuildContext context,
    FinanceProvider provider,
    ReceivableModel rec,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.debtorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      rec.concept,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Resta: ${provider.maskedCurrency(rec.remainingAmount)}',
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rec.progress,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Original: ${provider.maskedCurrency(rec.totalAmount)} (Abonado: ${provider.maskedCurrency(rec.paidAmount)})',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      widget.onOpenModule?.call(AppModuleId.receivables),
                  icon: const Icon(Icons.attach_money, size: 16),
                  label: const Text('Registrar Abono'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Estado vacío para cuando la categoría completa está desactivada:
  /// muestra un mensaje y un botón que lleva al Catálogo de Módulos.
  Widget _buildAllInactiveState(
    BuildContext context,
    ThemeData theme,
    String categoryName,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 48, bottom: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin módulos activos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Activa los módulos de $categoryName desde el Catálogo de Módulos para verlos aquí.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => widget.onOpenModule?.call('modules_hub'),
              icon: const Icon(Icons.widgets_outlined, size: 18),
              label: const Text('Abrir Catálogo de Módulos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0,
      color: Colors.grey.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
