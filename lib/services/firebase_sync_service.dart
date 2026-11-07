import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/erika_loan_model.dart';
import '../models/fiado_model.dart';
import '../models/modular_models.dart';
import '../models/other_debt_model.dart';
import '../models/shared_config_model.dart';
import '../models/transaction_model.dart';

class LinkedDeviceModel {
  final String id;
  final String deviceName;
  final String platform;
  final DateTime linkedAt;
  final DateTime lastActive;
  final bool isActive;

  LinkedDeviceModel({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.linkedAt,
    required this.lastActive,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceName': deviceName,
        'platform': platform,
        'linkedAt': linkedAt.toIso8601String(),
        'lastActive': lastActive.toIso8601String(),
        'isActive': isActive,
      };

  factory LinkedDeviceModel.fromJson(Map<String, dynamic> json) =>
      LinkedDeviceModel(
        id: (json['id'] as String?) ?? '',
        deviceName: (json['deviceName'] as String?) ?? 'Windows / Web PC',
        platform: (json['platform'] as String?) ?? 'Escritorio',
        linkedAt: json['linkedAt'] != null
            ? DateTime.parse(json['linkedAt'] as String)
            : DateTime.now(),
        lastActive: json['lastActive'] != null
            ? DateTime.parse(json['lastActive'] as String)
            : DateTime.now(),
        isActive: (json['isActive'] as bool?) ?? true,
      );
}

class FirebaseSyncService {
  String? _activeVaultId;

