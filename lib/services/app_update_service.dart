import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AppVersionInfo {
  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final String changelog;
  final String apkUrl;
  final String windowsExeUrl;

  AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.forceUpdate,
    required this.changelog,
    required this.apkUrl,
    required this.windowsExeUrl,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      version: (json['version'] as String?) ?? '2.1.0',
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 210,
      forceUpdate: (json['forceUpdate'] as bool?) ?? false,
      changelog: (json['changelog'] as String?) ?? '',
      apkUrl: (json['apkUrl'] as String?) ??
          'https://github.com/Xx5n0wxX/plan-de-cuentas/releases/latest/download/PlanDeCuentas_Android.apk',
      windowsExeUrl: (json['windowsExeUrl'] as String?) ??
          'https://github.com/Xx5n0wxX/plan-de-cuentas/releases/latest/download/PlanDeCuentas_Setup.exe',
    );
  }
}

class AppUpdateService {
  static const String currentVersion = '2.4.2';
  static const int currentBuildNumber = 241;
  static const String versionJsonUrl =
      'https://plan-de-cuentas-45670.web.app/version.json';

  static const MethodChannel _channel =
      MethodChannel('com.diegoplan.plan_de_cuentas/updater');

  static Future<AppVersionInfo?> checkRemoteVersion() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$versionJsonUrl?t=$ts');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data =
            Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
        return AppVersionInfo.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  static bool isUpdateAvailable(AppVersionInfo remote) {
    return remote.buildNumber > currentBuildNumber;
  }

  static Future<void> launchUpdateDownload(AppVersionInfo remote) async {
    final targetUrl = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? remote.apkUrl
        : remote.windowsExeUrl;
    await openExternalUrl(targetUrl);
  }

  static Future<void> openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('openUrl', {'url': url});
        return;
      } catch (_) {}
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
