import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fiado_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/add_fiado_dialog.dart';
import '../widgets/pay_fiado_dialog.dart';

class FiadoView extends StatelessWidget {
  const FiadoView({super.key});

  void _showNewAccountDialog(BuildContext context, FinanceProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Libreta / Cuenta Abierta'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del comercio o libreta',
            hintText: 'Ej: Almacén del barrio, Verdulería, Taller...',
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                provider.addOpenAccountName(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear Libreta'),
          ),
        ],
      ),
    );
  }

  void _showRenameAccountDialog(
      BuildContext context, FinanceProvider provider, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar Libreta'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nuevo nombre de la libreta',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final next = ctrl.text.trim();
              if (next.isNotEmpty) {
                provider.renameOpenAccount(currentName, next);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(
      BuildContext context, FinanceProvider provider, String accountName) {
    final pending = provider.pendingForOpenAccount(accountName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Eliminar Libreta')),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la libreta "$accountName"?\n\n'
          '• Saldo pendiente actual: ${CurrencyFormatter.format(pending)}\n'
          '• Se borrarán todos los cargos y abonos asociados a esta libreta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await provider.deleteOpenAccount(accountName);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Libreta "$accountName" eliminada'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar Libreta'),
          ),
        ],
      ),
    );
  }

  void _showEditFiadoEntryDialog(
      BuildContext context, FinanceProvider provider, FiadoEntry entry) {
    final amountCtrl = TextEditingController(
      text: entry.amount % 1 == 0
          ? entry.amount.toInt().toString()
          : entry.amount.toString(),
    );
    final noteCtrl = TextEditingController(text: entry.note);
    String selectedAcc = entry.accountName;
    DateTime selectedDate = entry.date;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Cargo a Cuenta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Monto del Cargo',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Detalle / Artículos comprados',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                if (provider.openAccountNames.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: provider.openAccountNames.contains(selectedAcc)
                        ? selectedAcc
                        : provider.openAccountNames.first,
                    decoration: const InputDecoration(
                      labelText: 'Mover a libreta',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    items: provider.openAccountNames
                        .map((acc) => DropdownMenuItem(value: acc, child: Text(acc)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedAcc = val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                        });
                      }
                    },
                    child: const Text('Cambiar'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text);
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un monto válido')),
                  );
                  return;
                }
                final updated = entry.copyWith(
                  amount: amt,
                  note: noteCtrl.text.trim().isEmpty ? 'Compra a cuenta' : noteCtrl.text.trim(),
                  accountName: selectedAcc,
                  date: selectedDate,
                );
                provider.updateFiadoEntry(updated);
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFiadoPaymentDialog(
      BuildContext context, FinanceProvider provider, FiadoPayment payment) {
    final amountCtrl = TextEditingController(
      text: payment.amountPaid % 1 == 0
          ? payment.amountPaid.toInt().toString()
          : payment.amountPaid.toString(),
    );
    final noteCtrl = TextEditingController(text: payment.note);
    DateTime selectedDate = payment.date;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Abono / Pago'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Monto Abonado',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Detalle o Glosa del Abono',
                    prefixIcon: Icon(Icons.payment),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: const Text('Cambiar'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text);
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un monto válido')),
                  );
                  return;
                }
                final updated = payment.copyWith(
                  amountPaid: amt,
                  note: noteCtrl.text.trim().isEmpty ? 'Abono cuenta' : noteCtrl.text.trim(),
                  date: selectedDate,
                );
                provider.updateFiadoPayment(updated);
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final hasAccounts = provider.openAccountNames.isNotEmpty;
    final selectedAcc = provider.selectedOpenAccount;
    final entries = provider.selectedAccountEntries;
    final payments = provider.selectedAccountPayments;
    final pendingSelected =
        hasAccounts ? provider.pendingForOpenAccount(selectedAcc) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Libretas y Cuentas Abiertas'),
        actions: [
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
            tooltip: 'Nueva Libreta',
            onPressed: () => _showNewAccountDialog(context, provider),
          ),
          if (hasAccounts) ...[
            IconButton(
              icon: const Icon(Icons.payment),
              tooltip: 'Abonar / Pagar',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const PayFiadoDialog(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Anotar a Cuenta',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const AddFiadoDialog(),
                );
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: 16,
        ),
        child: !hasAccounts
            ? _buildEmptyAccountsState(context, provider, theme, isDark)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SELECTOR DE MÚLTIPLES LIBRETAS / CUENTAS ABIERTAS CON OPCIÓN DE BORRAR
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...provider.openAccountNames.map((acc) {
                          final isSelected = acc == selectedAcc;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InputChip(
                              label: Text(acc),
                              selected: isSelected,
                              onSelected: (_) =>
                                  provider.setSelectedOpenAccount(acc),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              deleteButtonTooltipMessage:
                                  'Eliminar libreta "$acc"',
                              onDeleted: () => _showDeleteAccountDialog(
                                  context, provider, acc),
                            ),
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Nueva Libreta'),
                          onPressed: () =>
                              _showNewAccountDialog(context, provider),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // GRAN TARJETA DE ESTADO DE CUENTA
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark
                            ? AppTheme.fiadoDark.withValues(alpha: 0.4)
                            : AppTheme.fiadoLight.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    color:
                        isDark ? AppTheme.fiadoBgDark : AppTheme.fiadoBgLight,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.storefront,
                                color: isDark
                                    ? AppTheme.fiadoDark
                                    : AppTheme.fiadoLight,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Libreta: $selectedAcc',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 19),
                                tooltip: 'Renombrar esta libreta',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _showRenameAccountDialog(
                                    context, provider, selectedAcc),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: Colors.redAccent),
                                tooltip: 'Eliminar esta libreta',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _showDeleteAccountDialog(
                                    context, provider, selectedAcc),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'SALDO PENDIENTE EN ESTA LIBRETA',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(pendingSelected),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? const Color(0xFFFBBF24)
                                  : AppTheme.fiadoLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(
                              color: isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'Total Todas las Libretas',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(
                                        provider.totalPendingFiado),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: isDark
                                    ? AppTheme.darkBorder
                                    : AppTheme.lightBorder,
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Total Abonado',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(
                                        provider.totalFiadoPaid),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppTheme.incomeDark
                                          : AppTheme.incomeLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? AppTheme.primaryTealDark
                                : AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const AddFiadoDialog(),
                            );
                          },
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Anotar a Cuenta (+)',
                              style: TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark
                                  ? AppTheme.fiadoDark
                                  : AppTheme.fiadoLight,
                              width: 1.5,
                            ),
                            foregroundColor: isDark
                                ? AppTheme.fiadoDark
                                : AppTheme.fiadoLight,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const PayFiadoDialog(),
                            );
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('Pagar / Abonar',
                              style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Detalle de Cargos ($selectedAcc)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '${entries.length} registros',
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No hay compras o cargos anotados en "$selectedAcc" aún.',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final dateStr =
                            DateFormat('dd/MM/yyyy • HH:mm').format(entry.date);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: theme.colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isDark
                                          ? AppTheme.fiadoDark.withValues(alpha: 0.2)
                                          : const Color(0xFFFEF3C7),
                                      child: Text(
                                        '#${entries.length - index}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? const Color(0xFFFDE68A)
                                              : const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.note.isEmpty
                                                ? 'Cargo a cuenta'
                                                : entry.note,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: theme.colorScheme.onSurface,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dateStr,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.format(entry.amount),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? const Color(0xFFFBBF24)
                                            : AppTheme.fiadoLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
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
                                      onPressed: () => _showEditFiadoEntryDialog(context, provider, entry),
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
                                            title: const Text('¿Eliminar cargo?'),
                                            content: Text('Se eliminará este cargo de ${CurrencyFormatter.format(entry.amount)}.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          final deletedEntry = entry;
                                          final deletedIdx = provider.fiadoEntries.indexOf(entry);
                                          provider.deleteFiadoEntry(entry.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).clearSnackBars();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(deletedEntry.note.isNotEmpty
                                                    ? 'Anotación "${deletedEntry.note}" eliminada'
                                                    : 'Anotación eliminada'),
                                                duration: const Duration(seconds: 4),
                                                action: SnackBarAction(
                                                  label: 'Deshacer',
                                                  onPressed: () {
                                                    provider.restoreFiadoEntry(deletedEntry, index: deletedIdx);
                                                  },
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
                      },
                    ),

                  const SizedBox(height: 24),

                  if (payments.isNotEmpty) ...[
                    Text(
                      'Historial de Abonos ($selectedAcc)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        final dateStr =
                            DateFormat('dd/MM/yyyy').format(payment.date);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isDark
                                          ? AppTheme.incomeDark.withValues(alpha: 0.25)
                                          : const Color(0xFFD1FAE5),
                                      child: Icon(
                                        Icons.check,
                                        color: isDark
                                            ? AppTheme.incomeDark
                                            : AppTheme.incomeLight,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            payment.note.isEmpty
                                                ? 'Abono realizado'
                                                : payment.note,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: theme.colorScheme.onSurface,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$dateStr • Restante tras pago: ${CurrencyFormatter.format(payment.remainingBalance)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '+ ${CurrencyFormatter.format(payment.amountPaid)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppTheme.incomeDark
                                            : AppTheme.incomeLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
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
                                      onPressed: () => _showEditFiadoPaymentDialog(context, provider, payment),
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
                                            title: const Text('¿Eliminar abono?'),
                                            content: Text('Se eliminará este abono de ${CurrencyFormatter.format(payment.amountPaid)}.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          final deletedPayment = payment;
                                          final deletedIdx = provider.fiadoPayments.indexOf(payment);
                                          provider.deleteFiadoPayment(payment.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).clearSnackBars();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text('Abono eliminado'),
                                                duration: const Duration(seconds: 4),
                                                action: SnackBarAction(
                                                  label: 'Deshacer',
                                                  onPressed: () {
                                                    provider.restoreFiadoPayment(deletedPayment, index: deletedIdx);
                                                  },
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
                      },
                    ),
                  ],
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppTheme.fiadoDark : AppTheme.fiadoLight,
        foregroundColor: Colors.white,
        onPressed: () {
          if (!hasAccounts) {
            _showNewAccountDialog(context, provider);
          } else {
            showDialog(
              context: context,
              builder: (_) => const AddFiadoDialog(),
            );
          }
        },
        icon: Icon(hasAccounts ? Icons.add : Icons.create_new_folder_outlined),
        label: Text(hasAccounts ? '+ Anotar a Cuenta' : '+ Crear Libreta'),
      ),
    );
  }

  Widget _buildEmptyAccountsState(
    BuildContext context,
    FinanceProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 56,
                color: isDark ? AppTheme.fiadoDark : AppTheme.fiadoLight,
              ),
              const SizedBox(height: 16),
              Text(
                'No tienes libretas o cuentas abiertas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crea una libreta para llevar el control de compras a cuenta en un almacén, verdulería o comercio.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isDark ? AppTheme.fiadoDark : AppTheme.fiadoLight,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: () => _showNewAccountDialog(context, provider),
                icon: const Icon(Icons.add),
                label: const Text('Crear Primera Libreta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
