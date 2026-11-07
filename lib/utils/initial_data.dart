import '../models/erika_loan_model.dart';
import '../models/fiado_model.dart';
import '../models/other_debt_model.dart';
import '../models/transaction_model.dart';

/// Clase de datos iniciales completamente neutra (en 0, sin datos personales).
class InitialData {
  static List<ErikaLoan> getInitialErikaLoans() => [];

  static List<FiadoEntry> getInitialFiadoEntries() => [];

  static List<OtherDebt> getInitialOtherDebts() => [];

  static List<TransactionModel> getInitialTransactions() => [];
}
