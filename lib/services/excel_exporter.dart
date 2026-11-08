import 'excel_exporter_web.dart'
    if (dart.library.io) 'excel_exporter_io.dart' as impl;

class ExcelExporter {
  static Future<String> saveAndShare({
    required List<int> bytes,
    required String filename,
  }) =>
      impl.saveAndShareExcel(bytes: bytes, filename: filename);
}
