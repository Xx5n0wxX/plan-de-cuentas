import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/modular_models.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/add_transaction_dialog.dart';
import '../widgets/export_options_dialog.dart';

/// Centro de Módulos (Permite activar/desactivar los 10 módulos o abrir cualquiera)
class ModulesHubView extends StatefulWidget {
  final ValueChanged<String>? onOpenModule;

  const ModulesHubView({super.key, this.onOpenModule});

  @override
  State<ModulesHubView> createState() => _ModulesHubViewState();
}

class _ModulesHubViewState extends State<ModulesHubView> {
  // 0: Todos, 1: Flujo Diario, 2: Deudas y Cobros, 3: Metas y Planes
  int _categoryFilter = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final activeCount = provider.activeModules.length + 1; // +1 por Flujo Mensual base
    final progress = (activeCount / 10).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Módulos (Arma tu Plan)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar Plan (Google Sheets / Excel)',
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
            // TARJETA SUPERIOR DE RESUMEN Y PERFILES RÁPIDOS
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.widgets,
                                  color: AppTheme.primaryTeal, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$activeCount de 10 módulos activos (${(progress * 100).toInt()}%)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            activeCount == 10 ? 'Plan Completo 🚀' : 'Personalizado',
                            style: const TextStyle(
                              color: AppTheme.primaryTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
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
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Perfiles de Configuración en 1 Clic:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.bolt, size: 15),
                          label: const Text('Básico'),
                          onPressed: () {
                            provider.applyModulePreset([
                              AppModuleId.dailyBudget,
                              AppModuleId.savingsGoals,
                              AppModuleId.subscriptions,
                            ]);
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.home_outlined, size: 15),
                          label: const Text('Hogar / Pareja'),
                          onPressed: () {
                            provider.applyModulePreset([
                              AppModuleId.sharedExpenses,
                              AppModuleId.shoppingList,
                              AppModuleId.subscriptions,
                              AppModuleId.creditCards,
                            ]);
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.storefront, size: 15),
                          label: const Text('Comercio / Deudas'),
                          onPressed: () {
                            provider.applyModulePreset([
                              AppModuleId.loans,
                              AppModuleId.openAccounts,
                              AppModuleId.receivables,
                            ]);
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.rocket_launch, size: 15),
                          label: const Text('Todo Activo'),
                          onPressed: () {
                            provider.applyModulePreset(AppModuleId.allOptional);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // FILTRO DE CATEGORÍAS EN PÍLDORAS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(0, 'Todos (10)', Icons.apps),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, 'Flujo Diario', Icons.trending_up),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, 'Deudas y Cobros', Icons.account_balance),
                  const SizedBox(width: 8),
                  _buildFilterChip(3, 'Planes y Futuro', Icons.savings),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // GRUPOS CATEGORIZADOS DE MÓDULOS
            if (_categoryFilter == 0 || _categoryFilter == 1) ...[
              _buildCategorySection(
                title: 'Flujo y Gestión Diaria',
                icon: Icons.payments_outlined,
                color: Colors.teal,
                modules: [
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.monthlyFlow),
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.dailyBudget),
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.shoppingList),
                ],
                provider: provider,
                theme: theme,
              ),
              const SizedBox(height: 20),
            ],

            if (_categoryFilter == 0 || _categoryFilter == 2) ...[
              _buildCategorySection(
                title: 'Deudas, Créditos y Cobros',
                icon: Icons.account_balance_outlined,
                color: Colors.indigo,
                modules: [
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.loans),
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.openAccounts),
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.creditCards),
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.receivables),
                ],
                provider: provider,
                theme: theme,
              ),
              const SizedBox(height: 20),
            ],

            if (_categoryFilter == 0 || _categoryFilter == 3) ...[
              _buildCategorySection(
                title: 'Planes, Metas y Futuro',
                icon: Icons.rocket_launch_outlined,
                color: Colors.purple,
                modules: [
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.savingsGoals),
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.sharedExpenses),
                  AppModuleMeta.catalog.firstWhere((m) => m.id == AppModuleId.subscriptions),
                ],
                provider: provider,
                theme: theme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _categoryFilter == index;
    return FilterChip(
      selected: isSelected,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : null),
      label: Text(label),
      onSelected: (_) => setState(() => _categoryFilter = index),
      selectedColor: AppTheme.primaryTeal,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<AppModuleMeta> modules,
    required FinanceProvider provider,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...modules.map((meta) {
          final active = provider.isModuleActive(meta.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: active
                    ? meta.accentColor.withValues(alpha: 0.45)
                    : theme.dividerColor.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: meta.accentColor.withValues(alpha: 0.15),
                child: Icon(meta.selectedIcon,
                    color: meta.accentColor, size: 22),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      meta.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (meta.isCore)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Base',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(meta.subtitle,
                    style: const TextStyle(fontSize: 12)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active && widget.onOpenModule != null)
                    TextButton(
                      onPressed: () => widget.onOpenModule!(meta.id),
                      child: const Text('Abrir'),
                    ),
                  if (!meta.isCore)
                    Switch(
                      value: active,
                      activeTrackColor: meta.accentColor,
                      onChanged: (val) =>
                          provider.toggleModule(meta.id, val),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Módulo 4: Gastos Compartidos (Pareja / Hogar / Roommates)
class SharedExpensesModuleView extends StatelessWidget {
  const SharedExpensesModuleView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final cfg = provider.sharedConfig;
    final sharedTxs = provider.sharedMonthTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Compartidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar Plan (Google Sheets / Excel)',
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
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configurar porcentajes',
            onPressed: () => _showSharedSettingsDialog(context, provider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              'Compartido con ${cfg.partnerName}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _showSharedSettingsDialog(context, provider),
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(
                              '${cfg.myPercentage.toInt()}% / ${cfg.partnerPercentage.toInt()}%'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricCol('Total Compartido',
                            CurrencyFormatter.format(provider.totalSharedExpensesMonth)),
                        _metricCol('Tu Parte (${cfg.myPercentage.toInt()}%)',
                            CurrencyFormatter.format(provider.mySharedShareMonth)),
                        _metricCol(
                            'Parte ${cfg.partnerName} (${cfg.partnerPercentage.toInt()}%)',
                            CurrencyFormatter.format(provider.partnerSharedShareMonth)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (provider.totalSharedExpensesMonth > 0)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final text =
                              'RESUMEN GASTOS COMPARTIDOS: Total ${CurrencyFormatter.format(provider.totalSharedExpensesMonth)} • Parte de ${cfg.partnerName} (${cfg.partnerPercentage.toInt()}%): ${CurrencyFormatter.format(provider.partnerSharedShareMonth)}.-';
                          await Clipboard.setData(ClipboardData(text: text));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      '✓ Resumen copiado para WhatsApp: "$text"')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copiar liquidación para WhatsApp'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Gastos Compartidos del Mes',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (sharedTxs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                        'No hay gastos compartidos registrados este mes.'),
                  ),
                ),
              )
            else
              ...sharedTxs.map((tx) {
                final partnerPart = tx.amount * (cfg.partnerPercentage / 100.0);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(Icons.people, color: Color(0xFF2563EB)),
                    ),
                    title: Text(tx.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Total: ${CurrencyFormatter.format(tx.amount)} • Parte ${cfg.partnerName}: ${CurrencyFormatter.format(partnerPart)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar gasto compartido',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar Gasto Compartido'),
                            content: Text('¿Deseas eliminar "${tx.title}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.redAccent),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final deleted = tx;
                          final deletedIdx = provider.transactions.indexOf(tx);
                          provider.deleteTransaction(tx.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gasto "${deleted.title}" eliminado'),
                                duration: const Duration(seconds: 4),
                                action: SnackBarAction(
                                  label: 'Deshacer',
                                  onPressed: () => provider.restoreTransaction(
                                      deleted,
                                      index: deletedIdx),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddTransactionDialog(
              initialType: TransactionType.expense,
              initialShared: true,
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Gasto Compartido'),
      ),
    );
  }

  Widget _metricCol(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(val,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showSharedSettingsDialog(
      BuildContext context, FinanceProvider provider) {
    final nameCtrl =
        TextEditingController(text: provider.sharedConfig.partnerName);
    double myPct = provider.sharedConfig.myPercentage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Configurar Gastos Compartidos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de pareja / roommate / grupo',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tu aporte: ${myPct.toInt()}% • ${nameCtrl.text}: ${(100 - myPct).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: myPct,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setStateDialog(() => myPct = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                provider.updateSharedConfig(
                  provider.sharedConfig.copyWith(
                    isEnabled: true,
                    partnerName: nameCtrl.text.trim().isEmpty
                        ? 'Compañero/a'
                        : nameCtrl.text.trim(),
                    myPercentage: myPct,
                    partnerPercentage: 100 - myPct,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Módulo 5: Me Deben / Cuentas por Cobrar
class ReceivablesModuleView extends StatelessWidget {
  const ReceivablesModuleView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me Deben / Cuentas por Cobrar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar Plan (Google Sheets / Excel)',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFFECFDF5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL PENDIENTE POR COBRAR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.format(provider.totalPendingReceivables),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (provider.receivables.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                        'No tienes cuentas por cobrar registradas en este momento.'),
                  ),
                ),
              )
            else
              ...provider.receivables.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.debtorName} • ${item.concept}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Editar',
                                  onPressed: () => _showEditReceivableDialog(
                                      context, provider, item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('¿Eliminar cobro?'),
                                        content: Text(
                                            'Se eliminará la cuenta por cobrar de ${item.debtorName}.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final deleted = item;
                                      final deletedIdx = provider.receivables.indexOf(item);
                                      provider.deleteReceivable(item.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Cobro de "${deleted.debtorName}" eliminado'),
                                            duration: const Duration(seconds: 4),
                                            action: SnackBarAction(
                                              label: 'Deshacer',
                                              onPressed: () => provider.restoreReceivable(
                                                  deleted,
                                                  index: deletedIdx),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Prestado: ${CurrencyFormatter.format(item.totalAmount)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Abonado: ${CurrencyFormatter.format(item.paidAmount)}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF059669)),
                            ),
                            Text(
                              'Falta: ${CurrencyFormatter.format(item.remainingAmount)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: item.isSettled
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: item.progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          color: const Color(0xFF059669),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!item.isSettled) ...[
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    _showCollectDialog(context, provider, item),
                                icon: const Icon(Icons.payments_outlined,
                                    size: 16),
                                label: const Text('Registrar Abono / Cobro'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final msg =
                                      'Hola ${item.debtorName}, te escribo para recordarte el saldo pendiente por "${item.concept}": ${CurrencyFormatter.format(item.remainingAmount)}.- ¡Gracias!';
                                  await Clipboard.setData(
                                      ClipboardData(text: msg));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              '✓ Recordatorio copiado para WhatsApp')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copiar recordatorio WhatsApp'),
                              ),
                            ] else
                              const Chip(label: Text('✓ Pagado por completo')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        onPressed: () => _showAddReceivableDialog(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Registrar Préstamo a Tercero'),
      ),
    );
  }

  void _showAddReceivableDialog(
      BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final conceptCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Dinero por Cobrar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: '¿Quién te debe? (Nombre)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: conceptCtrl,
              decoration:
                  const InputDecoration(labelText: 'Concepto o motivo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Monto total', prefixText: '\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              if (amt <= 0 || nameCtrl.text.trim().isEmpty) return;
              provider.addReceivable(
                debtorName: nameCtrl.text.trim(),
                concept: conceptCtrl.text.trim().isEmpty
                    ? 'Préstamo'
                    : conceptCtrl.text.trim(),
                totalAmount: amt,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showCollectDialog(
      BuildContext context, FinanceProvider provider, ReceivableModel item) {
    final ctrl =
        TextEditingController(text: item.remainingAmount.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar cobro de ${item.debtorName}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monto recibido',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(ctrl.text) ?? 0;
              if (amt > 0) {
                provider.registerReceivablePayment(item.id, amt);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Confirmar Cobro'),
          ),
        ],
      ),
    );
  }

  void _showEditReceivableDialog(
      BuildContext context, FinanceProvider provider, ReceivableModel item) {
    final nameCtrl = TextEditingController(text: item.debtorName);
    final conceptCtrl = TextEditingController(text: item.concept);
    final totalCtrl = TextEditingController(
      text: item.totalAmount % 1 == 0
          ? item.totalAmount.toInt().toString()
          : item.totalAmount.toString(),
    );
    final paidCtrl = TextEditingController(
      text: item.paidAmount % 1 == 0
          ? item.paidAmount.toInt().toString()
          : item.paidAmount.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Cobro • ${item.debtorName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nombre del deudor'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: conceptCtrl,
                decoration: const InputDecoration(labelText: 'Concepto / Glosa'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: totalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Monto Total', prefixText: '\$ '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: paidCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Monto Ya Cobrado', prefixText: '\$ '),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final total = double.tryParse(totalCtrl.text) ?? item.totalAmount;
              final paid = double.tryParse(paidCtrl.text) ?? item.paidAmount;
              if (nameCtrl.text.trim().isEmpty) return;
              provider.updateReceivable(
                item.copyWith(
                  debtorName: nameCtrl.text.trim(),
                  concept: conceptCtrl.text.trim(),
                  totalAmount: total,
                  paidAmount: paid.clamp(0.0, total),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Módulo 6: Metas de Ahorro y "Sobres"
class SavingsGoalsModuleView extends StatelessWidget {
  const SavingsGoalsModuleView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas de Ahorro y Sobres'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar Plan (Google Sheets / Excel)',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Total Ahorrado en Sobres',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(provider.totalSavedInGoals),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Reserva Mensual Activa',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(
                              provider.reservedSavingsThisMonth),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (provider.savingsGoals.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                        'Aún no has creado sobres o metas de ahorro (ej: Fondo de Emergencia, Vacaciones).'),
                  ),
                ),
              )
            else
              ...provider.savingsGoals.map((goal) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                goal.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Editar',
                                  onPressed: () => _showEditGoalDialog(
                                      context, provider, goal),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('¿Eliminar sobre?'),
                                        content: Text(
                                            'Se eliminará el sobre "${goal.name}".'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final deleted = goal;
                                      final deletedIdx = provider.savingsGoals.indexOf(goal);
                                      provider.deleteSavingsGoal(goal.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Meta "${deleted.name}" eliminada'),
                                            duration: const Duration(seconds: 4),
                                            action: SnackBarAction(
                                              label: 'Deshacer',
                                              onPressed: () => provider.restoreSavingsGoal(
                                                  deleted,
                                                  index: deletedIdx),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ahorrado: ${CurrencyFormatter.format(goal.currentAmount)} de ${CurrencyFormatter.format(goal.targetAmount)} (${(goal.progress * 100).toInt()}%)',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (goal.monthlyContribution > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Cuota mensual sugerida: ${CurrencyFormatter.format(goal.monthlyContribution)} ${goal.reserveFromLiquidity ? "(Reservada de liquidez)" : ""}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF059669)),
                          ),
                        ],
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: goal.progress,
                          minHeight: 9,
                          borderRadius: BorderRadius.circular(5),
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: () =>
                                _showDepositGoalDialog(context, provider, goal),
                            icon: const Icon(Icons.savings_outlined, size: 16),
                            label: const Text('Abonar al Sobre'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        onPressed: () => _showAddGoalDialog(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Sobre / Meta'),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final monthlyCtrl = TextEditingController(text: '0');
    bool reserve = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Crear Meta de Ahorro / Sobre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del sobre',
                  hintText: 'Ej: Fondo de Emergencia, Vacaciones...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Meta Total', prefixText: '\$ '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: monthlyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aporte mensual sugerido',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reservar de mi liquidez mensual',
                    style: TextStyle(fontSize: 13)),
                value: reserve,
                onChanged: (v) => setStateDialog(() => reserve = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final target = double.tryParse(targetCtrl.text) ?? 0;
                final monthly = double.tryParse(monthlyCtrl.text) ?? 0;
                if (target <= 0 || nameCtrl.text.trim().isEmpty) return;
                provider.addSavingsGoal(
                  name: nameCtrl.text.trim(),
                  targetAmount: target,
                  monthlyContribution: monthly,
                  reserveFromLiquidity: reserve,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Crear Sobre'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositGoalDialog(
      BuildContext context, FinanceProvider provider, SavingsGoalModel goal) {
    final ctrl = TextEditingController(
      text: goal.monthlyContribution > 0
          ? goal.monthlyContribution.toInt().toString()
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abonar a "${goal.name}"'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Monto a depositar', prefixText: '\$ '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(ctrl.text) ?? 0;
              if (amt > 0) {
                provider.depositToSavingsGoal(goal.id, amt);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Depositar'),
          ),
        ],
      ),
    );
  }

  void _showEditGoalDialog(
      BuildContext context, FinanceProvider provider, SavingsGoalModel goal) {
    final nameCtrl = TextEditingController(text: goal.name);
    final targetCtrl = TextEditingController(
      text: goal.targetAmount % 1 == 0
          ? goal.targetAmount.toInt().toString()
          : goal.targetAmount.toString(),
    );
    final currentCtrl = TextEditingController(
      text: goal.currentAmount % 1 == 0
          ? goal.currentAmount.toInt().toString()
          : goal.currentAmount.toString(),
    );
    final monthlyCtrl = TextEditingController(
      text: goal.monthlyContribution % 1 == 0
          ? goal.monthlyContribution.toInt().toString()
          : goal.monthlyContribution.toString(),
    );
    bool reserve = goal.reserveFromLiquidity;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Editar Sobre • ${goal.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del sobre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Meta Total', prefixText: '\$ '),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: currentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Monto Ahorrado Actual', prefixText: '\$ '),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: monthlyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Aporte mensual sugerido',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reservar de mi liquidez mensual',
                      style: TextStyle(fontSize: 13)),
                  value: reserve,
                  onChanged: (v) => setStateDialog(() => reserve = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final target = double.tryParse(targetCtrl.text) ?? goal.targetAmount;
                final current = double.tryParse(currentCtrl.text) ?? goal.currentAmount;
                final monthly = double.tryParse(monthlyCtrl.text) ?? goal.monthlyContribution;
                if (nameCtrl.text.trim().isEmpty) return;
                provider.updateSavingsGoal(
                  goal.copyWith(
                    name: nameCtrl.text.trim(),
                    targetAmount: target,
                    currentAmount: current,
                    monthlyContribution: monthly,
                    reserveFromLiquidity: reserve,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Módulo 7: Suscripciones y Cobros Automáticos
class SubscriptionsModuleView extends StatelessWidget {
  const SubscriptionsModuleView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripciones y Pagos Recurrentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar Plan (Google Sheets / Excel)',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Costo Mensual Activo',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(
                              provider.totalMonthlySubscriptions),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEC4899),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Impacto Anualizado (12 meses)',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(
                              provider.totalAnnualSubscriptions),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (provider.subscriptions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                        'No hay suscripciones registradas (ej: Streaming, Gimnasio, Nube, Seguros).'),
                  ),
                ),
              )
            else
              ...provider.subscriptions.map((sub) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFFCE7F3),
                              child: Text(
                                'D${sub.billingDay}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFBE185D),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      height: 1.25,
                                      decoration: sub.isActive
                                          ? null
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Día ${sub.billingDay} de cada mes • ${CurrencyFormatter.format(sub.annualCost)} al año',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${CurrencyFormatter.format(sub.amount)}/mes',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFBE185D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  sub.isActive ? 'Activa' : 'Inactiva',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: sub.isActive
                                        ? const Color(0xFF059669)
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: sub.isActive,
                                    onChanged: (v) => provider
                                        .toggleSubscriptionActive(sub.id, v),
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (sub.isActive && !sub.paidThisMonth)
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                    ),
                                    onPressed: () => provider
                                        .paySubscriptionThisMonth(sub.id),
                                    icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 16),
                                    label: const Text('Pagar este mes',
                                        style: TextStyle(fontSize: 12)),
                                  )
                                else if (sub.paidThisMonth)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '✓ Pagada este mes',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF065F46)),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  tooltip: 'Editar',
                                  onPressed: () => _showEditSubscriptionDialog(
                                      context, provider, sub),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                            '¿Eliminar suscripción?'),
                                        content: Text(
                                            'Se eliminará "${sub.name}".'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final deleted = sub;
                                      final deletedIdx = provider.subscriptions.indexOf(sub);
                                      provider.deleteSubscription(sub.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Suscripción "${deleted.name}" eliminada'),
                                            duration: const Duration(seconds: 4),
                                            action: SnackBarAction(
                                              label: 'Deshacer',
                                              onPressed: () => provider.restoreSubscription(
                                                  deleted,
                                                  index: deletedIdx),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
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
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEC4899),
        foregroundColor: Colors.white,
        onPressed: () => _showAddSubscriptionDialog(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Suscripción'),
      ),
    );
  }

  void _showAddSubscriptionDialog(
      BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '15');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Suscripción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Servicio o membresía',
                hintText: 'Ej: Spotify, Gimnasio, Plan Celular...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Valor mensual', prefixText: '\$ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Día de cobro del mes (1 al 31)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              final day = int.tryParse(dayCtrl.text) ?? 1;
              if (amt <= 0 || nameCtrl.text.trim().isEmpty) return;
              provider.addSubscription(
                name: nameCtrl.text.trim(),
                amount: amt,
                billingDay: day,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditSubscriptionDialog(
      BuildContext context, FinanceProvider provider, SubscriptionModel sub) {
    final nameCtrl = TextEditingController(text: sub.name);
    final amountCtrl = TextEditingController(
      text: sub.amount % 1 == 0
          ? sub.amount.toInt().toString()
          : sub.amount.toString(),
    );
    final dayCtrl = TextEditingController(text: sub.billingDay.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Suscripción • ${sub.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Servicio o membresía',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Valor mensual', prefixText: '\$ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Día de cobro del mes (1 al 31)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text) ?? sub.amount;
              final day = int.tryParse(dayCtrl.text) ?? sub.billingDay;
              if (nameCtrl.text.trim().isEmpty) return;
              provider.updateSubscription(
                sub.copyWith(
                  name: nameCtrl.text.trim(),
                  amount: amt,
                  billingDay: day.clamp(1, 31),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Módulo 8: Gastos Hormiga y Presupuestos por Categoría (Semáforo)
class DailyBudgetModuleView extends StatelessWidget {
  const DailyBudgetModuleView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Hormiga y Presupuestos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar Plan (Google Sheets / Excel)',
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
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Crear tope de categoría',
            onPressed: () => _showAddCategoryDialog(context, provider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Semáforo de Topes Mensuales',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showAddCategoryDialog(context, provider),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nueva Categoría'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.budgetCategories.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                        'Define topes mensuales (ej: Delivery, Café/Snacks, Salidas) para activar el semáforo de presupuesto.'),
                  ),
                ),
              )
            else
              ...provider.budgetCategories.map((cat) {
                final spent = provider.spentInCategory(cat.id);
                final ratio = cat.monthlyLimit > 0
                    ? (spent / cat.monthlyLimit).clamp(0.0, 1.0)
                    : 0.0;
                final Color statusColor = ratio >= 1.0
                    ? const Color(0xFFDC2626)
                    : (ratio >= 0.75
                        ? const Color(0xFFD97706)
                        : const Color(0xFF059669));

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                cat.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${CurrencyFormatter.format(spent)} / ${CurrencyFormatter.format(cat.monthlyLimit)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: ratio,
                          minHeight: 9,
                          borderRadius: BorderRadius.circular(5),
                          color: statusColor,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ratio >= 1.0
                                  ? '¡Tope superado!'
                                  : 'Queda: ${CurrencyFormatter.format((cat.monthlyLimit - spent).clamp(0.0, double.infinity))}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: () => _showAddAntExpenseDialog(
                                      context, provider, cat),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Gasto',
                                      style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  tooltip: 'Editar categoría',
                                  onPressed: () => _showEditCategoryDialog(
                                      context, provider, cat),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                            '¿Eliminar categoría?'),
                                        content: Text(
                                            'Se eliminará "${cat.name}".'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final deleted = cat;
                                      final deletedIdx = provider.budgetCategories.indexOf(cat);
                                      provider.deleteBudgetCategory(cat.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Presupuesto "${deleted.name}" eliminado'),
                                            duration: const Duration(seconds: 4),
                                            action: SnackBarAction(
                                              label: 'Deshacer',
                                              onPressed: () => provider.restoreBudgetCategory(
                                                  deleted,
                                                  index: deletedIdx),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
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
            if (provider.antExpenses.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gastos Registrados en Categorías',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${provider.antExpenses.length} gastos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...provider.antExpenses.take(15).map((expense) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: Text(
                      expense.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${expense.categoryName} • ${expense.date.day}/${expense.date.month}/${expense.date.year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          CurrencyFormatter.format(expense.amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar gasto',
                          onPressed: () => _showEditAntExpenseDialog(
                              context, provider, expense),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Eliminar',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('¿Eliminar gasto?'),
                                content: Text('Se eliminará "${expense.title}".'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.redAccent),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final deleted = expense;
                              final deletedIdx = provider.antExpenses.indexOf(expense);
                              provider.deleteAntExpense(expense.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gasto "${deleted.title}" eliminado'),
                                    duration: const Duration(seconds: 4),
                                    action: SnackBarAction(
                                      label: 'Deshacer',
                                      onPressed: () => provider.restoreAntExpense(
                                          deleted,
                                          index: deletedIdx),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
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
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        onPressed: () => _showAddCategoryDialog(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Tope de Presupuesto'),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final limitCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear Categoría con Tope Mensual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                hintText: 'Ej: Delivery, Cafetería, Salidas...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Tope máximo mensual', prefixText: '\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final lim = double.tryParse(limitCtrl.text) ?? 0;
              if (lim <= 0 || nameCtrl.text.trim().isEmpty) return;
              provider.addBudgetCategory(
                name: nameCtrl.text.trim(),
                monthlyLimit: lim,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showAddAntExpenseDialog(BuildContext context, FinanceProvider provider,
      BudgetCategoryModel cat) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gasto en ${cat.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Detalle'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              if (amt <= 0) return;
              provider.addAntExpense(
                categoryId: cat.id,
                categoryName: cat.name,
                title: titleCtrl.text.trim(),
                amount: amt,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, FinanceProvider provider,
      BudgetCategoryModel cat) {
    final nameCtrl = TextEditingController(text: cat.name);
    final limitCtrl = TextEditingController(
      text: cat.monthlyLimit % 1 == 0
          ? cat.monthlyLimit.toInt().toString()
          : cat.monthlyLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Categoría • ${cat.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Tope máximo mensual', prefixText: '\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final lim = double.tryParse(limitCtrl.text) ?? cat.monthlyLimit;
              if (nameCtrl.text.trim().isEmpty) return;
              provider.updateBudgetCategory(
                cat.copyWith(
                  name: nameCtrl.text.trim(),
                  monthlyLimit: lim,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditAntExpenseDialog(BuildContext context,
      FinanceProvider provider, AntExpenseModel expense) {
    final titleCtrl = TextEditingController(text: expense.title);
    final amountCtrl = TextEditingController(
      text: expense.amount % 1 == 0
          ? expense.amount.toInt().toString()
          : expense.amount.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Gasto Diario / Hormiga'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Monto', prefixText: '\$ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Detalle'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text) ?? expense.amount;
              if (amt <= 0) return;
              provider.updateAntExpense(
                expense.copyWith(
                  title: titleCtrl.text.trim(),
                  amount: amt,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Módulo 9: Tarjetas de Crédito y Facturación
class CreditCardsModuleView extends StatelessWidget {
  const CreditCardsModuleView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarjetas de Crédito y Facturación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar Plan (Google Sheets / Excel)',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text('FACTURACIÓN ACUMULADA PRÓXIMO MES',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.format(
                          provider.totalNextCreditCardBilling),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (provider.creditCards.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                        'No has registrado tarjetas de crédito para controlar cupo y facturación.'),
                  ),
                ),
              )
            else
              ...provider.creditCards.map((card) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                card.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Editar tarjeta',
                                  onPressed: () => _showEditCardDialog(
                                      context, provider, card),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                            '¿Eliminar tarjeta de crédito?'),
                                        content: Text(
                                            'Se eliminará "${card.name}".'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final deleted = card;
                                      final deletedIdx = provider.creditCards.indexOf(card);
                                      provider.deleteCreditCard(card.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Tarjeta "${deleted.name}" eliminada'),
                                            duration: const Duration(seconds: 4),
                                            action: SnackBarAction(
                                              label: 'Deshacer',
                                              onPressed: () => provider.restoreCreditCard(
                                                  deleted,
                                                  index: deletedIdx),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Corte: día ${card.closingDay}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Vence: día ${card.dueDay}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Disponible: ${CurrencyFormatter.format(card.availableCredit)} de ${CurrencyFormatter.format(card.creditLimit)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: card.usageRatio,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          color: const Color(0xFF4F46E5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Facturación próx. mes: ${CurrencyFormatter.format(card.nextBillingAmount)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: () => _showCardChargeDialog(
                                      context, provider, card),
                                  child: const Text('+ Cargo'),
                                ),
                                if (card.nextBillingAmount > 0)
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                    ),
                                    onPressed: () =>
                                        provider.payCreditCardStatement(
                                            card.id, card.nextBillingAmount),
                                    child: const Text('Pagar Facturado'),
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
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        onPressed: () => _showAddCardDialog(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Agregar Tarjeta'),
      ),
    );
  }

  void _showAddCardDialog(BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    final closeCtrl = TextEditingController(text: '20');
    final dueCtrl = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Tarjeta de Crédito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Tarjeta',
                hintText: 'Ej: Visa Banco, Mastercard...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Cupo Total', prefixText: '\$ '),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: closeCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Día Facturación'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: dueCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Día Pago'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final lim = double.tryParse(limitCtrl.text) ?? 0;
              if (lim <= 0 || nameCtrl.text.trim().isEmpty) return;
              provider.addCreditCard(
                name: nameCtrl.text.trim(),
                creditLimit: lim,
                closingDay: int.tryParse(closeCtrl.text) ?? 20,
                dueDay: int.tryParse(dueCtrl.text) ?? 5,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showCardChargeDialog(
      BuildContext context, FinanceProvider provider, CreditCardModel card) {
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar compra en ${card.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amtCtrl.text) ?? 0;
              if (amt > 0) {
                provider.addCardCharge(card.id, amt, descCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditCardDialog(
      BuildContext context, FinanceProvider provider, CreditCardModel card) {
    final nameCtrl = TextEditingController(text: card.name);
    final limitCtrl = TextEditingController(
      text: card.creditLimit % 1 == 0
          ? card.creditLimit.toInt().toString()
          : card.creditLimit.toString(),
    );
    final usedCtrl = TextEditingController(
      text: card.usedAmount % 1 == 0
          ? card.usedAmount.toInt().toString()
          : card.usedAmount.toString(),
    );
    final nextBillingCtrl = TextEditingController(
      text: card.nextBillingAmount % 1 == 0
          ? card.nextBillingAmount.toInt().toString()
          : card.nextBillingAmount.toString(),
    );
    final closeCtrl = TextEditingController(text: card.closingDay.toString());
    final dueCtrl = TextEditingController(text: card.dueDay.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Tarjeta • ${card.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nombre de la Tarjeta'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Cupo Total', prefixText: '\$ '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: usedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Cupo Utilizado Total', prefixText: '\$ '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nextBillingCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Facturación próximo mes', prefixText: '\$ '),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: closeCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Día Corte'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: dueCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Día Pago'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final lim = double.tryParse(limitCtrl.text) ?? card.creditLimit;
              final used = double.tryParse(usedCtrl.text) ?? card.usedAmount;
              final nextBill =
                  double.tryParse(nextBillingCtrl.text) ?? card.nextBillingAmount;
              if (nameCtrl.text.trim().isEmpty) return;
              provider.updateCreditCard(
                card.copyWith(
                  name: nameCtrl.text.trim(),
                  creditLimit: lim,
                  usedAmount: used,
                  nextBillingAmount: nextBill,
                  closingDay: int.tryParse(closeCtrl.text) ?? card.closingDay,
                  dueDay: int.tryParse(dueCtrl.text) ?? card.dueDay,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Módulo 10: Lista de Compras / Supermercado
class ShoppingListModuleView extends StatelessWidget {
  const ShoppingListModuleView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras / Presupuesto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add, color: AppTheme.primaryTeal),
            tooltip: 'Crear nueva lista de compras',
            onPressed: () => _showNewShoppingListDialog(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart, color: Color(0xFF0F9D58)),
            tooltip: 'Exportar Plan (Google Sheets / Excel)',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildShoppingListSelector(context, provider),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Total Lista Estimada',
                                style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(
                                  provider.shoppingCartEstimatedTotal),
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('En el Carrito (Marcados)',
                                style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(
                                  provider.shoppingCartCheckedTotal),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0891B2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (provider.shoppingItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              provider.checkoutShoppingCart(
                                  chargeToOpenAccount: false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        '✓ Compra registrada en tus Gastos del Mes')),
                              );
                            },
                            icon: const Icon(Icons.receipt_long, size: 18),
                            label: const Text('Pasar a Gasto del Mes'),
                          ),
                          if (provider.isModuleActive(AppModuleId.openAccounts))
                            OutlinedButton.icon(
                              onPressed: () {
                                provider.checkoutShoppingCart(
                                    chargeToOpenAccount: true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '✓ Compra cargada a tu Libreta (${provider.selectedOpenAccount})')),
                                );
                              },
                              icon: const Icon(Icons.storefront, size: 18),
                              label: Text(
                                  'Cargar a Libreta (${provider.selectedOpenAccount})'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (provider.shoppingItems.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      provider.shoppingLists.isEmpty
                          ? 'Aún no tienes ninguna lista de compras. Crea la primera con el botón "+ Nueva lista" (en el AppBar o junto a la última).'
                          : 'Tu lista de compras está vacía. Agrega productos para calcular cuánto gastarás antes de ir a pagar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              ...provider.shoppingItems.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: item.isChecked,
                          onChanged: (v) => provider
                              .toggleShoppingItemChecked(item.id, v ?? false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.name} (x${item.quantity})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  decoration: item.isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${CurrencyFormatter.format(item.estimatedPrice)} c/u • Subtotal: ${CurrencyFormatter.format(item.subtotal)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Editar producto',
                              onPressed: () => _showEditShoppingItemDialog(
                                  context, provider, item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Eliminar',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('¿Eliminar producto?'),
                                    content:
                                        Text('Se eliminará "${item.name}".'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Colors.redAccent),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final deleted = item;
                                  final deletedIdx = provider.shoppingItems.indexOf(item);
                                  provider.deleteShoppingItem(item.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Artículo "${deleted.name}" eliminado'),
                                        duration: const Duration(seconds: 4),
                                        action: SnackBarAction(
                                          label: 'Deshacer',
                                          onPressed: () => provider.restoreShoppingItem(
                                              deleted,
                                              index: deletedIdx),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        onPressed: () => _showAddShoppingItemDialog(context, provider),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Agregar Producto'),
      ),
    );
  }

  Widget _buildShoppingListSelector(
      BuildContext context, FinanceProvider provider) {
    final theme = Theme.of(context);
    final active = provider.activeShoppingList;
    final activeId = active?.id;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_add_check_circle_outlined,
                    color: AppTheme.primaryTeal),
                const SizedBox(width: 8),
                const Text('Mis Listas de Compras',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  '${provider.shoppingLists.length} listas',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final list in provider.shoppingLists)
                  InputChip(
                    label: Text(list.name),
                    selected: list.id == activeId,
                    selectedColor:
                        AppTheme.primaryTeal.withValues(alpha: 0.25),
                    avatar: CircleAvatar(
                      backgroundColor:
                          AppTheme.primaryTeal.withValues(alpha: 0.15),
                      child: Text(
                        '${list.items.length}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onPressed: () =>
                        provider.setActiveShoppingList(list.id),
                    onDeleted: () => _showDeleteShoppingListDialog(
                        context, provider, list),
                    deleteButtonTooltipMessage:
                        'Eliminar lista "${list.name}"',
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva lista'),
                  onPressed: () =>
                      _showNewShoppingListDialog(context, provider),
                ),
              ],
            ),
            if (active != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppTheme.primaryTeal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Editando: ${active.name}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.drive_file_rename_outline, size: 16),
                    label: const Text('Renombrar'),
                    onPressed: () => _showRenameShoppingListDialog(
                        context, provider, active),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showNewShoppingListDialog(
      BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva lista de compras'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la lista',
            hintText: 'Ej: Supermercado, Farmacia, Home Depot...',
            prefixIcon: Icon(Icons.playlist_add_check),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              provider.createShoppingList(n.isEmpty ? 'Nueva lista' : n);
              Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showRenameShoppingListDialog(BuildContext context,
      FinanceProvider provider, ShoppingListModel list) {
    final nameCtrl = TextEditingController(text: list.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar lista'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nuevo nombre',
            prefixIcon: Icon(Icons.drive_file_rename_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              provider.renameShoppingList(list.id, nameCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteShoppingListDialog(BuildContext context,
      FinanceProvider provider, ShoppingListModel list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar lista de compras?'),
        content: Text(
            'Se eliminará la lista "${list.name}" y sus ${list.items.length} producto(s). Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      provider.deleteShoppingList(list.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lista "${list.name}" eliminada')),
        );
      }
    }
  }

  void _showAddShoppingItemDialog(
      BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar a la Lista de Compras'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Producto / Artículo'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Precio unitario est.', prefixText: '\$ '),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final price = double.tryParse(priceCtrl.text) ?? 0;
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              if (nameCtrl.text.trim().isEmpty) return;
              provider.addShoppingItem(
                name: nameCtrl.text.trim(),
                estimatedPrice: price,
                quantity: qty,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showEditShoppingItemDialog(
      BuildContext context, FinanceProvider provider, ShoppingItemModel item) {
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(
      text: item.estimatedPrice % 1 == 0
          ? item.estimatedPrice.toInt().toString()
          : item.estimatedPrice.toString(),
    );
    final qtyCtrl = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar Producto • ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Producto / Artículo'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Precio unitario est.', prefixText: '\$ '),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final price =
                  double.tryParse(priceCtrl.text) ?? item.estimatedPrice;
              final qty = int.tryParse(qtyCtrl.text) ?? item.quantity;
              if (nameCtrl.text.trim().isEmpty) return;
              provider.updateShoppingItem(
                item.copyWith(
                  name: nameCtrl.text.trim(),
                  estimatedPrice: price,
                  quantity: qty < 1 ? 1 : qty,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
