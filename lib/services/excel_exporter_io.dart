import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveAndShareExcel({
  required List<int> bytes,
  required String filename,
}) async {
  Directory dir;
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      dir = await getTemporaryDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
  } catch (_) {
    dir = Directory.systemTemp;
  }

  final filePath = '${dir.path}/$filename';
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  try {
    if (Platform.isAndroid || Platform.isIOS) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              filePath,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: filename,
            ),
          ],
          subject: 'Plan de Cuentas - Exportación Excel',
          text: 'Exportación completa de Plan de Cuentas: $filename',
        ),
      );
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              filePath,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: filename,
            ),
          ],
          subject: 'Plan de Cuentas - $filename',
        ),
      );
    }
  } catch (e) {
    debugPrint('SharePlus notice: $e');
  }

  return filePath;
}
