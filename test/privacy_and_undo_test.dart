import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plan_de_cuentas/models/transaction_model.dart';
import 'package:plan_de_cuentas/providers/finance_provider.dart';
import 'package:plan_de_cuentas/utils/currency_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Punto 1: Modo Privacidad y Deshacer (Undo)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CurrencyFormatter.isPrivacyMode = false;
    });

    test('CurrencyFormatter masks currency when privacy mode is active', () {
      final realFormatted = CurrencyFormatter.format(150000);
      expect(realFormatted.contains('150.000'), isTrue);
      // El signo $ debe ir antes de los números
      expect(realFormatted, '\$150.000');
      expect(CurrencyFormatter.format(-2500), '-\$2.500');
      expect(
        CurrencyFormatter.formatLoanReceipt(
          creditor: 'Erika',
          label: 'No 7',
          loanNumber: 7,
          currentCuota: 2,
          totalCuotas: 5,
          amount: 190000,
          customTemplate:
              'PRESTAMO {ACREEDOR} [{ETIQUETA}] CUOTA {CUOTA}/{TOTAL} {MONTO}.-',
        ),
        'PRESTAMO ERIKA [No 7] CUOTA 2/5 \$190.000.-',
      );
      
      CurrencyFormatter.isPrivacyMode = true;
      expect(CurrencyFormatter.format(150000), CurrencyFormatter.maskedCurrency);
      expect(CurrencyFormatter.formatInt(5000), CurrencyFormatter.maskedCurrency);

      // Receipts should bypass privacy mode when allowPrivacy is false
      expect(
        CurrencyFormatter.format(150000, allowPrivacy: false),
        realFormatted,
      );

      CurrencyFormatter.isPrivacyMode = false;
      expect(CurrencyFormatter.format(150000), realFormatted);
    });

    test('FinanceProvider togglePrivacyMode switches and stores privacy state', () async {
      final provider = FinanceProvider();
      expect(provider.isPrivacyMode, isFalse);

      await provider.togglePrivacyMode();
      expect(provider.isPrivacyMode, isTrue);
      expect(CurrencyFormatter.isPrivacyMode, isTrue);

      await provider.togglePrivacyMode();
      expect(provider.isPrivacyMode, isFalse);
      expect(CurrencyFormatter.isPrivacyMode, isFalse);
    });

    test('FinanceProvider restores deleted transactions with undo', () async {
      final provider = FinanceProvider();
      await provider.addTransaction(
        title: 'Supermercado',
        amount: 25000,
        type: TransactionType.expense,
        category: 'Alimentación',
      );

      expect(provider.transactions.length, 1);
      final tx = provider.transactions.first;

      await provider.deleteTransaction(tx.id);
      expect(provider.transactions.isEmpty, isTrue);

      await provider.restoreTransaction(tx, index: 0);
      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.title, 'Supermercado');
    });

    test('FinanceProvider restores deleted fiado entries with undo', () async {
      final provider = FinanceProvider();
      await provider.addFiadoEntry(
        4500,
        accountName: 'Comercio Local',
        note: 'Pan y cecinas',
      );

      expect(provider.fiadoEntries.length, 1);
      final entry = provider.fiadoEntries.first;

      await provider.deleteFiadoEntry(entry.id);
      expect(provider.fiadoEntries.isEmpty, isTrue);

      await provider.restoreFiadoEntry(entry, index: 0);
      expect(provider.fiadoEntries.length, 1);
      expect(provider.fiadoEntries.first.note, 'Pan y cecinas');
    });
  });
}
