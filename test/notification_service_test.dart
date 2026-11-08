import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plan_de_cuentas/providers/finance_provider.dart';
import 'package:plan_de_cuentas/services/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Punto 3: Notificaciones locales de vencimientos', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('LocalNotificationService initialization and preferences', () async {
      final service = LocalNotificationService.instance;
      await service.init();
      expect(service.isInitialized, isTrue);

      final initiallyEnabled = await service.isNotificationsEnabled();
      expect(initiallyEnabled, isTrue);

      await service.setNotificationsEnabled(false);
      final disabled = await service.isNotificationsEnabled();
      expect(disabled, isFalse);

      await service.setNotificationsEnabled(true);
      final reEnabled = await service.isNotificationsEnabled();
      expect(reEnabled, isTrue);
    });

    test('syncAndScheduleReminders detects active loans, subscriptions and cards', () async {
      final service = LocalNotificationService.instance;
      await service.init();
      await service.setNotificationsEnabled(true);

      final provider = FinanceProvider();

      // Add a future loan due in 3 days
      final futureDate = DateTime.now().add(const Duration(days: 3));
      await provider.addErikaLoan(
        loanNumber: 1,
        creditor: 'Banco Falabella',
        grantDate: DateTime.now(),
        principalAmount: 200000,
        totalToPay: 240000,
        installmentValue: 40000,
        totalInstallments: 6,
        nextDueDate: futureDate,
      );

      // Add active subscription
      await provider.addSubscription(
        name: 'Spotify Familiar',
        amount: 8500,
        billingDay: 25,
      );

      // Add credit card with pending billing
      await provider.addCreditCard(
        name: 'CMR Mastercard',
        creditLimit: 1000000,
        usedAmount: 85000,
        nextBillingAmount: 85000,
        closingDay: 20,
        dueDay: 5,
      );

      // Add receivable due in future
      await provider.addReceivable(
        debtorName: 'Matías Silva',
        concept: 'Entrada concierto',
        totalAmount: 35000,
        dueDate: DateTime.now().add(const Duration(days: 5)),
      );

      final scheduledCount = await service.syncAndScheduleReminders(provider);
      // It should calculate and attempt to schedule reminders for future dates
      expect(scheduledCount, greaterThan(0));

      // When notifications are disabled, scheduledCount should be 0
      await service.setNotificationsEnabled(false);
      final countDisabled = await service.syncAndScheduleReminders(provider);
      expect(countDisabled, 0);
    });
  });
}
