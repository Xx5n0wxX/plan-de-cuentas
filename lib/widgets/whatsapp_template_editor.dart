import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class WhatsAppTemplateEditor extends StatefulWidget {
  final TextEditingController controller;
  final String creditor;
  final String label;
  final int loanNumber;
  final int currentCuota;
  final int totalCuotas;
  final double amount;
  final ValueChanged<String>? onChanged;

  const WhatsAppTemplateEditor({
    super.key,
    required this.controller,
    this.creditor = 'ACREEDOR',
    this.label = 'No 1',
    this.loanNumber = 1,
    this.currentCuota = 1,
    this.totalCuotas = 5,
    this.amount = 50000,
    this.onChanged,
  });

  @override
  State<WhatsAppTemplateEditor> createState() => _WhatsAppTemplateEditorState();
}

class _WhatsAppTemplateEditorState extends State<WhatsAppTemplateEditor> {
  static const String defaultTemplate =
      'PRESTAMO {ACREEDOR} [{ETIQUETA}] CUOTA {CUOTA}/{TOTAL} {MONTO}.-';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _insertVariable(String variable) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    int start = selection.start;
    int end = selection.end;
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }
    final newText = text.replaceRange(start, end, variable);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + variable.length),
    );
    widget.onChanged?.call(newText);
  }

  void _resetDefault() {
    widget.controller.text = defaultTemplate;
    widget.onChanged?.call(defaultTemplate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sampleCreditor =
        widget.creditor.trim().isEmpty ? 'ACREEDOR' : widget.creditor.trim();
    final sampleLabel =
        widget.label.trim().isEmpty ? 'No 1' : widget.label.trim();
    final sampleNumber = widget.loanNumber > 0 ? widget.loanNumber : 1;
    final sampleCuota = widget.currentCuota > 0 ? widget.currentCuota : 1;
    final sampleTotal = widget.totalCuotas > 0 ? widget.totalCuotas : 5;
    final sampleAmount = widget.amount > 0 ? widget.amount : 50000.0;

    final previewText = CurrencyFormatter.formatLoanReceipt(
      creditor: sampleCreditor,
      label: sampleLabel,
      loanNumber: sampleNumber,
      currentCuota: sampleCuota,
      totalCuotas: sampleTotal,
      amount: sampleAmount,
      customTemplate: widget.controller.text.trim().isEmpty
          ? defaultTemplate
          : widget.controller.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: 'Plantilla de Comprobante (WhatsApp)',
            alignLabelWithHint: true,
            hintText: defaultTemplate,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        // Sección variables
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Variables (toca para insertar):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            InkWell(
              onTap: _resetDefault,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'Restablecer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.primaryTealDark
                        : AppTheme.primaryTeal,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildChip(context, '{ACREEDOR}', 'Acreedor'),
            _buildChip(context, '{ETIQUETA}', 'Etiqueta'),
            _buildChip(context, '{NUMERO}', 'N°'),
            _buildChip(context, '{CUOTA}', 'Cuota'),
            _buildChip(context, '{TOTAL}', 'Total'),
            _buildChip(context, '{MONTO}', 'Monto'),
          ],
        ),
        const SizedBox(height: 12),
        // Live Preview Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 14, color: Color(0xFF25D366)),
                  const SizedBox(width: 6),
                  Text(
                    'Vista previa del comprobante:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                previewText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String code, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ActionChip(
      onPressed: () => _insertVariable(code),
      avatar: const Icon(Icons.add, size: 14, color: Color(0xFF25D366)),
      label: Text(
        code,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      tooltip: 'Insertar variable $label ($code)',
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      backgroundColor:
          isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}
