import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const BiometricLockScreen({super.key, this.onUnlocked});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _showPinInput = false;
  String? _pinErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometricPrompt();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricPrompt() async {
    final bio = BiometricService.instance;
    if (!bio.isAppLocked) return;

    final success = await bio.authenticate(
      reason: 'Desbloquea Plan de Cuentas para acceder a tus finanzas',
    );
    if (success && mounted) {
      widget.onUnlocked?.call();
    }
  }

  void _verifyCustomPin() {
    final bio = BiometricService.instance;
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    if (bio.verifyCustomPin(pin)) {
      setState(() {
        _pinErrorMessage = null;
        _pinController.clear();
      });
      widget.onUnlocked?.call();
    } else {
      setState(() {
        _pinErrorMessage = 'PIN incorrecto. Intenta de nuevo.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    BiometricService? bioProvider;
    try {
      bioProvider = context.watch<BiometricService>();
    } catch (_) {}
    final bio = bioProvider ?? BiometricService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    AuthProvider? auth;
    try {
      auth = context.read<AuthProvider>();
    } catch (_) {}

    final backgroundColor =
        isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardColor =
        isDark ? const Color(0xFF1E293B) : Colors.white;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Shield Icon with teal aura
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isDark
                                  ? AppTheme.primaryTealDark
                                  : AppTheme.primaryTeal)
                              .withValues(alpha: 0.15),
                          border: Border.all(
                            color: (isDark
                                    ? AppTheme.primaryTealDark
                                    : AppTheme.primaryTeal)
                                .withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 46,
                          color: isDark
                              ? AppTheme.primaryTealDark
                              : AppTheme.primaryTeal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Plan de Cuentas',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Aplicación bloqueada por seguridad.\nVerifica tu identidad para continuar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 36),

                    if (!_showPinInput) ...[
                      // Biometric Unlock Button
                      FilledButton.icon(
                        onPressed: bio.isAuthenticating
                            ? null
                            : _triggerBiometricPrompt,
                        icon: bio.isAuthenticating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fingerprint, size: 26),
                        label: Text(
                          bio.isAuthenticating
                              ? 'Verificando...'
                              : 'Desbloquear con Huella',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark
                              ? AppTheme.primaryTealDark
                              : AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      if (bio.hasCustomPin) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showPinInput = true;
                              _pinErrorMessage = null;
                            });
                          },
                          icon: const Icon(Icons.pin_outlined),
                          label: const Text('Ingresar PIN de seguridad'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // In-App PIN Input Card
                      Card(
                        elevation: 0,
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Ingresa tu PIN de 4 dígitos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _pinController,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  letterSpacing: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '••••',
                                  errorText: _pinErrorMessage,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onSubmitted: (_) => _verifyCustomPin(),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _verifyCustomPin,
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppTheme.primaryTealDark
                                      : AppTheme.primaryTeal,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Verificar PIN'),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showPinInput = false;
                                    _pinErrorMessage = null;
                                  });
                                },
                                child: const Text('Volver a Biometría'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),

                    // Logout option in case user lost access
                    Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('¿Cerrar sesión?'),
                              content: const Text(
                                'Si cierras sesión deberás volver a ingresar con tu cuenta.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                  ),
                                  child: const Text('Cerrar sesión'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            bio.unlockApp();
                            if (auth != null) {
                              await auth.signOut();
                            }
                          }
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Cerrar sesión en esta app'),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.grey[400]
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
