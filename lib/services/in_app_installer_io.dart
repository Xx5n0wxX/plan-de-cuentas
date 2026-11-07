import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const MethodChannel _channel =
    MethodChannel('com.diegoplan.plan_de_cuentas/updater');

Future<void> downloadAndInstallApk({
  required String apkUrl,
  required void Function(double progress, int received, int total) onProgress,
}) async {
  final tempDir = await getTemporaryDirectory();
  final filePath = '${tempDir.path}/PlanDeCuentas_Update.apk';
  final file = File(filePath);
  if (file.existsSync()) {
    try {
      file.deleteSync();
    } catch (_) {}
  }

  final client = http.Client();
  final request = http.Request('GET', Uri.parse(apkUrl));
  final response = await client.send(request);
  final totalBytes = response.contentLength ?? 0;
  int receivedBytes = 0;

  final sink = file.openWrite();
  try {
    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress(receivedBytes / totalBytes, receivedBytes, totalBytes);
      }
    }
    await sink.flush();
  } finally {
    await sink.close();
    client.close();
  }

  await _channel.invokeMethod('installApk', {'filePath': file.path});
}