  void setActiveVaultId(String? vaultId) {
    _activeVaultId = vaultId;
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  bool get isAvailable => _firestore != null && _auth != null;

  String? get currentVaultId {
    if (_activeVaultId != null && _activeVaultId!.isNotEmpty) {
      return _activeVaultId;
    }
    try {
      return _auth?.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<String?> ensureAuthenticated() async {
    final auth = _auth;
    if (auth == null) return null;
    try {
      User? user = auth.currentUser;
      if (user == null) {
        final userCred = await auth.signInAnonymously();
        user = userCred.user;
      }
      return user?.uid;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? _userCol(String col) {
    final fs = _firestore;
    if (fs == null) return null;
    final vid = currentVaultId ?? 'default_user';
    return fs.collection('users').doc(vid).collection(col);
  }

  // --- EMPAREJAMIENTO QR ESTILO WHATSAPP WEB / DESKTOP ---
  Future<void> createPairingSession({
    required String code,
    required String desktopDeviceName,
  }) async {
    final fs = _firestore;
    if (fs == null) return;
    await ensureAuthenticated();
    await fs.collection('pairing_sessions').doc(code.toUpperCase()).set({
      'code': code.toUpperCase(),
      'status': 'waiting',
      'createdAt': DateTime.now().toIso8601String(),
      'desktopDeviceName': desktopDeviceName,
      'vaultId': null,
      'ownerName': null,
      'linkedDeviceId': null,
    });
  }

  Stream<Map<String, dynamic>?> watchPairingSession(String code) {
    final fs = _firestore;
    if (fs == null) return const Stream.empty();
    return fs
        .collection('pairing_sessions')
        .doc(code.toUpperCase())
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  Future<bool> authorizePairingSession({
    required String code,
    required String vaultId,
    required String ownerName,
  }) async {
    final fs = _firestore;
    if (fs == null) return false;
    await ensureAuthenticated();

    final normalizedCode = code.trim().toUpperCase();
    final sessionRef = fs.collection('pairing_sessions').doc(normalizedCode);
    final snap = await sessionRef.get();

    String desktopName = 'Windows / Web PC';
    if (snap.exists && snap.data() != null) {
      desktopName =
          (snap.data()!['desktopDeviceName'] as String?) ?? desktopName;
    }

    final linkedDeviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    await fs
        .collection('users')
        .doc(vaultId)
        .collection('linked_devices')
        .doc(linkedDeviceId)
        .set({
      'id': linkedDeviceId,
      'deviceName': desktopName,
      'platform': 'Windows / Navegador Escritorio',
      'linkedAt': nowIso,
      'lastActive': nowIso,
      'isActive': true,
    });

    await sessionRef.set({
      'code': normalizedCode,
      'status': 'linked',
      'createdAt': nowIso,
      'desktopDeviceName': desktopName,
      'vaultId': vaultId,
      'ownerName': ownerName,
      'linkedDeviceId': linkedDeviceId,
    });

    return true;
  }

  Stream<List<LinkedDeviceModel>> getLinkedDevicesStream() {
    final col = _userCol('linked_devices');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => LinkedDeviceModel.fromJson(d.data()))
          .where((d) => d.isActive)
          .toList();
      list.sort((a, b) => b.linkedAt.compareTo(a.linkedAt));
      return list;
    });
  }

  Future<void> revokeLinkedDevice(String deviceId) async {
    final col = _userCol('linked_devices');
    if (col == null) return;
    await col.doc(deviceId).delete();
  }

  Stream<bool> watchIsDeviceStillLinked(String linkedDeviceId) {
    final col = _userCol('linked_devices');
    if (col == null) return const Stream.empty();
    return col.doc(linkedDeviceId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return false;
      return (doc.data()!['isActive'] as bool?) ?? false;
    });
  }

  // --- STREAMS EN TIEMPO REAL (LIVE SYNC) ---
  Stream<List<TransactionModel>> getTransactionsStream() {
    final col = _userCol('transactions');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => TransactionModel.fromJson(doc.data()))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<FiadoEntry>> getFiadoEntriesStream() {
    final col = _userCol('fiado_entries');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      final list =
          snap.docs.map((doc) => FiadoEntry.fromJson(doc.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<FiadoPayment>> getFiadoPaymentsStream() {
    final col = _userCol('fiado_payments');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      final list =
          snap.docs.map((doc) => FiadoPayment.fromJson(doc.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<ErikaLoan>> getErikaLoansStream() {
    final col = _userCol('erika_loans');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      final list =
          snap.docs.map((doc) => ErikaLoan.fromJson(doc.data())).toList();
      list.sort((a, b) => a.loanNumber.compareTo(b.loanNumber));
      return list;
    });
  }

  Stream<List<OtherDebt>> getOtherDebtsStream() {
    final col = _userCol('other_debts');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      return snap.docs.map((doc) => OtherDebt.fromJson(doc.data())).toList();
    });
  }

  Stream<SharedExpenseConfig> getSharedConfigStream() {
    final fs = _firestore;
    if (fs == null) return const Stream.empty();
    return fs
        .collection('users')
        .doc(currentVaultId ?? 'default_user')
        .collection('config')
        .doc('shared')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return SharedExpenseConfig();
      }
      return SharedExpenseConfig.fromJson(doc.data()!);
    });
  }

  Stream<Map<String, dynamic>?> getModulesConfigStream() {
    final fs = _firestore;
    if (fs == null) return const Stream.empty();
    return fs
        .collection('users')
        .doc(currentVaultId ?? 'default_user')
        .collection('config')
        .doc('modules')
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  Stream<List<ReceivableModel>> getReceivablesStream() {
    final col = _userCol('receivables');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => ReceivableModel.fromJson(doc.data()))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<SavingsGoalModel>> getSavingsGoalsStream() {
    final col = _userCol('savings_goals');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      return snap.docs
          .map((doc) => SavingsGoalModel.fromJson(doc.data()))
          .toList();
    });
  }

