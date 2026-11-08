import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService extends ChangeNotifier {
  static final BiometricService _instance = BiometricService._internal();
  static BiometricService get instance => _instance;

  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  static const String _keyBiometricEnabled = 'biometric_lock_enabled';
  static const String _keyLockOnBackground = 'biometric_lock_on_background';
  static const String _keyCustomPin = 'biometric_custom_pin';

  bool _isInitialized = false;
  bool _isDeviceSupported = false;
  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];

  bool _isLockEnabled = false;
  bool _lockOnBackground = true;
  String? _customPin;

  // In-memory lock state
  bool _isAppLocked = false;
  bool _isAuthenticating = false;

  // For unit testing overrides
  static bool? testDeviceSupported;
  static bool? testCanCheckBiometrics;
  static List<BiometricType>? testAvailableBiometrics;
  static bool? testAuthSuccess;

  bool get isInitialized => _isInitialized;
  bool get isDeviceSupported => testDeviceSupported ?? _isDeviceSupported;
  bool get canCheckBiometrics => testCanCheckBiometrics ?? _canCheckBiometrics;
  List<BiometricType> get availableBiometrics =>
      testAvailableBiometrics ?? _availableBiometrics;

  bool get isLockEnabled => _isLockEnabled;
  bool get lockOnBackground => _lockOnBackground;
  bool get isAppLocked => _isLockEnabled && _isAppLocked;
  bool get hasCustomPin => _customPin != null && _customPin!.isNotEmpty;
  bool get isAuthenticating => _isAuthenticating;

  bool get hasBiometricHardware =>
      isDeviceSupported && (canCheckBiometrics || availableBiometrics.isNotEmpty);

  String get biometricTypeDescription {
    if (availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID / Reconocimiento facial';
    }
    if (availableBiometrics.contains(BiometricType.fingerprint) ||
        availableBiometrics.contains(BiometricType.strong)) {
      return 'Huella dactilar';
    }
    if (availableBiometrics.contains(BiometricType.iris)) {
      return 'Reconocimiento de iris';
    }
    if (hasBiometricHardware) {
      return 'Biometría / Clave del sistema';
    }
    return 'PIN de seguridad de la app';
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isLockEnabled = prefs.getBool(_keyBiometricEnabled) ?? false;
      _lockOnBackground = prefs.getBool(_keyLockOnBackground) ?? true;
      _customPin = prefs.getString(_keyCustomPin);

      // Lock on initial launch if security is enabled
      if (_isLockEnabled) {
        _isAppLocked = true;
      }

      await checkBiometricsAvailable();
    } catch (e) {
      debugPrint('BiometricService init warning: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> checkBiometricsAvailable() async {
    if (kIsWeb) {
      _isDeviceSupported = false;
      _canCheckBiometrics = false;
      _availableBiometrics = [];
      return;
    }

    try {
      _isDeviceSupported = await _auth.isDeviceSupported();
      _canCheckBiometrics = await _auth.canCheckBiometrics;
      _availableBiometrics = await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Check biometrics error: $e');
      _isDeviceSupported = false;
      _canCheckBiometrics = false;
      _availableBiometrics = [];
    }
  }

  /// Attempts biometric or device authentication
  Future<bool> authenticate({
    String reason = 'Confirma tu identidad para acceder a Plan de Cuentas',
  }) async {
    if (testAuthSuccess != null) {
      if (testAuthSuccess!) {
        _isAppLocked = false;
        notifyListeners();
      }
      return testAuthSuccess!;
    }

    if (_isAuthenticating) return false;

    _isAuthenticating = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        // Web does not support native local_auth biometric prompts
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // Allows device PIN/Passcode fallback
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        _isAppLocked = false;
      }

      _isAuthenticating = false;
      notifyListeners();
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('Biometric authenticate PlatformException: ${e.message}');
      _isAuthenticating = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Biometric authenticate unexpected error: $e');
      _isAuthenticating = false;
      notifyListeners();
      return false;
    }
  }

  /// Changes the lock enabled state.
  /// If enabling, callers should first authenticate or have confirmed PIN.
  Future<void> setLockEnabled(bool enabled) async {
    _isLockEnabled = enabled;
    if (!enabled) {
      _isAppLocked = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    notifyListeners();
  }

  Future<void> setLockOnBackground(bool enabled) async {
    _lockOnBackground = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLockOnBackground, enabled);
    notifyListeners();
  }

  Future<void> setCustomPin(String? pin) async {
    _customPin = (pin != null && pin.trim().length >= 4) ? pin.trim() : null;
    final prefs = await SharedPreferences.getInstance();
    if (_customPin != null) {
      await prefs.setString(_keyCustomPin, _customPin!);
    } else {
      await prefs.remove(_keyCustomPin);
    }
    notifyListeners();
  }

  bool verifyCustomPin(String inputPin) {
    if (_customPin == null || _customPin!.isEmpty) return false;
    final matched = _customPin == inputPin.trim();
    if (matched) {
      _isAppLocked = false;
      notifyListeners();
    }
    return matched;
  }

  void lockApp() {
    if (_isLockEnabled && !_isAppLocked) {
      _isAppLocked = true;
      notifyListeners();
    }
  }

  void unlockApp() {
    if (_isAppLocked) {
      _isAppLocked = false;
      notifyListeners();
    }
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (!_isLockEnabled || !_lockOnBackground) return;

    if (state == AppLifecycleState.paused) {
      // Mark as locked when sent to background
      _isAppLocked = true;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      // Re-assert lock on resume
      if (!_isAppLocked) {
        _isAppLocked = true;
        notifyListeners();
      }
    }
  }
}
