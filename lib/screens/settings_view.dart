import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../services/app_update_service.dart';
import '../services/firebase_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_scanner_dialog.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late bool _sharedEnabled;
  late TextEditingController _partnerNameCtrl;
  late double _myPercentage;

  @override
  void initState() {
    super.initState();
    final config = context.read<FinanceProvider>().sharedConfig;
    _sharedEnabled = config.isEnabled;
    _partnerNameCtrl = TextEditingController(text: config.partnerName);
    _myPercentage = config.myPercentage;
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
            // 1. SECCIÓN: DISPOSITIVOS VINCULADOS (ESTILO WHATSAPP WEB / DESKTOP)
            const Text(
              'Dispositivos vinculados (Live Sync QR)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Vincula Plan de Cuentas con tu PC escaneando el código QR, igual que en WhatsApp.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildLinkedDevicesCard(context, provider),
            const SizedBox(height: 28),

            // 2. SECCIÓN: COPIA DE SEGURIDAD EN GOOGLE DRIVE (ESTILO WHATSAPP)
            const Text(
              'Copia de seguridad en Google Drive',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Guarda tus cuentas, libreta de fiado y préstamos en el espacio seguro de tu Google Drive para restaurarlos si cambias de teléfono.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildGoogleDriveBackupCard(context, provider),
            const SizedBox(height: 28),

            // 3. SECCIÓN: PERFIL Y CUENTA DE GOOGLE
            const Text(
              'Cuenta de Google Vinculada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildProfileCard(context),
            const SizedBox(height: 28),

            // 3.5 SECCIÓN: ACTUALIZACIONES INTEGRADAS (OTA)
            const Text(
              'Actualizaciones de la Aplicación (OTA)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Comprueba e instala nuevas versiones directamente desde la aplicación sin desinstalar.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'v${AppUpdateService.currentVersion} (Build ${AppUpdateService.currentBuildNumber})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.primaryTeal,
                            ),
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
                          final remote =
                              await AppUpdateService.checkRemoteVersion();
                          if (!context.mounted) return;
                          if (remote == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'No se pudo conectar al servidor de actualizaciones.'),
                              ),
                            );
                            return;
                          }
                          if (AppUpdateService.isUpdateAvailable(remote)) {
                            await AppUpdateService.launchUpdateDownload(remote);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '✓ Ya tienes la última versión (v${remote.version}).'),
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
            ),
            const SizedBox(height: 28),

            // 4. SECCIÓN: APARIENCIA Y TEMA
            const Text(
              'Apariencia de la Aplicación',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Elige el tema que mejor se adapte a tu comodidad visual.',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tema de color',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 5. SECCIÓN: GASTOS COMPARTIDOS (MODULAR)
            const Text(
              'Módulo de Gastos Compartidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Actívalo solo si en algún momento compartes arriendo, compras o salidas con otra persona.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                          labelText: 'Nombre de la persona o entidad',
                          hintText: 'Ej: Roommate, Hermano, Amigo...',
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
            ),
            const SizedBox(height: 28),

            // 6. SECCIÓN: REINICIAR DATOS EN CERO
            const Text(
              'Restablecer Datos de la App',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Si deseas empezar un nuevo período o limpiar todos los registros para dejar la aplicación completamente en 0:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title:
                                const Text('Dejar la aplicación desde 0'),
                            content: const Text(
                              '¿Confirmas que deseas borrar todos los registros actuales y dejar todos los módulos en 0?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  provider.clearAllDataToZero();
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            '✓ Aplicación reiniciada en 0')),
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
