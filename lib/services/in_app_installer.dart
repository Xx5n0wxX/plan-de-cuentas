import 'in_app_installer_stub.dart'
    if (dart.library.io) 'in_app_installer_io.dart' as impl;

class InAppInstaller {
  static Future<void> downloadAndInstallApk({
    required String apkUrl,
    required void Function(double progress, int received, int total) onProgress,
  }) =>
      impl.downloadAndInstallApk(apkUrl: apkUrl, onProgress: onProgress);
}
