import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'google_drive_backup_service.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isGuest;
  final bool isLinkedDesktop;
  final String vaultId;
  final String? accessToken;
  final String? linkedDeviceId;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isGuest = false,
    this.isLinkedDesktop = false,
    String? vaultId,
    this.accessToken,
    this.linkedDeviceId,
  }) : vaultId = vaultId ?? uid;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isGuest,
    bool? isLinkedDesktop,
    String? vaultId,
    String? accessToken,
    String? linkedDeviceId,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isGuest: isGuest ?? this.isGuest,
      isLinkedDesktop: isLinkedDesktop ?? this.isLinkedDesktop,
      vaultId: vaultId ?? this.vaultId,
      accessToken: accessToken ?? this.accessToken,
      linkedDeviceId: linkedDeviceId ?? this.linkedDeviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'isGuest': isGuest,
        'isLinkedDesktop': isLinkedDesktop,
        'vaultId': vaultId,
        'accessToken': accessToken,
        'linkedDeviceId': linkedDeviceId,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        photoUrl: json['photoUrl'] as String?,
        isGuest: (json['isGuest'] as bool?) ?? false,
        isLinkedDesktop: (json['isLinkedDesktop'] as bool?) ?? false,
        vaultId: (json['vaultId'] as String?) ?? (json['uid'] as String),
        accessToken: json['accessToken'] as String?,
        linkedDeviceId: json['linkedDeviceId'] as String?,
      );
}

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      GoogleDriveBackupService.driveAppDataScope,
    ],
  );

  /// Obtiene o genera un vaultId local persistente para este dispositivo principal
  Future<String> getOrCreateLocalVaultId() async {
    final prefs = await SharedPreferences.getInstance();
    String? existing = prefs.getString('primary_vault_id');
    if (existing == null || existing.isEmpty) {
      existing = 'vault_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
      await prefs.setString('primary_vault_id', existing);
    }
    return existing;
  }

  /// Inicia sesión con Google (con alcance para Copia de Seguridad en Google Drive)
  Future<AppUser?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.addScope(GoogleDriveBackupService.driveAppDataScope);
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
        final user = userCredential.user;
        if (user == null) return null;

        String? accessToken;
        if (userCredential.credential is OAuthCredential) {
          accessToken = (userCredential.credential as OAuthCredential).accessToken;
        }

        final appUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ??
              (user.email != null ? user.email!.split('@').first : 'Usuario'),
          photoUrl: user.photoURL,
          isGuest: false,
          isLinkedDesktop: false,
          vaultId: user.uid,
          accessToken: accessToken,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('primary_vault_id', user.uid);
        await _persistUser(appUser);
        return appUser;
      }

      // En Android / Móvil
      try {
        final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
        if (googleAccount == null) {
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleAccount.authentication;
        String uid = googleAccount.id;

        try {
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final userCredential =
              await FirebaseAuth.instance.signInWithCredential(credential);
          if (userCredential.user != null) {
            uid = userCredential.user!.uid;
          }
        } catch (_) {}

        final appUser = AppUser(
          uid: uid,
          email: googleAccount.email,
          displayName:
              googleAccount.displayName ?? googleAccount.email.split('@').first,
          photoUrl: googleAccount.photoUrl,
          isGuest: false,
          isLinkedDesktop: false,
          vaultId: uid,
          accessToken: googleAuth.accessToken,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('primary_vault_id', uid);
        await _persistUser(appUser);
        return appUser;
      } catch (_) {
        // Respaldo mediante proveedor OAuth de Firebase en Android
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.addScope(GoogleDriveBackupService.driveAppDataScope);
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithProvider(googleProvider);
        final user = userCredential.user;
        if (user == null) return null;

        String? accessToken;
        if (userCredential.credential is OAuthCredential) {
          accessToken =
              (userCredential.credential as OAuthCredential).accessToken;
        }

        final appUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ??
              (user.email != null ? user.email!.split('@').first : 'Usuario'),
          photoUrl: user.photoURL,
          isGuest: false,
          isLinkedDesktop: false,
          vaultId: user.uid,
          accessToken: accessToken,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('primary_vault_id', user.uid);
        await _persistUser(appUser);
        return appUser;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Crea una sesión vinculada por QR (Estilo WhatsApp Desktop / Web)
  Future<AppUser> createLinkedDesktopSession({
    required String vaultId,
    required String ownerName,
    required String linkedDeviceId,
  }) async {
    String uid = 'desktop_$linkedDeviceId';
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      uid = FirebaseAuth.instance.currentUser?.uid ?? uid;
    } catch (_) {}

    final linkedUser = AppUser(
      uid: uid,
      email: 'Vinculado por QR con $ownerName',
      displayName: ownerName,
      isGuest: false,
      isLinkedDesktop: true,
      vaultId: vaultId,
      linkedDeviceId: linkedDeviceId,
    );
    await _persistUser(linkedUser);
    return linkedUser;
  }

  /// Cerrar sesión o desvincular dispositivo
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_user_session');
  }

  /// Modo invitado / Dispositivo principal sin cuenta de Google aún
  Future<AppUser> continueAsGuest() async {
    final vaultId = await getOrCreateLocalVaultId();
    String uid = 'guest_user';
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      uid = FirebaseAuth.instance.currentUser?.uid ?? uid;
    } catch (_) {}

    final guestUser = AppUser(
      uid: uid,
      email: 'Sin cuenta de Google Drive vinculada',
      displayName: 'Mi Teléfono / Principal',
      isGuest: true,
      isLinkedDesktop: false,
      vaultId: vaultId,
    );
    await _persistUser(guestUser);
    return guestUser;
  }

  /// Recupera la sesión guardada previamente
  Future<AppUser?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('app_user_session');
    if (jsonStr == null) return null;
    try {
      final user =
          AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(jsonStr)));
      final isDesktopPlatform = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux);
      if (isDesktopPlatform && !user.isLinkedDesktop) {
        // En escritorio solo se permite acceso mediante sesión vinculada por QR
        await prefs.remove('app_user_session');
        return null;
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> persistUser(AppUser user) => _persistUser(user);

  Future<void> _persistUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_user_session', jsonEncode(user.toJson()));
  }
}
