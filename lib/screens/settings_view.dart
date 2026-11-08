import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/modular_models.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../services/app_update_service.dart';
import '../services/biometric_service.dart';
import '../services/excel_export_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/google_sheets_export_service.dart';
import '../services/local_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/export_options_dialog.dart';
import '../widgets/qr_scanner_dialog.dart';
import 'modular_views.dart';

class SettingsView extends StatefulWidget {
  final void Function(String route)? onNavigateToRoute;

  const SettingsView({super.key, this.onNavigateToRoute});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late bool _sharedEnabled;
  late TextEditingController _partnerNameCtrl;
  late double _myPercentage;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    final config = context.read<FinanceProvider>().sharedConfig;
    _sharedEnabled = config.isEnabled;
    _partnerNameCtrl = TextEditingController(text: config.partnerName);
    _myPercentage = config.myPercentage;
    LocalNotificationService.instance
        .isNotificationsEnabled()
        .then((val) {
      if (mounted) setState(() => _notificationsEnabled = val);
    });
  }

  @override
  void dispose() {
    _partnerNameCtrl.dispose();
    super.dispose();
  }

  void _saveConfig() {
    final provider = context.read<FinanceProvider>();
    final newConfig = provider.sharedConfig.copyWith(
      isEnabled: _sharedEnabled,
      partnerName: _partnerNameCtrl.text.trim().isEmpty
          ? 'Compañero/a'
          : _partnerNameCtrl.text.trim(),
      myPercentage: _myPercentage,
      partnerPercentage: 100 - _myPercentage,
    );
    provider.updateSharedConfig(newConfig);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Ajustes guardados correctamente')),
    );
  }

  bool _isExportingSheets = false;
  bool _isExportingExcel = false;

  Future<void> _handleExportGoogleSheets(
      BuildContext context, FinanceProvider provider) async {
    final auth = context.read<AuthProvider>();
    setState(() => _isExportingSheets = true);
    try {
      final token =
          await auth.ensureGoogleDriveAccessToken(forGoogleSheets: true);
      if (token == null || token.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Conecta primero tu cuenta de Google en la sección de perfil para exportar a Google Sheets.'),
            ),
          );
        }
        return;
      }
      try {
        final result = await provider.exportToGoogleSheets(accessToken: token);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => GoogleSheetSuccessDialog(result: result),
          );
        }
      } on GoogleSheetsPermissionException {
        if (context.mounted) {
          _promptGoogleDriveReauthorization(context, provider);
        }
      }
    } catch (e) {
      if (context.mounted) {
        if (e is GoogleSheetsPermissionException) {
          _promptGoogleDriveReauthorization(context, provider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear hoja de cálculo en Google Sheets: $e'),
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

  Future<void> _promptGoogleDriveReauthorization(
      BuildContext context, FinanceProvider provider) async {
    final auth = context.read<AuthProvider>();
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
          'Google requiere que autorices el permiso para que Plan de Cuentas cree y guarde la hoja de cálculo en tu Google Drive.\n\nPresiona "Autorizar" para conceder el acceso en la ventana de Google y generar tu planilla.',
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

    if (confirmed == true && context.mounted) {
      setState(() => _isExportingSheets = true);
      try {
        final token = await auth.ensureGoogleDriveAccessToken(
          forGoogleSheets: true,
          forcePrompt: true,
        );
        if (token != null && token.isNotEmpty && context.mounted) {
          final result =
              await provider.exportToGoogleSheets(accessToken: token);
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (ctx) => GoogleSheetSuccessDialog(result: result),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
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

  Future<void> _handleExportExcel(
      BuildContext context, FinanceProvider provider) async {
    setState(() => _isExportingExcel = true);
    try {
      final path = await ExcelExportService.exportFullWorkbook(provider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✓ Planilla Excel generada exitosamente ($path)',
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
      }
    } catch (e) {
      if (context.mounted) {
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

  Future<void> _toggleNotifications(
      bool value, FinanceProvider provider) async {
    if (value) {
      final granted =
          await LocalNotificationService.instance.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Por favor concede permisos de notificación en los ajustes de tu dispositivo.'),
          ),
        );
      }
    }
    await LocalNotificationService.instance.setNotificationsEnabled(value);
    setState(() => _notificationsEnabled = value);
    final count = await LocalNotificationService.instance
        .syncAndScheduleReminders(provider);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? '✓ Notificaciones activadas ($count alertas programadas)'
              : 'Notificaciones desactivadas'),
        ),
      );
    }
  }

  Future<void> _handleTestNotification() async {
    final granted =
        await LocalNotificationService.instance.requestPermissions();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Por favor permite notificaciones para recibir alertas.'),
        ),
      );
      return;
    }

    await LocalNotificationService.instance.showInstantNotification(
      id: 9999,
      title: '🔔 Notificación de Prueba: Plan de Cuentas',
      body:
          'Tus alertas de cuotas, suscripciones y tarjetas están configuradas y funcionando correctamente.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Notificación de prueba enviada al dispositivo'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    }
  }

  Future<void> _handleScheduleRemindersNow(FinanceProvider provider) async {
    final granted =
        await LocalNotificationService.instance.requestPermissions();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor permite notificaciones en el sistema.'),
        ),
      );
      return;
    }

    final count = await LocalNotificationService.instance
        .syncAndScheduleReminders(provider);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✓ Se programaron $count recordatorios de vencimiento en tu teléfono'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    }
  }

  Future<void> _handleDriveBackupNow(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();

    final token = await auth.ensureGoogleDriveAccessToken();
    if (token == null || token.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Conecta primero tu cuenta de Google para respaldar en Google Drive.'),
          ),
        );
      }
      return;
    }

    try {
      final meta = await finance.performGoogleDriveBackup(
        accessToken: token,
        vaultId: auth.vaultId ?? 'default_vault',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ Copia de seguridad guardada en Google Drive (${meta.formattedSize})'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar en Google Drive: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleDriveRestoreNow(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();

    final token = await auth.ensureGoogleDriveAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      final meta = await finance.checkExistingDriveBackup(token);
      if (meta == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No se encontró ninguna copia previa en tu Google Drive.'),
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;
      final formattedDate = DateFormat("dd/MM/yyyy HH:mm", 'es_CL')
          .format(meta.modifiedTime);

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restaurar desde Google Drive'),
          content: Text(
            'Se encontró una copia del $formattedDate (${meta.formattedSize}).\n\n¿Deseas restaurar todos tus módulos, cuentas y movimientos desde Google Drive?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar ahora'),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        await finance.restoreFromGoogleDrive(
          accessToken: token,
          fileId: meta.fileId,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('✓ Copia restaurada exitosamente desde Google Drive'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar desde Drive: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final bio = context.watch<BiometricService>();
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes y Configuración'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SECCIÓN: PERFIL Y CUENTA DE GOOGLE
            _buildSettingsGroupHeader(
              title: 'Cuenta de Google y Sincronización',
              icon: Icons.account_circle,
              color: AppTheme.primaryTeal,
            ),
            const SizedBox(height: 10),
            _buildProfileCard(context),
            const SizedBox(height: 12),
            _buildLinkedDevicesCard(context, provider),
            const SizedBox(height: 26),

            // 2. SECCIÓN: CATÁLOGO DE MÓDULOS (ARMA TU PLAN)
            _buildSettingsGroupHeader(
              title: 'Catálogo de Módulos (Arma tu Plan)',
              icon: Icons.widgets_outlined,
              color: AppTheme.primaryTeal,
            ),
            const SizedBox(height: 10),
            _buildModulesCatalogCard(context, provider),
            const SizedBox(height: 26),

            // 3. SECCIÓN: SEGURIDAD Y PRIVACIDAD
            _buildSettingsGroupHeader(
              title: 'Seguridad y Privacidad',
              icon: Icons.security,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 10),
            _buildBiometricCard(context, bio),
            const SizedBox(height: 26),

            // 3. SECCIÓN: NUBE Y EXPORTACIÓN DE DATOS
            _buildSettingsGroupHeader(
              title: 'Nube, Respaldos y Exportación',
              icon: Icons.cloud_sync,
              color: Colors.blue.shade700,
            ),
            const SizedBox(height: 10),
            _buildGoogleDriveBackupCard(context, provider),
            const SizedBox(height: 12),
            _buildExportCard(context, provider),
            const SizedBox(height: 26),

            // 4. SECCIÓN: PREFERENCIAS Y APARIENCIA
            _buildSettingsGroupHeader(
              title: 'Preferencias y Apariencia',
              icon: Icons.palette,
              color: Colors.purple,
            ),
            const SizedBox(height: 10),
            _buildNotificationsCard(context, provider),
            const SizedBox(height: 12),
            _buildAppearanceCard(context, provider),
            const SizedBox(height: 26),

            // 5. SECCIÓN: CONFIGURACIÓN DE PAREJA
            if (provider.isModuleActive(AppModuleId.sharedExpenses) || _sharedEnabled) ...[
              _buildSettingsGroupHeader(
                title: 'Finanzas en Pareja (Gastos Compartidos)',
                icon: Icons.favorite,
                color: Colors.pink,
              ),
              const SizedBox(height: 10),
              _buildSharedExpensesConfigCard(context),
              const SizedBox(height: 26),
            ],

            // 6. SECCIÓN: SISTEMA Y MANTENIMIENTO
            _buildSettingsGroupHeader(
              title: 'Sistema y Mantenimiento',
              icon: Icons.tune,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 10),
            _buildOtaUpdateCard(context),
            const SizedBox(height: 12),
            _buildResetDataCard(context, provider),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroupHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
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
      ],
    );
  }

  Widget _buildAppearanceCard(BuildContext context, FinanceProvider provider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tema visual',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Claro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Oscuro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Sistema'),
                  ),
                ],
                selected: {provider.themeMode},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  provider.setThemeMode(newSelection.first);
                },
              ),
            ),
            const Divider(height: 28),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Modo Privacidad (Ocultar Saldos)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Oculta los montos y balances con "\$ ••••••" en todas las vistas de la aplicación.',
                style: TextStyle(fontSize: 13),
              ),
              secondary: Icon(
                provider.isPrivacyMode ? Icons.visibility_off : Icons.visibility,
                color: provider.isPrivacyMode ? Colors.amber.shade700 : null,
              ),
              value: provider.isPrivacyMode,
              onChanged: (_) => provider.togglePrivacyMode(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedExpensesConfigCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Habilitar Gastos Compartidos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_sharedEnabled
                  ? 'Módulo activo'
                  : 'Desactivado (modo individual)'),
              value: _sharedEnabled,
              onChanged: (val) {
                setState(() => _sharedEnabled = val);
                _saveConfig();
              },
            ),
            if (_sharedEnabled) ...[
              const Divider(),
              const SizedBox(height: 10),
              TextField(
                controller: _partnerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la pareja o compañero/a',
                  hintText: 'Ej: Erika, Roommate...',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _saveConfig(),
              ),
              const SizedBox(height: 16),
              Text(
                'División de Gastos: Tu aporte ${_myPercentage.toInt()}% / Aporte de ${_partnerNameCtrl.text} ${(100 - _myPercentage).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _myPercentage,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${_myPercentage.toInt()}%',
                onChanged: (val) {
                  setState(() => _myPercentage = val);
                  _saveConfig();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOtaUpdateCard(BuildContext context) {
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
                const Text(
                  'Versión instalada:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 14, color: AppTheme.primaryTeal),
                      SizedBox(width: 4),
                      Text(
                        'v${AppUpdateService.currentVersion} • Actualizaciones 1-Toque',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final remote = await AppUpdateService.checkRemoteVersion();
                  if (!context.mounted) return;
                  if (remote == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo conectar al servidor de actualizaciones.'),
                      ),
                    );
                    return;
                  }
                  if (AppUpdateService.isUpdateAvailable(remote)) {
                    showDialog(
                      context: context,
                      builder: (_) => AppUpdateDialog(remote: remote),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Ya tienes la última versión (v${remote.version}).'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.system_update),
                label: const Text('Buscar e Instalar Actualización'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetDataCard(BuildContext context, FinanceProvider provider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Restablecer Datos de la Aplicación',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Borra todos los registros actuales y deja todos los módulos completamente en 0.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Dejar la aplicación desde 0'),
                    content: const Text(
                      '¿Confirmas que deseas borrar todos los registros actuales y dejar todos los módulos en 0?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          provider.clearAllDataToZero();
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✓ Aplicación reiniciada en 0')),
                          );
                        },
                        child: const Text('Sí, dejar en 0'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Reiniciar Todo en 0'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedDevicesCard(
      BuildContext context, FinanceProvider provider) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.devices, color: AppTheme.primaryTeal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.isLinkedDesktop
                            ? 'Sesión de Escritorio Vinculada por QR'
                            : 'Usa Plan de Cuentas en otros dispositivos',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Sincronización en vivo instantánea entre tu celular y tu PC.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final linked = await showDialog<bool>(
                    context: context,
                    builder: (_) => const QrScannerDialog(),
                  );
                  if (linked == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '✓ ¡Dispositivo vinculado! Live Sync activado en tiempo real.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Vincular un dispositivo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'ESTADO DE DISPOSITIVOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<LinkedDeviceModel>>(
              stream: provider.syncService.getLinkedDevicesStream(),
              builder: (context, snapshot) {
                final devices = snapshot.data ?? [];
                if (devices.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.laptop_windows_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No hay computadoras vinculadas en este momento.',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: devices.map((dev) {
                    final dateStr = DateFormat('dd/MM HH:mm', 'es_CL')
                        .format(dev.linkedAt);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFD1FAE5),
                        child: Icon(Icons.desktop_windows,
                            color: Color(0xFF047857), size: 20),
                      ),
                      title: Text(
                        dev.deviceName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '🟢 Activo en Live Sync • Vinculado el $dateStr',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await provider.syncService
                              .revokeLinkedDevice(dev.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Sesión de PC cerrada remotamente.'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Cerrar sesión',
                          style: TextStyle(color: AppTheme.expenseLight),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleDriveBackupCard(
      BuildContext context, FinanceProvider provider) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    final localTimeStr = provider.lastLocalSaveTime != null
        ? DateFormat('dd/MM/yyyy HH:mm', 'es_CL')
            .format(provider.lastLocalSaveTime!)
        : 'Hoy';
    final driveTimeStr = provider.lastDriveBackupTime != null
        ? DateFormat('dd/MM/yyyy HH:mm', 'es_CL')
            .format(provider.lastDriveBackupTime!)
        : 'Nunca';
    final driveSizeStr = provider.lastDriveBackupSize ?? 'Sin copia aún';
    final googleEmail = (!auth.isGuest && auth.user != null)
        ? auth.user!.email
        : 'Sin cuenta vinculada (toca Guardar para conectar)';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_upload_outlined,
                      color: Color(0xFF059669)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Última copia de seguridad',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text('📱 Local: $localTimeStr',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('☁️ Google Drive: $driveTimeStr',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('📦 Tamaño: $driveSizeStr',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            if (provider.isBackingUpDrive) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: provider.driveBackupProgress,
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sincronizando copia de seguridad con tu Google Drive...',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: provider.isBackingUpDrive
                        ? null
                        : () => _handleDriveBackupNow(context),
                    icon: const Icon(Icons.backup, size: 18),
                    label: const Text(
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: provider.isBackingUpDrive
                        ? null
                        : () => _handleDriveRestoreNow(context),
                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('Restaurar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Cuenta de Google Drive',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle:
                  Text(googleEmail, style: const TextStyle(fontSize: 12)),
              trailing: TextButton(
                onPressed: () => auth.signInWithGoogle(),
                child: Text(auth.isGuest ? 'Conectar' : 'Cambiar'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Guardar en Google Drive',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(provider.backupFrequency,
                  style: const TextStyle(fontSize: 12)),
              trailing: DropdownButton<String>(
                value: provider.backupFrequency,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: 'Solo cuando toco Guardar',
                    child: Text('Al tocar Guardar',
                        style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 'Diariamente',
                    child:
                        Text('Diariamente', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 'Semanalmente',
                    child:
                        Text('Semanalmente', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 'Tras cada pago importante',
                    child: Text('Tras cada pago',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.setBackupFrequency(val);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard(BuildContext context, FinanceProvider provider) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart,
                      color: Color(0xFF0F9D58), size: 28),
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
                              'Hoja de Cálculo y Excel',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
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
                              '11 Módulos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Genera una hoja online en Google Sheets o un archivo .xlsx local.',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ExcelFeatureChip(label: 'Resumen General'),
                _ExcelFeatureChip(label: 'Movimientos'),
                _ExcelFeatureChip(label: 'Libretas'),
                _ExcelFeatureChip(label: 'Préstamos'),
                _ExcelFeatureChip(label: 'Gastos Compartidos'),
                _ExcelFeatureChip(label: 'Cuentas por Cobrar'),
                _ExcelFeatureChip(label: 'Ahorros'),
                _ExcelFeatureChip(label: 'Suscripciones'),
                _ExcelFeatureChip(label: 'Presupuestos'),
                _ExcelFeatureChip(label: 'Tarjetas'),
                _ExcelFeatureChip(label: 'Lista de Compras'),
              ],
            ),
            const SizedBox(height: 16),
            // BOTÓN PRINCIPAL: GOOGLE SHEETS
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D58),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_isExportingSheets || _isExportingExcel)
                    ? null
                    : () => _handleExportGoogleSheets(context, provider),
                icon: _isExportingSheets
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.table_chart, size: 20),
                label: Text(
                  _isExportingSheets
                      ? 'Creando en Google Sheets...'
                      : 'Crear en Google Sheets (En línea)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // BOTÓN SECUNDARIO: EXCEL (.XLSX)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF107C41),
                  side: const BorderSide(color: Color(0xFF107C41), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_isExportingSheets || _isExportingExcel)
                    ? null
                    : () => _handleExportExcel(context, provider),
                icon: _isExportingExcel
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF107C41)),
                        ),
                      )
                    : const Icon(Icons.file_download_outlined, size: 20),
                label: Text(
                  _isExportingExcel
                      ? 'Generando Archivo Excel...'
                      : 'Descargar Archivo Excel (.xlsx)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard(
      BuildContext context, FinanceProvider provider) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Activar Recordatorios de Vencimientos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Recibe notificaciones automáticas para cuotas de créditos, cobro de suscripciones y facturación de tarjetas.',
                style: TextStyle(fontSize: 12),
              ),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _notificationsEnabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: Colors.amber.shade800,
                ),
              ),
              value: _notificationsEnabled,
              onChanged: (val) => _toggleNotifications(val, provider),
            ),
            const Divider(height: 24),
            const Text(
              'Alertas que recibirás en tu teléfono:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildNotificationFeatureItem(
              theme: theme,
              icon: Icons.handshake_outlined,
              color: const Color(0xFF7C3AED),
              title: 'Préstamos y Créditos',
              desc:
                  'Alerta el día de vencimiento y 1 día antes con monto y cuota.',
            ),
            const SizedBox(height: 6),
            _buildNotificationFeatureItem(
              theme: theme,
              icon: Icons.autorenew_outlined,
              color: const Color(0xFFEC4899),
              title: 'Suscripciones y Membresías',
              desc: 'Recordatorio el día del cobro mensual recurrente.',
            ),
            const SizedBox(height: 6),
            _buildNotificationFeatureItem(
              theme: theme,
              icon: Icons.credit_card_outlined,
              color: const Color(0xFF4F46E5),
              title: 'Tarjetas de Crédito',
              desc: 'Aviso en la fecha de corte y en el día límite de pago.',
            ),
            const SizedBox(height: 6),
            _buildNotificationFeatureItem(
              theme: theme,
              icon: Icons.call_received_outlined,
              color: const Color(0xFF059669),
              title: 'Cuentas por Cobrar',
              desc:
                  'Notificación cuando se cumple el plazo acordado con un deudor.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _notificationsEnabled
                      ? () => _handleScheduleRemindersNow(provider)
                      : null,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Programar Alertas Ahora'),
                ),
                OutlinedButton.icon(
                  onPressed: _handleTestNotification,
                  icon: const Icon(Icons.notification_important_outlined,
                      size: 18),
                  label: const Text('Probar Notificación'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationFeatureItem({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleBiometricLock(bool enable, BiometricService bio) async {
    if (enable) {
      if (!bio.hasBiometricHardware && !bio.hasCustomPin) {
        final pinSet = await _showSetPinDialog(context, bio);
        if (!pinSet) return;
      } else if (bio.hasBiometricHardware) {
        final ok = await bio.authenticate(
          reason: 'Confirma tu huella o biometría para activar la protección',
        );
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo verificar la identidad biométrica.'),
              ),
            );
          }
          return;
        }
      }
      await bio.setLockEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Bloqueo de seguridad activado'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } else {
      bool verified = false;
      if (bio.hasBiometricHardware) {
        verified = await bio.authenticate(
          reason: 'Confirma tu identidad para desactivar el bloqueo',
        );
      } else if (bio.hasCustomPin) {
        verified = await _promptPinConfirmation(context, bio);
      } else {
        verified = true;
      }

      if (verified) {
        await bio.setLockEnabled(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bloqueo de seguridad desactivado')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo desactivar: identidad no verificada.'),
          ),
        );
      }
    }
  }

  Future<bool> _showSetPinDialog(
      BuildContext context, BiometricService bio) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(bio.hasCustomPin
              ? 'Modificar PIN de Respaldo'
              : 'Configurar PIN de Respaldo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa un PIN numérico de 4 a 6 dígitos para desbloquear la app si tu huella o cámara fallan.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Nuevo PIN',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Confirmar PIN',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (bio.hasCustomPin)
              TextButton(
                onPressed: () async {
                  await bio.setCustomPin(null);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Eliminar PIN'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final p = pinCtrl.text.trim();
                final c = confirmCtrl.text.trim();
                if (p.length < 4) {
                  setDialogState(() {
                    errorText = 'El PIN debe tener al menos 4 dígitos';
                  });
                  return;
                }
                if (p != c) {
                  setDialogState(() {
                    errorText = 'Los PIN ingresados no coinciden';
                  });
                  return;
                }
                await bio.setCustomPin(p);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar PIN'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  Future<bool> _promptPinConfirmation(
      BuildContext context, BiometricService bio) async {
    final pinCtrl = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirmar PIN de Seguridad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresa tu PIN actual para confirmar la acción:'),
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'PIN de seguridad',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (bio.verifyCustomPin(pinCtrl.text.trim())) {
                  Navigator.pop(ctx, true);
                } else {
                  setDialogState(() {
                    errorText = 'PIN incorrecto';
                  });
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  Widget _buildBiometricCard(BuildContext context, BiometricService bio) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Bloqueo con Huella / Biometría',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                bio.hasBiometricHardware
                    ? 'Requiere ${bio.biometricTypeDescription} para abrir la aplicación y consultar tus saldos.'
                    : 'Protege la aplicación usando un PIN numérico de seguridad.',
                style: const TextStyle(fontSize: 12),
              ),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppTheme.primaryTealDark
                          : AppTheme.primaryTeal)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint,
                  color: isDark
                      ? AppTheme.primaryTealDark
                      : AppTheme.primaryTeal,
                ),
              ),
              value: bio.isLockEnabled,
              onChanged: (val) => _toggleBiometricLock(val, bio),
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Bloquear al cambiar o salir de la app',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Si minimizas la app o cambias a otra tarea, volverá a solicitar autenticación de inmediato.',
                style: TextStyle(fontSize: 12),
              ),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phonelink_lock,
                  color: Colors.blueGrey,
                ),
              ),
              value: bio.lockOnBackground,
              onChanged: bio.isLockEnabled
                  ? (val) => bio.setLockOnBackground(val)
                  : null,
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pin_outlined,
                  color: Colors.indigo,
                ),
              ),
              title: Text(
                bio.hasCustomPin
                    ? 'PIN de respaldo configurado (••••)'
                    : 'PIN de respaldo alternativo',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Desbloquea la aplicación con 4 dígitos si el sensor de huellas no responde.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: OutlinedButton(
                onPressed: () => _showSetPinDialog(context, bio),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(bio.hasCustomPin ? 'Modificar' : 'Crear PIN'),
              ),
            ),
            if (bio.isLockEnabled) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    bio.lockApp();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('App bloqueada por seguridad'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Probar Bloqueo Ahora'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModulesCatalogCard(
      BuildContext context, FinanceProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeCount = provider.activeModules.length + 1;
    final totalCount = AppModuleMeta.catalog.length + 1;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.widgets_outlined,
                    color: AppTheme.primaryTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Personalizar Módulos Activos',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$activeCount / $totalCount activos',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Activa o desactiva préstamos, libretas de fiado, tarjetas, metas y presupuestos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (widget.onNavigateToRoute != null) {
                    widget.onNavigateToRoute!('modules_hub');
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Catálogo de Módulos'),
                          ),
                          body: const ModulesHubView(),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Abrir Catálogo de Módulos (Arma tu Plan)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGuest = auth.isGuest || auth.user == null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isGuest
                      ? (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0))
                      : (isDark
                          ? AppTheme.primaryTealDark.withValues(alpha: 0.25)
                          : const Color(0xFFCCFBF1)),
                  backgroundImage: (!isGuest && auth.user?.photoUrl != null)
                      ? NetworkImage(auth.user!.photoUrl!)
                      : null,
                  child: (isGuest || auth.user?.photoUrl == null)
                      ? Icon(
                          isGuest
                              ? Icons.phone_android
                              : Icons.account_circle,
                          size: 26,
                          color: isGuest
                              ? theme.colorScheme.onSurfaceVariant
                              : (isDark
                                  ? AppTheme.primaryTealDark
                                  : AppTheme.primaryTeal),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuest
                            ? 'Modo Dispositivo Local'
                            : (auth.user?.displayName ?? 'Usuario de Google'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.user?.email ?? '',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark
                        ? const Color(0xFF064E3B)
                        : const Color(0xFFECFDF5)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.isLinkedDesktop ? 'Vinculado QR' : 'Live Sync Activo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: isGuest
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.primaryTealDark
                            : AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await auth.signInWithGoogle();
                      },
                      icon: const Icon(Icons.add_to_drive),
                      label:
                          const Text('Conectar Google Drive'),
                    )
                  : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? AppTheme.expenseDark
                            : AppTheme.expenseLight,
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.expenseDark
                              : AppTheme.expenseLight,
                        ),
                      ),
                      onPressed: () async {
                        context.read<FinanceProvider>().stopLiveSync();
                        await auth.signOut();
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(auth.isLinkedDesktop
                          ? 'Desvincular este equipo'
                          : 'Cerrar Sesión'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExcelFeatureChip extends StatelessWidget {
  final String label;

  const _ExcelFeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