  Stream<List<SubscriptionModel>> getSubscriptionsStream() {
    final col = _userCol('subscriptions');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => SubscriptionModel.fromJson(doc.data()))
          .toList();
      list.sort((a, b) => a.billingDay.compareTo(b.billingDay));
      return list;
    });
  }

  Stream<List<BudgetCategoryModel>> getBudgetCategoriesStream() {
    final col = _userCol('budget_categories');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      return snap.docs
          .map((doc) => BudgetCategoryModel.fromJson(doc.data()))
          .toList();
    });
  }

  Stream<List<AntExpenseModel>> getAntExpensesStream() {
    final col = _userCol('ant_expenses');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => AntExpenseModel.fromJson(doc.data()))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<CreditCardModel>> getCreditCardsStream() {
    final col = _userCol('credit_cards');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      return snap.docs
          .map((doc) => CreditCardModel.fromJson(doc.data()))
          .toList();
    });
  }

  Stream<List<ShoppingItemModel>> getShoppingItemsStream() {
    final col = _userCol('shopping_items');
    if (col == null) return const Stream.empty();
    return col.snapshots().map((snap) {
      return snap.docs
          .map((doc) => ShoppingItemModel.fromJson(doc.data()))
          .toList();
    });
  }

  // --- OPERACIONES DE ESCRITURA EN LA NUBE ---
  Future<void> saveTransaction(TransactionModel tx) async {
    final col = _userCol('transactions');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(tx.id).set(tx.toJson());
  }

  Future<void> deleteTransaction(String id) async {
    final col = _userCol('transactions');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveFiadoEntry(FiadoEntry entry) async {
    final col = _userCol('fiado_entries');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(entry.id).set(entry.toJson());
  }

  Future<void> deleteFiadoEntry(String id) async {
    final col = _userCol('fiado_entries');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveFiadoPayment(FiadoPayment payment) async {
    final col = _userCol('fiado_payments');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(payment.id).set(payment.toJson());
  }

  Future<void> deleteFiadoPayment(String id) async {
    final col = _userCol('fiado_payments');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveErikaLoan(ErikaLoan loan) async {
    final col = _userCol('erika_loans');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(loan.id).set(loan.toJson());
  }

  Future<void> deleteErikaLoan(String id) async {
    final col = _userCol('erika_loans');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveOtherDebt(OtherDebt debt) async {
    final col = _userCol('other_debts');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(debt.id).set(debt.toJson());
  }

  Future<void> deleteOtherDebt(String id) async {
    final col = _userCol('other_debts');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveSharedConfig(SharedExpenseConfig config) async {
    final fs = _firestore;
    if (fs == null) return;
    await ensureAuthenticated();
    await fs
        .collection('users')
        .doc(currentVaultId ?? 'default_user')
        .collection('config')
        .doc('shared')
        .set(config.toJson());
  }

  Future<void> saveModulesConfig({
    required List<String> activeModules,
    required bool onboardingCompleted,
    required List<String> openAccountNames,
  }) async {
    final fs = _firestore;
    if (fs == null) return;
    await ensureAuthenticated();
    await fs
        .collection('users')
        .doc(currentVaultId ?? 'default_user')
        .collection('config')
        .doc('modules')
        .set({
      'activeModules': activeModules,
      'onboardingCompleted': onboardingCompleted,
      'openAccountNames': openAccountNames,
    });
  }

  Future<void> saveReceivable(ReceivableModel item) async {
    final col = _userCol('receivables');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(item.id).set(item.toJson());
  }

  Future<void> deleteReceivable(String id) async {
    final col = _userCol('receivables');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveSavingsGoal(SavingsGoalModel item) async {
    final col = _userCol('savings_goals');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(item.id).set(item.toJson());
  }

  Future<void> deleteSavingsGoal(String id) async {
    final col = _userCol('savings_goals');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveSubscription(SubscriptionModel item) async {
    final col = _userCol('subscriptions');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(item.id).set(item.toJson());
  }

  Future<void> deleteSubscription(String id) async {
    final col = _userCol('subscriptions');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveBudgetCategory(BudgetCategoryModel item) async {
    final col = _userCol('budget_categories');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(item.id).set(item.toJson());
  }

  Future<void> deleteBudgetCategory(String id) async {
    final col = _userCol('budget_categories');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveAntExpense(AntExpenseModel item) async {
    final col = _userCol('ant_expenses');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(item.id).set(item.toJson());
  }

  Future<void> deleteAntExpense(String id) async {
    final col = _userCol('ant_expenses');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveCreditCard(CreditCardModel item) async {
    final col = _userCol('credit_cards');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(item.id).set(item.toJson());
  }

  Future<void> deleteCreditCard(String id) async {
    final col = _userCol('credit_cards');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  Future<void> saveShoppingItem(ShoppingItemModel item) async {
    final col = _userCol('shopping_items');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(item.id).set(item.toJson());
  }

  Future<void> deleteShoppingItem(String id) async {
    final col = _userCol('shopping_items');
    if (col == null) return;
    await ensureAuthenticated();
    await col.doc(id).delete();
  }

  /// Sube todos los datos locales a la bóveda compartida para Live Sync
  Future<void> syncAllLocalDataToCloud({
    required List<TransactionModel> transactions,
    required List<FiadoEntry> fiadoEntries,
    required List<FiadoPayment> fiadoPayments,
    required List<ErikaLoan> erikaLoans,
    required List<OtherDebt> otherDebts,
    required SharedExpenseConfig sharedConfig,
    List<ReceivableModel> receivables = const [],
    List<SavingsGoalModel> savingsGoals = const [],
    List<SubscriptionModel> subscriptions = const [],
    List<BudgetCategoryModel> budgetCategories = const [],
    List<AntExpenseModel> antExpenses = const [],
    List<CreditCardModel> creditCards = const [],
    List<ShoppingItemModel> shoppingItems = const [],
    List<String> activeModules = const [],
    bool onboardingCompleted = false,
    List<String> openAccountNames = const [],
  }) async {
    final fs = _firestore;
    if (fs == null) return;
    await ensureAuthenticated();
    final batch = fs.batch();

    for (final tx in transactions) {
      final col = _userCol('transactions');
      if (col != null) batch.set(col.doc(tx.id), tx.toJson());
    }
    for (final f in fiadoEntries) {
      final col = _userCol('fiado_entries');
      if (col != null) batch.set(col.doc(f.id), f.toJson());
    }
    for (final p in fiadoPayments) {
      final col = _userCol('fiado_payments');
      if (col != null) batch.set(col.doc(p.id), p.toJson());
    }
    for (final l in erikaLoans) {
      final col = _userCol('erika_loans');
      if (col != null) batch.set(col.doc(l.id), l.toJson());
    }
    for (final d in otherDebts) {
      final col = _userCol('other_debts');
      if (col != null) batch.set(col.doc(d.id), d.toJson());
    }
    for (final r in receivables) {
      final col = _userCol('receivables');
      if (col != null) batch.set(col.doc(r.id), r.toJson());
    }
    for (final s in savingsGoals) {
      final col = _userCol('savings_goals');
      if (col != null) batch.set(col.doc(s.id), s.toJson());
    }
    for (final sub in subscriptions) {
      final col = _userCol('subscriptions');
      if (col != null) batch.set(col.doc(sub.id), sub.toJson());
    }
    for (final cat in budgetCategories) {
      final col = _userCol('budget_categories');
      if (col != null) batch.set(col.doc(cat.id), cat.toJson());
    }
    for (final ant in antExpenses) {
      final col = _userCol('ant_expenses');
      if (col != null) batch.set(col.doc(ant.id), ant.toJson());
    }
    for (final card in creditCards) {
      final col = _userCol('credit_cards');
      if (col != null) batch.set(col.doc(card.id), card.toJson());
    }
    for (final item in shoppingItems) {
      final col = _userCol('shopping_items');
      if (col != null) batch.set(col.doc(item.id), item.toJson());
    }

    final vid = currentVaultId ?? 'default_user';
    final configDoc =
        fs.collection('users').doc(vid).collection('config').doc('shared');
    batch.set(configDoc, sharedConfig.toJson());

    if (activeModules.isNotEmpty) {
      final modDoc =
          fs.collection('users').doc(vid).collection('config').doc('modules');
      batch.set(modDoc, {
        'activeModules': activeModules,
        'onboardingCompleted': onboardingCompleted,
        'openAccountNames': openAccountNames,
      });
    }

    await batch.commit();
  }

  /// Carga todos los datos de la bóveda compartida desde Firestore si existen
  Future<Map<String, dynamic>?> loadAllDataFromCloud() async {
    final fs = _firestore;
    final vid = currentVaultId;
    if (fs == null || vid == null) return null;
    await ensureAuthenticated();

    final txCol = _userCol('transactions');
    final fiadoCol = _userCol('fiado_entries');
    final payCol = _userCol('fiado_payments');
    final loansCol = _userCol('erika_loans');
    final debtsCol = _userCol('other_debts');
    final recCol = _userCol('receivables');
    final savCol = _userCol('savings_goals');
    final subCol = _userCol('subscriptions');
    final catCol = _userCol('budget_categories');
    final antCol = _userCol('ant_expenses');
    final cardCol = _userCol('credit_cards');
    final shopCol = _userCol('shopping_items');

    if (txCol == null ||
        fiadoCol == null ||
        payCol == null ||
        loansCol == null ||
        debtsCol == null) {
      return null;
    }

    final txSnap = await txCol.get();
    final fiadoSnap = await fiadoCol.get();
    final paySnap = await payCol.get();
    final loansSnap = await loansCol.get();
    final debtsSnap = await debtsCol.get();
    final recSnap = recCol != null ? await recCol.get() : null;
    final savSnap = savCol != null ? await savCol.get() : null;
    final subSnap = subCol != null ? await subCol.get() : null;
    final catSnap = catCol != null ? await catCol.get() : null;
    final antSnap = antCol != null ? await antCol.get() : null;
    final cardSnap = cardCol != null ? await cardCol.get() : null;
    final shopSnap = shopCol != null ? await shopCol.get() : null;

    final configDoc = await fs
        .collection('users')
        .doc(vid)
        .collection('config')
        .doc('shared')
        .get();
    final modDoc = await fs
        .collection('users')
        .doc(vid)
        .collection('config')
        .doc('modules')
        .get();

    final hasAnyData = txSnap.docs.isNotEmpty ||
        fiadoSnap.docs.isNotEmpty ||
        loansSnap.docs.isNotEmpty ||
        debtsSnap.docs.isNotEmpty ||
        (recSnap?.docs.isNotEmpty ?? false) ||
        (savSnap?.docs.isNotEmpty ?? false) ||
        (subSnap?.docs.isNotEmpty ?? false) ||
        (catSnap?.docs.isNotEmpty ?? false) ||
        (antSnap?.docs.isNotEmpty ?? false) ||
        (cardSnap?.docs.isNotEmpty ?? false) ||
        (shopSnap?.docs.isNotEmpty ?? false) ||
        modDoc.exists;

    if (!hasAnyData) {
      return null;
    }

    return {
      'transactions':
          txSnap.docs.map((d) => TransactionModel.fromJson(d.data())).toList(),
      'fiadoEntries':
          fiadoSnap.docs.map((d) => FiadoEntry.fromJson(d.data())).toList(),
      'fiadoPayments':
          paySnap.docs.map((d) => FiadoPayment.fromJson(d.data())).toList(),
      'erikaLoans':
          loansSnap.docs.map((d) => ErikaLoan.fromJson(d.data())).toList(),
      'otherDebts':
          debtsSnap.docs.map((d) => OtherDebt.fromJson(d.data())).toList(),
      'receivables': recSnap?.docs
              .map((d) => ReceivableModel.fromJson(d.data()))
              .toList() ??
          <ReceivableModel>[],
      'savingsGoals': savSnap?.docs
              .map((d) => SavingsGoalModel.fromJson(d.data()))
              .toList() ??
          <SavingsGoalModel>[],
      'subscriptions': subSnap?.docs
              .map((d) => SubscriptionModel.fromJson(d.data()))
              .toList() ??
          <SubscriptionModel>[],
      'budgetCategories': catSnap?.docs
              .map((d) => BudgetCategoryModel.fromJson(d.data()))
              .toList() ??
          <BudgetCategoryModel>[],
      'antExpenses': antSnap?.docs
              .map((d) => AntExpenseModel.fromJson(d.data()))
              .toList() ??
          <AntExpenseModel>[],
      'creditCards': cardSnap?.docs
              .map((d) => CreditCardModel.fromJson(d.data()))
              .toList() ??
          <CreditCardModel>[],
      'shoppingItems': shopSnap?.docs
              .map((d) => ShoppingItemModel.fromJson(d.data()))
              .toList() ??
          <ShoppingItemModel>[],
      'sharedConfig': configDoc.exists && configDoc.data() != null
          ? SharedExpenseConfig.fromJson(configDoc.data()!)
          : SharedExpenseConfig(),
      'modulesConfig': modDoc.exists ? modDoc.data() : null,
    };
  }

  /// Elimina todos los documentos de las colecciones en la nube para dejar la cuenta 100% en cero
  Future<void> clearAllCloudData() async {
    final fs = _firestore;
    if (fs == null) return;
    await ensureAuthenticated();
    final cols = [
      'transactions',
      'fiado_entries',
      'fiado_payments',
      'erika_loans',
      'other_debts',
      'receivables',
      'savings_goals',
      'subscriptions',
      'budget_categories',
      'ant_expenses',
      'credit_cards',
      'shopping_items',
    ];
    for (final c in cols) {
      try {
        final colRef = _userCol(c);
        if (colRef == null) continue;
        final snap = await colRef.get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }
  }
}
