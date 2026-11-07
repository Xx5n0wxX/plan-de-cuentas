import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key});

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _useCamera = !kIsWeb;
  bool _isProcessing = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitPairingCode(String rawInput) async {
    if (_isProcessing) return;

    String cleanCode = rawInput.trim().toUpperCase();
    if (cleanCode.contains('CODE=')) {
      cleanCode = cleanCode.split('CODE=').last.split('&').first;
    }
    cleanCode = cleanCode.replaceAll('-', '').replaceAll(' ', '');

    if (cleanCode.length != 6) {
      setState(() {
        _errorText = 'El código debe tener 6 caracteres (ej: A7X92B)';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorText = null;
    });

    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();
    final vaultId = auth.vaultId ?? 'default_vault';
    final ownerName = auth.user?.displayName ?? 'Mi Teléfono';

    final success = await finance.authorizeQrPairing(
      code: cleanCode,
      vaultId: vaultId,
      ownerName: ownerName,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isProcessing = false;
        _errorText =
            'No se pudo vincular. Verifica tu conexión e inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          const Icon(Icons.qr_code_scanner, color: AppTheme.primaryTeal),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Vincular un dispositivo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector Cámara vs Código de 6 dígitos (estilo WhatsApp)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text('Escanear QR'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.pin_outlined, size: 18),
                    label: Text('Usar código'),
                  ),
                ],
                selected: {_useCamera},
                onSelectionChanged: (sel) {
                  setState(() {
                    _useCamera = sel.first;
                    _errorText = null;
                  });
                },
              ),
              const SizedBox(height: 18),

              if (_isProcessing) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Sincronizando tus cuentas con la PC...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
              ] else if (_useCamera) ...[
                Text(
                  'Apunta la cámara al código QR que aparece en Plan de Cuentas en tu PC.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 240,
                    width: double.infinity,
                    child: MobileScanner(
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final val = barcode.rawValue;
                          if (val != null && val.isNotEmpty) {
                            _submitPairingCode(val);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => setState(() => _useCamera = false),
                  icon: const Icon(Icons.keyboard, size: 16),
                  label: const Text('¿Sin cámara? Vincular con código de 6 letras'),
                ),
              ] else ...[
                Text(
                  'Escribe el código de 6 caracteres que aparece debajo del QR en la pantalla de tu PC:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  maxLength: 7,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'A7X-92B',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onSubmitted: _submitPairingCode,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                    ),
                    onPressed: () => _submitPairingCode(_codeController.text),
                    icon: const Icon(Icons.link),
                    label: const Text('Vincular PC ahora'),
                  ),
                ),
              ],

              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.expenseLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
