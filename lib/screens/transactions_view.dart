import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/add_transaction_dialog.dart';

class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  String _filterType = 'all'; // all, income, expense
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final monthName = DateFormat('MMMM yyyy', 'es_CL').format(provider.selectedMonth);

    // Filtrar transacciones del mes
    var list = provider.currentMonthTransactions;

    if (_filterType == 'income') {
      list = list.where((t) => t.type == TransactionType.income).toList();
    } else if (_filterType == 'expense') {
      list = list.where((t) => t.type == TransactionType.expense).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((t) {
        final q = _searchQuery.toLowerCase();
        return t.title.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            (t.note?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Libro de Movimientos ($monthName)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo Movimiento',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const AddTransactionDialog(),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: 12,
        ),
        child: Column(
          children: [
            // BUSCADOR Y FILTROS
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por glosa o categoría...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Todos')),
                    ButtonSegment(value: 'income', label: Text('Ingresos')),
                    ButtonSegment(value: 'expense', label: Text('Gastos')),
                  ],
                  selected: {_filterType},
                  onSelectionChanged: (val) => setState(() => _filterType = val.first),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // TOTALES DEL LISTADO FILTRADO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${list.length} movimientos registrados',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  'Neto: ${CurrencyFormatter.format(provider.monthlyNetBalance)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: provider.isDeficit
                        ? (isDark ? AppTheme.expenseDark : AppTheme.expenseLight)
                        : (isDark ? AppTheme.incomeDark : AppTheme.incomeLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // LISTA DE MOVIMIENTOS
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 54, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          Text(
                            'No hay movimientos registrados para este filtro',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final tx = list[index];
                        final isIncome = tx.type == TransactionType.income;
                        final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AddTransactionDialog(transactionToEdit: tx),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: isIncome
                                            ? (isDark ? AppTheme.incomeDark.withValues(alpha: 0.25) : const Color(0xFFD1FAE5))
                                            : (isDark ? AppTheme.expenseDark.withValues(alpha: 0.25) : const Color(0xFFFFE4E6)),
                                        child: Icon(
                                          isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                                          color: isIncome
                                              ? (isDark ? AppTheme.incomeDark : AppTheme.incomeLight)
                                              : (isDark ? AppTheme.expenseDark : AppTheme.expenseLight),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          tx.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(tx.amount)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isIncome
                                              ? (isDark ? AppTheme.incomeDark : AppTheme.incomeLight)
                                              : (isDark ? AppTheme.expenseDark : AppTheme.expenseLight),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.calendar_today, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                            const SizedBox(width: 4),
                                            Text(dateStr, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.category_outlined, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                            const SizedBox(width: 4),
                                            Text(tx.category, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                      if (tx.isShared)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.people_outline, size: 12, color: Colors.purple),
                                              SizedBox(width: 4),
                                              Text('Compartido', style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (tx.note != null && tx.note!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.notes, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              tx.note!.trim(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.onSurfaceVariant,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        label: const Text('Editar', style: TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AddTransactionDialog(transactionToEdit: tx),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: theme.colorScheme.error,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('¿Eliminar movimiento?'),
                                              content: Text('Se eliminará "${tx.title}" por ${CurrencyFormatter.format(tx.amount)}.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(ctx).pop(false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                                  onPressed: () => Navigator.of(ctx).pop(true),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            provider.deleteTransaction(tx.id);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? AppTheme.primaryTealDark : AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddTransactionDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
