import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/modular_models.dart';
import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';

class AddTransactionDialog extends StatefulWidget {
  final TransactionType initialType;
  final bool initialShared;
  final TransactionModel? transactionToEdit;

  const AddTransactionDialog({
    super.key,
    this.initialType = TransactionType.expense,
    this.initialShared = false,
    this.transactionToEdit,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  late TransactionType _type;
  late bool _isShared;
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'Gastos Diarios';
  DateTime _selectedDate = DateTime.now();

  final List<String> _expenseCategories = [
    'Gastos Diarios',
    'Arriendo / Dividendo',
    'Servicios (Luz/Agua/Gas)',
    'Internet / Teléfono',
    'Mercadería / Supermercado',
    'Transporte / Bencina',
    'Salud / Farmacia',
    'Suscripciones / Streaming',
    'Ocio / Salidas',
    'Otros',
  ];

  final List<String> _incomeCategories = [
    'Sueldo',
    'Honorarios / Trabajo extra',
    'Cobros / Devoluciones',
    'Venta',
    'Pensión / Beca',
    'Otros Ingresos',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.transactionToEdit;
    if (edit != null) {
      _type = edit.type;
      _isShared = edit.isShared;
      _titleController.text = edit.title;
      _amountController.text = edit.amount % 1 == 0
          ? edit.amount.toInt().toString()
          : edit.amount.toString();
      _noteController.text = edit.note ?? '';
      _selectedCategory = edit.category;
      _selectedDate = edit.date;
    } else {
      _type = widget.initialType;
      _isShared = widget.initialShared;
      _selectedCategory =
          _type == TransactionType.income ? 'Sueldo' : 'Gastos Diarios';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final categories =
        _type == TransactionType.income ? _incomeCategories : _expenseCategories;
    final showSharedOption = _type == TransactionType.expense &&
        provider.isModuleActive(AppModuleId.sharedExpenses);

    final isEditing = widget.transactionToEdit != null;
    return AlertDialog(
      title: Text(isEditing
          ? (_type == TransactionType.income
              ? 'Editar Ingreso'
              : 'Editar Gasto')
          : (_type == TransactionType.income
              ? 'Registrar Ingreso'
              : 'Registrar Gasto')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Gasto'),
                  icon: Icon(Icons.arrow_downward, color: Colors.red),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Ingreso'),
                  icon: Icon(Icons.arrow_upward, color: Colors.green),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (newSet) {
                setState(() {
                  _type = newSet.first;
                  if (!categories.contains(_selectedCategory)) {
                    _selectedCategory = _type == TransactionType.income
                        ? 'Sueldo'
                        : 'Gastos Diarios';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              autofocus: !isEditing,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '\$ ',
                labelText: 'Monto',
                filled: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Concepto / Glosa',
                hintText: _type == TransactionType.income
                    ? 'Ej: Sueldo Mensual'
                    : 'Ej: Arriendo, Luz, Almuerzo...',
                prefixIcon: const Icon(Icons.label_outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: categories.contains(_selectedCategory)
                  ? _selectedCategory
                  : categories.first,
              decoration: InputDecoration(
                labelText: 'Categoría',
                prefixIcon: const Icon(Icons.category_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Nota u observación (opcional)',
                hintText: 'Detalles adicionales...',
                prefixIcon: const Icon(Icons.notes_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (showSharedOption) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Gasto compartido con ${provider.sharedConfig.partnerName}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Se divide ${provider.sharedConfig.myPercentage.toInt()}% / ${provider.sharedConfig.partnerPercentage.toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _isShared,
                onChanged: (v) => setState(() => _isShared = v),
              ),
            ],
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text(
                'Fecha: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
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
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amountController.text);
            final title = _titleController.text.trim();
            if (amount == null || amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingresa un monto válido')),
              );
              return;
            }
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingresa un concepto o glosa')),
              );
              return;
            }

            final finProvider = context.read<FinanceProvider>();
            if (isEditing) {
              final updated = widget.transactionToEdit!.copyWith(
                title: title,
                amount: amount,
                type: _type,
                category: _selectedCategory,
                date: _selectedDate,
                note: _noteController.text.trim(),
                isShared: showSharedOption && _isShared,
              );
              finProvider.updateTransaction(updated);
            } else {
              finProvider.addTransaction(
                title: title,
                amount: amount,
                type: _type,
                category: _selectedCategory,
                date: _selectedDate,
                note: _noteController.text.trim(),
                isShared: showSharedOption && _isShared,
              );
            }

            Navigator.of(context).pop();
          },
          child: Text(isEditing ? 'Actualizar' : 'Guardar'),
        ),
      ],
    );
  }
}
