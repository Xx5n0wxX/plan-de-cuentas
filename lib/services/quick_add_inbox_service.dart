import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Acciones rápidas que puede despachar el widget nativo (QuickAdd).
///
/// Flujo:
///  1. El usuario toca el widget → se abre el overlay nativo.
///  2. El overlay escribe `pending_quick_add.json` en el directorio interno
///     de la app (el mismo directorio que expone `getApplicationDocumentsDirectory()`).
///  3. Al arrancar la app, Flutter lee y aplica las entradas pendientes.
///  4. El archivo se borra una vez aplicadas.
///
/// Así el overlay nunca necesita conocer reglas de negocio: sólo coleta el
/// dato y lo deja para que Flutter aplique sus reglas (sync, validaciones,
/// persistencia, etc.).
class QuickAddInboxService {
  const QuickAddInboxService._();

  static const String _pendingFileName = 'pending_quick_add.json';
  static const String _metaFileName = 'quick_add_meta.json';
  static const String _widgetDataFileName = 'widget_financial_data.json';
  static const int _expectedVersion = 1;
  static const MethodChannel _updaterChannel =
      MethodChannel('com.diegoplan.plan_de_cuentas/updater');

  /// Obtiene los directorios candidatos donde se comparten datos entre Kotlin y Flutter
  /// (en Android: filesDir = getApplicationSupportDirectory, y getApplicationDocumentsDirectory).
  static Future<List<Directory>> _targetDirs() async {
    final dirs = <Directory>[];
    try {
      dirs.add(await getApplicationSupportDirectory());
    } catch (_) {}
    try {
      dirs.add(await getApplicationDocumentsDirectory());
    } catch (_) {}
    return dirs;
  }

  /// Lee las entradas pendientes. Si hay cualquier problema de formato o
  /// lectura devuelve una lista vacía. Nunca lanza excepción (seguro en
  /// entornos headless como unit tests sin path_provider).
  static Future<List<QuickAddEntry>> readPending() async {
    try {
      final dirs = await _targetDirs();
      final allEntries = <QuickAddEntry>[];
      final seenQueued = <dynamic>{};

      for (final dir in dirs) {
        final file = File('${dir.path}/$_pendingFileName');
        if (!await file.exists()) continue;
        final raw = await file.readAsString();
        if (raw.trim().isEmpty) continue;
        final decoded = jsonDecode(raw);
        final entries = _decodeEntries(decoded);
        for (final entry in entries) {
          final q = entry.fields['queuedAt'];
          if (q != null && !seenQueued.add(q)) continue;
          allEntries.add(entry);
        }
      }
      return allEntries;
    } catch (e) {
      debugPrint('QuickAdd: lectura de $_pendingFileName ignorada: $e');
      return [];
    }
  }

  /// Borra el archivo de pendientes (invocado tras aplicar las entradas).
  static Future<void> clearPending() async {
    try {
      final dirs = await _targetDirs();
      for (final dir in dirs) {
        final file = File('${dir.path}/$_pendingFileName');
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('QuickAdd: no se pudo borrar $_pendingFileName: $e');
    }
  }

  /// Escribe el snapshot de metadatos usado por el overlay nativo para
  /// mostrar selectores (tarjetas de crédito, metas y categorías de gasto
  /// hormiga). Si hay cualquier error, el overlay verá una lista vacía y
  /// pedirá abrir la app primero. Nunca lanza excepción.
  static Future<void> writeMeta(Map<String, dynamic> meta) async {
    try {
      final dirs = await _targetDirs();
      final payload = jsonEncode({
        'version': _expectedVersion,
        'cards': meta['cards'] ?? const [],
        'goals': meta['goals'] ?? const [],
        'antCategories': meta['antCategories'] ?? const [],
      });
      for (final dir in dirs) {
        final file = File('${dir.path}/$_metaFileName');
        await file.writeAsString(payload);
      }
    } catch (e) {
      debugPrint('QuickAdd meta: no se pudo escribir $_metaFileName: $e');
    }
  }

  /// Escribe el snapshot financiero consumido por el widget de inicio de Android
  /// y notifica al AppWidgetProvider mediante MethodChannel para actualizar la vista.
  static Future<void> writeWidgetFinancialData({
    required String monthName,
    required String balance,
    required String income,
    required String expenses,
    required bool isDeficit,
    required String shoppingBadge,
  }) async {
    if (kIsWeb) return;
    try {
      final dirs = await _targetDirs();
      final payload = jsonEncode({
        'monthName': monthName,
        'balance': balance,
        'income': income,
        'expenses': expenses,
        'isDeficit': isDeficit,
        'shoppingBadge': shoppingBadge,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      for (final dir in dirs) {
        final file = File('${dir.path}/$_widgetDataFileName');
        await file.writeAsString(payload);
      }
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _updaterChannel.invokeMethod('updateWidgetData');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('QuickAdd: no se pudo escribir $_widgetDataFileName: $e');
    }
  }

  static List<QuickAddEntry> _decodeEntries(dynamic decoded) {
    final List<dynamic> rawEntries;
    if (decoded is Map) {
      final list = decoded['entries'];
      rawEntries = list is List ? List<dynamic>.from(list) : const [];
    } else if (decoded is List) {
      rawEntries = decoded;
    } else {
      return const [];
    }

    final out = <QuickAddEntry>[];
    for (final item in rawEntries) {
      if (item is! Map) continue;
      final action = (item['action'] ?? '').toString().trim();
      if (action.isEmpty) continue;
      final fields = (item['fields'] is Map)
          ? Map<String, dynamic>.from(item['fields'] as Map)
          : <String, dynamic>{};
      out.add(QuickAddEntry(action: action, fields: fields));
    }
    return out;
  }
}

class QuickAddEntry {
  const QuickAddEntry({required this.action, required this.fields});

  final String action;
  final Map<String, dynamic> fields;

  double _num(String key, {double fallback = 0.0}) {
    final v = fields[key];
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    final parsed = double.tryParse(v.toString().replaceAll(',', '.'));
    return parsed ?? fallback;
  }

  String _text(String key, {String fallback = ''}) =>
      (fields[key] ?? fallback).toString().trim();

  double get amount => _num('amount');
  String get note => _text('note');
  String get title =>
      _text('title', fallback: note.isNotEmpty ? note : 'Ingreso rápido');
  String get cardId => _text('cardId');
  String get goalId => _text('goalId');
  String get categoryId => _text('categoryId');
  String get categoryName => _text('categoryName');
  String get category => _text('category', fallback: 'Sin categoría');
  String get accountName => _text('accountName');
  String get type => _text('type').toLowerCase();
}
