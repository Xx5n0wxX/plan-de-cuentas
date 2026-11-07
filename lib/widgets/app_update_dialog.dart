import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/app_update_service.dart';
import '../services/in_app_installer.dart';
import '../theme/app_theme.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppVersionInfo remote;

  const AppUpdateDialog({super.key, required this.remote});

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _startDirectUpdate() async {
    if (!_isAndroid) {
      // En Windows / Web, abrir el enlace correspondiente
      await AppUpdateService.launchUpdateDownload(widget.remote);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
    });

    try {
      await InAppInstaller.downloadAndInstallApk(
        apkUrl: widget.remote.apkUrl,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'No se pudo completar la instalación directa: $e\nPuedes descargar la APK directamente desde el navegador.';
        });
      }
    }
  }

  Future<void> _downloadViaBrowser() async {
    await AppUpdateService.openExternalUrl(
        _isAndroid ? widget.remote.apkUrl : widget.remote.windowsExeUrl);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !widget.remote.forceUpdate && !_isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryTeal.withValues(alpha: 0.2)
                    : const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: AppTheme.primaryTeal, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.remote.forceUpdate
                        ? 'Actualización Obligatoria'
                        : 'Actualización Disponible',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Versión ${widget.remote.version}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.primaryTealDark
                          : AppTheme.primaryTeal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isDownloading) ...[
                Text(
                  widget.remote.forceUpdate
                      ? 'Hay una actualización crítica requerida para continuar usando la aplicación:'
                      : 'Novedades y mejoras incluidas en esta versión:',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.remote.changelog.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      widget.remote.changelog,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFF991B1B), fontSize: 12),
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFCCFBF1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.downloading_rounded,
                        color: AppTheme.primaryTeal, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _progress >= 0.99
                      ? 'Iniciando instalador de Android...'
                      : 'Descargando actualización directa...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _totalBytes > 0
                      ? '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB de ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB (${(_progress * 100).toInt()}%)'
                      : 'Conectando con el servidor...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _totalBytes > 0 ? _progress : null,
                    minHeight: 10,
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'La aplicación no saldrá al navegador. Al finalizar, confirma la instalación en la ventana del sistema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          if (!_isDownloading) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _startDirectUpdate,
              icon: Icon(_isAndroid ? Icons.bolt : Icons.download),
              label: Text(_isAndroid
                  ? 'Actualizar Directamente en la App'
                  : 'Actualizar Ahora'),
            ),
            OutlinedButton.icon(
              onPressed: _downloadViaBrowser,
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: Text(_isAndroid
                  ? 'Descargar APK completa en navegador'
                  : 'Descargar Instalador en navegador'),
            ),
            if (!widget.remote.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Más tarde'),
              ),
          ],
        ],
      ),
    );
  }
}
