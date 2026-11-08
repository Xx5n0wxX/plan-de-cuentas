import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../services/app_update_service.dart';
import '../services/excel_export_service.dart';
import '../services/google_sheets_export_service.dart';

/// Modal para seleccionar el destino de exportación del Plan Financiero:
/// 1. Hoja de cálculo en línea de Google Sheets (En tu Google Drive)
/// 2. Archivo Excel local (.xlsx)
class ExportOptionsSheet extends StatefulWidget {
  const ExportOptionsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ExportOptionsSheet(),
    );
  }

  @override
  State<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<ExportOptionsSheet> {
  bool _isExportingSheets = false;
  bool _isExportingExcel = false;

  Future<void> _handleSheetsExport() async {
    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();

    setState(() => _isExportingSheets = true);

    try {
      final token =
          await auth.ensureGoogleDriveAccessToken(forGoogleSheets: true);
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Conecta primero tu cuenta de Google para exportar a Google Sheets.'),
          ),
        );
        return;
      }

      try {
        final result = await finance.exportToGoogleSheets(accessToken: token);

        if (!mounted) return;
        Navigator.of(context).pop(); // Cierra el bottom sheet
        showDialog(
          context: context,
          builder: (ctx) => GoogleSheetSuccessDialog(result: result),
        );
      } on GoogleSheetsPermissionException {
        if (mounted) {
          _promptGoogleDriveReauthorization();
        }
      }
    } catch (e) {
      if (mounted) {
        if (e is GoogleSheetsPermissionException) {
          _promptGoogleDriveReauthorization();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear hoja de cálculo: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingSheets = false);
      }
    }
  }

  Future<void> _promptGoogleDriveReauthorization() async {
    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF0F9D58)),
            SizedBox(width: 10),
            Expanded(child: Text('Permiso de Google Drive')),
          ],
        ),
        content: const Text(
          'Google requiere que autorices el permiso para que Plan de Cuentas cree la hoja de cálculo en tu Google Drive.\n\nPresiona "Autorizar" para conceder el acceso en la ventana de Google y generar tu planilla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F9D58),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isExportingSheets = true);
      try {
        final token = await auth.ensureGoogleDriveAccessToken(
          forGoogleSheets: true,
          forcePrompt: true,
        );
        if (token != null && token.isNotEmpty && mounted) {
          final result =
              await finance.exportToGoogleSheets(accessToken: token);
          if (mounted) {
            Navigator.of(context).pop(); // Cierra el bottom sheet
            showDialog(
              context: context,
              builder: (ctx) => GoogleSheetSuccessDialog(result: result),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo completar la autorización: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isExportingSheets = false);
      }
    }
  }

  Future<void> _handleExcelExport() async {
    final finance = context.read<FinanceProvider>();

    setState(() => _isExportingExcel = true);

    try {
      final path = await ExcelExportService.exportFullWorkbook(finance);
      if (!mounted) return;
      Navigator.of(context).pop(); // Cierra el bottom sheet
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✓ Planilla Excel guardada exitosamente ($path)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF107C41),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar planilla Excel: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingExcel = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.table_view_outlined,
                      color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exportar Plan Financiero',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '11 módulos completos organizados en pestañas',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // OPCIÓN 1: GOOGLE SHEETS (ONLINE / RECOMENDADO)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: (_isExportingSheets || _isExportingExcel)
                  ? null
                  : _handleSheetsExport,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D58).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0F9D58).withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F9D58),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.table_chart,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Google Sheets',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F9D58),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'En línea • Recomendado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Crea una hoja de cálculo viva en tu Google Drive. Podrás editarla desde cualquier navegador o celular, y compartirla fácilmente.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_isExportingSheets)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0F9D58),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Generando en Google Sheets...',
                                  style: TextStyle(
                                    color: Color(0xFF0F9D58),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Row(
                              children: [
                                Text(
                                  'Crear y abrir en Google Sheets',
                                  style: TextStyle(
                                    color: Color(0xFF0F9D58),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward,
                                    size: 14, color: Color(0xFF0F9D58)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // OPCIÓN 2: EXCEL (.XLSX) DESCARGA LOCAL
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: (_isExportingSheets || _isExportingExcel)
                  ? null
                  : _handleExcelExport,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF107C41),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.file_download_outlined,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Archivo Excel (.xlsx)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Sin conexión',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Descarga el archivo `.xlsx` estructurado directamente en la memoria de tu dispositivo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_isExportingExcel)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF107C41),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Descargando archivo Excel...',
                                  style: TextStyle(
                                    color: Color(0xFF107C41),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Text(
                                  'Descargar archivo .xlsx',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward,
                                    size: 14,
                                    color: theme.colorScheme.onSurface),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de éxito tras crear la hoja de cálculo en Google Sheets
class GoogleSheetSuccessDialog extends StatelessWidget {
  final GoogleSheetExportResult result;

  const GoogleSheetSuccessDialog({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F9D58).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.table_chart,
                color: Color(0xFF0F9D58), size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '¡Hoja de cálculo lista!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu plan de 11 módulos ha sido creado exitosamente como una hoja de cálculo en línea dentro de tu Google Drive.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description,
                        size: 16, color: Color(0xFF0F9D58)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        result.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: result.webViewLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Enlace copiado al portapapeles'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.webViewLink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text:
                    'Revisa mi Plan de Cuentas en Google Sheets:\n${result.webViewLink}',
                subject: result.name,
              ),
            );
          },
          icon: const Icon(Icons.share, size: 16),
          label: const Text('Compartir'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F9D58),
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            await AppUpdateService.openExternalUrl(result.webViewLink);
          },
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Abrir en Sheets'),
        ),
      ],
    );
  }
}
