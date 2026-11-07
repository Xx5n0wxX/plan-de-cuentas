import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _user;
  bool _isLoading = true;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isGuest => _user?.isGuest ?? false;
  bool get isLinkedDesktop => _user?.isLinkedDesktop ?? false;
  String? get vaultId => _user?.vaultId;
  String? get accessToken => _user?.accessToken;

  AuthProvider() {
    _initSession();
  }

  Future<void> _initSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.getSavedSession();
    } catch (_) {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('popup-closed-by-user') ||
          msg.contains('cancelled') ||
          msg.contains('canceled')) {
        _errorMessage = null;
      } else if (msg.contains('operation-not-allowed')) {
        _errorMessage =
            'Falta habilitar el proveedor Google en Firebase Console.';
      } else if (msg.contains('unauthorized-domain')) {
        _errorMessage =
            'El dominio no está autorizado en Firebase Console (agrega localhost / tu IP).';
      } else {
        _errorMessage = 'No se pudo conectar con Google: $msg';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtiene un token válido para Google Drive (solicitando login si es necesario)
  Future<String?> ensureGoogleDriveAccessToken() async {
    if (_user != null &&
        !_user!.isGuest &&
        _user!.accessToken != null &&
        _user!.accessToken!.isNotEmpty) {
      return _user!.accessToken;
    }
    final ok = await signInWithGoogle();
    if (!ok) return null;
    return _user?.accessToken;
  }

  /// Completa la vinculación en vivo cuando el teléfono escanea el QR de la PC
  Future<void> completeQrDesktopPairing({
    required String vaultId,
    required String ownerName,
    required String linkedDeviceId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _user = await _authService.createLinkedDesktopSession(
      vaultId: vaultId,
      ownerName: ownerName,
      linkedDeviceId: linkedDeviceId,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _user = await _authService.continueAsGuest();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();
    _user = null;
    _isLoading = false;
    notifyListeners();
  }
}
