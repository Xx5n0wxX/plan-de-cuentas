import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';

Future<String> saveAndShareExcel({
  required List<int> bytes,
  required String filename,
}) async {
  final xfile = XFile.fromData(
    Uint8List.fromList(bytes),
    name: filename,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  await xfile.saveTo(filename);
  return filename;
}
