import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class AddFiadoDialog extends StatefulWidget {
  const AddFiadoDialog({super.key});

  @override
  State<AddFiadoDialog> createState() => _AddFiadoDialogState();
}

class _AddFiadoDialogState extends State<AddFiadoDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addQuickAmount(int value) {
    final current = double.tryParse(_amountController.text) ?? 0;
    _amountController.text = (current + value).toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.fiadoDark.withValues(alpha: 0.25) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.storefront, color: isDark ? AppTheme.fiadoDark : AppTheme.fiadoLight, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Anotar en ${context.watch<FinanceProvider>().selectedOpenAccount}',
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Cuánto agregaste a esta cuenta hoy?',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Chips de montos rápidos
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: const Text('+ \$1.000'),
                  onPressed: () => _addQuickAmount(1000),
                ),
                ActionChip(
                  label: const Text('+ \$2.000'),
                  onPressed: () => _addQuickAmount(2000),
                ),
                ActionChip(
                  label: const Text('+ \$5.000'),
                  onPressed: () => _addQuickAmount(5000),
                ),
                ActionChip(
                  label: const Text('+ \$10.000'),
                  onPressed: () => _addQuickAmount(10000),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Detalle (opcional)',
                hintText: 'Ej: Pan, cecinas, bebidas...',
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text(
                'Fecha: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? AppTheme.fiadoDark : AppTheme.fiadoLight,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final amount = double.tryParse(_amountController.text);
            if (amount == null || amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Por favor ingresa un monto válido')),
              );
              return;
            }
            context.read<FinanceProvider>().addFiadoEntry(
                  amount,
                  note: _noteController.text.trim(),
                  date: _selectedDate,
                );
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Compra fiada anotada con éxito'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.check),
          label: const Text('Guardar Fiado'),
        ),
      ],
    );
  }
}
