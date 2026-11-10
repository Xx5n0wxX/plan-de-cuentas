import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/modular_models.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'plan_de_cuentas_vencimientos';
  static const String channelName = 'Vencimientos y Alertas';
  static const String channelDesc =
      'Recordatorios de cuotas de préstamos, suscripciones y tarjetas de crédito';

  static const String prefsEnabledKey = 'notifications_reminders_enabled';
  static const String prefsReminderHourKey = 'notifications_reminder_hour'; // default 9 (09:00 AM)

  bool get isInitialized => _isInitialized;

  /// Inicializa el plugin de notificaciones locales y la base de zonas horarias
  Future<void> init() async {
    if (_isInitialized) return;

    // Inicializar Timezones
    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('America/Santiago'));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }
    } catch (e) {
      debugPrint('Timezone init notice: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Crear canal en Android
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              description: channelDesc,
              importance: Importance.high,
              enableVibration: true,
              playSound: true,
            ),
          );
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
      // Asegurar inicialización en entornos headless / pruebas unitarias
      _isInitialized = true;
    }
  }

  /// Solicita permisos de notificación en Android 13+ y iOS
  Future<bool> requestPermissions() async {
    await init();
    bool granted = false;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        granted = await androidImpl.requestNotificationsPermission() ?? false;
      }
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        granted = await iosImpl.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } else {
      granted = true;
    }

    return granted;
  }

  /// Dispara una notificación instantánea de prueba o alerta inmediata
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await _plugin.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }

  /// Programa una notificación para una fecha y hora específica
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await init();

    // Solo programar si la fecha está en el futuro
    if (scheduledDate.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Cancela todas las notificaciones programadas
  Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Error canceling notifications: $e');
    }
  }

  /// Verifica si las notificaciones están habilitadas en las preferencias del usuario
  Future<bool> isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsEnabledKey, enabled);
  }

  /// Escanea y programa todas las alertas de vencimientos de:
  /// 1. Préstamos y Deudas en Cuotas
  /// 2. Suscripciones y Pagos Recurrentes
  /// 3. Tarjetas de Crédito (Corte y Vencimiento)
  /// 4. Cuentas por Cobrar (Me Deben)
  Future<int> syncAndScheduleReminders(FinanceProvider provider) async {
    final enabled = await isNotificationsEnabled();
    if (!enabled) {
      await cancelAll();
      return 0;
    }

    await cancelAll();

    final now = DateTime.now();
    int count = 0;

    // --- 1. PRÉSTAMOS Y DEUDAS EN CUOTAS (solo si el módulo está activo) ---
    if (provider.isModuleActive(AppModuleId.loans)) {
      for (final loan in provider.activeErikaLoans) {
      if (loan.nextDueDate != null) {
        final due = loan.nextDueDate!;
        // Notificación el mismo día del vencimiento a las 09:00 AM
        final alertDay = DateTime(due.year, due.month, due.day, 9, 0);
        if (alertDay.isAfter(now)) {
          await scheduleNotification(
            id: 1000 + (loan.loanNumber % 900),
            title: '⏰ Vencimiento de Cuota: ${loan.creditor}',
            body:
                'Vence hoy la cuota ${loan.paidInstallments + 1}/${loan.totalInstallments} de ${CurrencyFormatter.format(loan.installmentValue, allowPrivacy: false)} (${loan.label}).',
            scheduledDate: alertDay,
            payload: 'loan_${loan.id}',
          );
          count++;
        }

        // Recordatorio preventivo 1 día antes a las 18:00
        final dayBefore = alertDay.subtract(const Duration(days: 1)).copyWith(hour: 18, minute: 0);
        if (dayBefore.isAfter(now)) {
          await scheduleNotification(
            id: 5000 + (loan.loanNumber % 900),
            title: '⚠️ Recordatorio: Cuota ${loan.creditor} vence mañana',
            body:
                'Monto a pagar: ${CurrencyFormatter.format(loan.installmentValue, allowPrivacy: false)} (${loan.label}).',
            scheduledDate: dayBefore,
            payload: 'loan_${loan.id}',
          );
          count++;
        }
      }
    }
    }

    // --- 2. SUSCRIPCIONES Y COBROS RECURRENTES (solo si el módulo está activo) ---
    if (provider.isModuleActive(AppModuleId.subscriptions)) {
      for (int i = 0; i < provider.subscriptions.length; i++) {
      final sub = provider.subscriptions[i];
      if (sub.isActive && !sub.paidThisMonth) {
        // Calcular fecha en el mes actual o siguiente
        var billingDate = DateTime(now.year, now.month, sub.billingDay, 9, 0);
        if (billingDate.isBefore(now)) {
          billingDate = DateTime(now.year, now.month + 1, sub.billingDay, 9, 0);
        }

        if (billingDate.isAfter(now)) {
          await scheduleNotification(
            id: 2000 + (i % 900),
            title: '📅 Cobro de Suscripción: ${sub.name}',
            body:
                'Hoy corresponde el cobro mensual de ${CurrencyFormatter.format(sub.amount, allowPrivacy: false)} (${sub.category}).',
            scheduledDate: billingDate,
            payload: 'sub_${sub.id}',
          );
          count++;
        }
      }
      }
    }

    // --- 3. TARJETAS DE CRÉDITO (CORTE Y PAGO) (solo si el módulo está activo) ---
    if (provider.isModuleActive(AppModuleId.creditCards)) {
      for (int i = 0; i < provider.creditCards.length; i++) {
      final card = provider.creditCards[i];
      if (card.nextBillingAmount > 0 || card.usedAmount > 0) {
        // Alerta de día de corte
        var closingDate = DateTime(now.year, now.month, card.closingDay, 10, 0);
        if (closingDate.isBefore(now)) {
          closingDate = DateTime(now.year, now.month + 1, card.closingDay, 10, 0);
        }
        if (closingDate.isAfter(now)) {
          await scheduleNotification(
            id: 3000 + (i * 2),
            title: '💳 Corte de Facturación: ${card.name}',
            body:
                'Hoy es el día de cierre. Facturación acumulada: ${CurrencyFormatter.format(card.nextBillingAmount, allowPrivacy: false)}.',
            scheduledDate: closingDate,
            payload: 'card_close_${card.id}',
          );
          count++;
        }

        // Alerta de día de vencimiento de pago
        var dueDate = DateTime(now.year, now.month, card.dueDay, 9, 0);
        if (dueDate.isBefore(now)) {
          dueDate = DateTime(now.year, now.month + 1, card.dueDay, 9, 0);
        }
        if (dueDate.isAfter(now)) {
          await scheduleNotification(
            id: 3000 + (i * 2) + 1,
            title: '🚨 Vencimiento de Tarjeta: ${card.name}',
            body:
                'Hoy vence la facturación de ${CurrencyFormatter.format(card.nextBillingAmount, allowPrivacy: false)}. Págala para evitar intereses.',
            scheduledDate: dueDate,
            payload: 'card_due_${card.id}',
          );
          count++;
        }
      }
      }
    }

    // --- 4. CUENTAS POR COBRAR (ME DEBEN) (solo si el módulo está activo) ---
    if (provider.isModuleActive(AppModuleId.receivables)) {
      for (int i = 0; i < provider.receivables.length; i++) {
      final rec = provider.receivables[i];
      if (!rec.isSettled && rec.dueDate != null) {
        final due = rec.dueDate!;
        final alertDay = DateTime(due.year, due.month, due.day, 10, 0);
        if (alertDay.isAfter(now)) {
          await scheduleNotification(
            id: 4000 + (i % 900),
            title: '💰 Compromiso de Cobro: ${rec.debtorName}',
            body:
                'Hoy vence el compromiso por ${CurrencyFormatter.format(rec.remainingAmount, allowPrivacy: false)} (${rec.concept}).',
            scheduledDate: alertDay,
            payload: 'rec_${rec.id}',
          );
          count++;
        }
      }
      }
    }

    return count;
  }
}
