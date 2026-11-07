import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pairingCode = '';
  StreamSubscription<Map<String, dynamic>?>? _pairingSub;
  bool _isCheckingDriveBackup = false;

  @override
  void initState() {
    super.initState();
    _generateAndListenPairingCode();
  }

  @override
  void dispose() {
    _pairingSub?.cancel();
    super.dispose();
  }

  void _generateAndListenPairingCode() {
    _pairingSub?.cancel();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final code =
        List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();

    setState(() {
      _pairingCode = code;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final finance = context.read<FinanceProvider>();
      try {
        await finance.syncService.createPairingSession(
          code: code,
          desktopDeviceName: 'Plan de Cuentas Desktop / Web',
        );

        _pairingSub =
            finance.syncService.watchPairingSession(code).listen((data) async {
          if (data == null || !mounted) return;
          final status = data['status'] as String?;
          final vaultId = data['vaultId'] as String?;
          final ownerName =
              (data['ownerName'] as String?) ?? 'Mi Teléfono Principal';
          final linkedDeviceId =
              (data['linkedDeviceId'] as String?) ?? 'desktop_1';

          if (status == 'linked' && vaultId != null && vaultId.isNotEmpty) {
            _pairingSub?.cancel();
            final auth = context.read<AuthProvider>();
            await auth.completeQrDesktopPairing(
              vaultId: vaultId,
              ownerName: ownerName,
              linkedDeviceId: linkedDeviceId,
            );
            if (mounted) {
              await finance.startLiveSync(vaultId, isLinkedDesktop: true);
            }
          }
        }, onError: (_) {});
      } catch (_) {}
    });
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();

    final ok = await auth.signInWithGoogle();
    if (!ok || !mounted) return;

    final token = auth.accessToken;
    final vaultId = auth.vaultId;

    if (vaultId != null) {
      unawaited(finance.startLiveSync(vaultId));
    }

    // Estilo WhatsApp: al iniciar con Google, buscar si existe copia en Google Drive
    if (token != null && token.isNotEmpty) {
      setState(() => _isCheckingDriveBackup = true);
      try {
        final backupMeta = await finance.checkExistingDriveBackup(token);
        if (backupMeta != null && context.mounted) {
          final shouldRestore = await _showRestoreFromDriveDialog(
            context,
            modifiedTime: backupMeta.modifiedTime,
            sizeText: backupMeta.formattedSize,
            email: auth.user?.email ?? '',
          );
          if (shouldRestore == true && mounted) {
            await finance.restoreFromGoogleDrive(
              accessToken: token,
              fileId: backupMeta.fileId,
            );
          }
        }
      } catch (_) {
        // Si aún no tiene copia o Drive API está propagándose, continúa normal
      } finally {
        if (mounted) {
          setState(() => _isCheckingDriveBackup = false);
        }
      }
    }
  }

  Future<bool?> _showRestoreFromDriveDialog(
    BuildContext context, {
    required DateTime modifiedTime,
    required String sizeText,
    required String email,
  }) {
    final formattedDate =
        DateFormat("dd 'de' MMMM yyyy, HH:mm", 'es_CL').format(modifiedTime);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cloud_download, color: AppTheme.primaryTeal, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Se encontró una copia de seguridad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Existe un respaldo previo guardado en tu cuenta de Google Drive:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 Fecha: $formattedDate',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('📦 Tamaño: $sizeText'),
                  const SizedBox(height: 4),
                  Text('👤 Cuenta: $email',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¿Deseas restaurar todos tus módulos, cuentas y movimientos desde esta copia?',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Omitir'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final isWideScreen = isDesktopPlatform || screenWidth >= 760;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWideScreen ? 880 : 440),
            child: Card(
              elevation: isDark ? 0 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWideScreen ? 36 : 24,
                  vertical: isWideScreen ? 36 : 28,
                ),
                child: isWideScreen
                    ? _buildDesktopSplitLayout(context, auth, theme, isDark)
                    : _buildMobileAndCompactLayout(context, auth, theme, isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Diseño de Escritorio / Web idéntico a WhatsApp Desktop (Exclusivo con Código QR en vivo)
  Widget _buildDesktopSplitLayout(
    BuildContext context,
    AuthProvider auth,
    ThemeData theme,
    bool isDark,
  ) {
    final instructionsCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryTealDark.withValues(alpha: 0.15)
                    : const Color(0xFFCCFBF1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wallet,
                size: 30,
                color: isDark ? AppTheme.primaryTealDark : AppTheme.primaryTeal,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan de Cuentas',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Sincronización en vivo estilo WhatsApp Desktop',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Para vincular tu celular con esta pantalla:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildStepItem(
          number: '1',
          text: 'Abre Plan de Cuentas en tu teléfono.',
          theme: theme,
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          number: '2',
          text:
              'Ve a la pestaña Ajustes ⚙️ y entra en "Dispositivos vinculados".',
          theme: theme,
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          number: '3',
          text:
              'Toca "Vincular un dispositivo" y apunta tu cámara al código QR o escribe el código de 6 caracteres.',
          theme: theme,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primaryTeal.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline,
                  color: AppTheme.primaryTeal, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Modo Escritorio Protegido: El acceso en computadora se realiza exclusivamente vinculando el código QR desde la aplicación de tu teléfono.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              instructionsCol,
              const SizedBox(height: 24),
              _buildQrPairingCard(theme, isDark),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 6, child: instructionsCol),
            const SizedBox(width: 36),
            Expanded(flex: 5, child: _buildQrPairingCard(theme, isDark)),
          ],
        );
      },
    );
  }

  /// Diseño Móvil / Compacto
  Widget _buildMobileAndCompactLayout(
    BuildContext context,
    AuthProvider auth,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.primaryTealDark.withValues(alpha: 0.15)
                : const Color(0xFFCCFBF1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.wallet,
            size: 42,
            color: isDark ? AppTheme.primaryTealDark : AppTheme.primaryTeal,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Plan de Cuentas',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tu economía personal, libreta de fiado y préstamos con respaldo en Google Drive y Live Sync por QR.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildFeatureRow(
                icon: Icons.add_to_drive,
                text: 'Copia de seguridad automática en tu Google Drive',
                theme: theme,
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                icon: Icons.qr_code_scanner,
                text: 'Vincula tu PC con código QR igual que WhatsApp Web',
                theme: theme,
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                icon: Icons.widgets_outlined,
                text: '10 módulos personalizables sincronizados en tiempo real',
                theme: theme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (auth.errorMessage != null)
          _buildErrorBanner(auth.errorMessage!, isDark),
        _buildGoogleSignInButton(context, auth, isDark),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            auth.continueAsGuest();
          },
          child: Text(
            'Usar en modo local (sin cuenta)',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            '¿Quieres vincular esta pantalla escaneando un QR?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          children: [
            const SizedBox(height: 8),
            _buildQrPairingCard(theme, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildQrPairingCard(ThemeData theme, bool isDark) {
    final qrPayload = 'plancuentas://pair?code=$_pairingCode';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              size: 190,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Esperando escaneo desde tu celular...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key, size: 16, color: AppTheme.primaryTeal),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Código manual: ${_pairingCode.length == 6 ? '${_pairingCode.substring(0, 3)}-${_pairingCode.substring(3)}' : _pairingCode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _generateAndListenPairingCode,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.refresh, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String number,
    required String text,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppTheme.primaryTeal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              color: theme.colorScheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.expenseBgDark : AppTheme.expenseBgLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.expenseDark : AppTheme.expenseLight,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFFFECDD3) : AppTheme.expenseLight,
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
  ) {
    final isBusy = auth.isLoading || _isCheckingDriveBackup;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: BorderSide(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isBusy ? null : () => _handleGoogleSignIn(context),
        child: isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGoogleGLogo(),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Continuar con Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String text,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryTeal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleGLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -0.5,
      2.0,
      true,
      paint,
    );

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      1.5,
      1.5,
      true,
      paint,
    );

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      3.0,
      1.2,
      true,
      paint,
    );

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      4.2,
      1.6,
      true,
      paint,
    );

    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.32,
      paint,
    );

    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.45,
        size.height * 0.38,
        size.width * 0.55,
        size.height * 0.24,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
