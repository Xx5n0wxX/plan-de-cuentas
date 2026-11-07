import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/erika_loan_model.dart';
import '../models/fiado_model.dart';
import '../models/modular_models.dart';
import '../models/other_debt_model.dart';
import '../models/shared_config_model.dart';
import '../models/transaction_model.dart';
import '../services/firebase_sync_service.dart';
import '../services/google_drive_backup_service.dart';

class FinanceProvider extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final GoogleDriveBackupService _driveService = GoogleDriveBackupService();

  // --- MÓDULOS ACTIVOS Y CONFIGURACIÓN MODULAR ---
  List<String> _activeModules = List<String>.from(AppModuleId.defaultActive);
  bool _onboardingCompleted = false;
  List<String> _openAccountNames = ['Comercio Local'];
  String _selectedOpenAccount = 'Comercio Local';

  // --- DATOS DE LOS 10 MÓDULOS (INICIAN EN 0) ---
  List<TransactionModel> _transactions = [];
  List<FiadoEntry> _fiadoEntries = [];
  List<FiadoPayment> _fiadoPayments = [];
  List<ErikaLoan> _erikaLoans = [];
  List<OtherDebt> _otherDebts = [];
  SharedExpenseConfig _sharedConfig = SharedExpenseConfig();
  List<ReceivableModel> _receivables = [];
  List<SavingsGoalModel> _savingsGoals = [];
  List<SubscriptionModel> _subscriptions = [];
  List<BudgetCategoryModel> _budgetCategories = [];
  List<AntExpenseModel> _antExpenses = [];
  List<CreditCardModel> _creditCards = [];
  List<ShoppingItemModel> _shoppingItems = [];

  ThemeMode _themeMode = ThemeMode.system;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isBackingUpDrive = false;
  double _driveBackupProgress = 0.0;

  // Metadatos estilo WhatsApp Copia de Seguridad
  DateTime? _lastLocalSaveTime;
  DateTime? _lastDriveBackupTime;
  String? _lastDriveBackupSize;
  String _backupFrequency = 'Diariamente';

  // Suscripciones de Live Sync (Celular <-> PC)
  final List<StreamSubscription<dynamic>> _liveSubs = [];
  String? _listeningVaultId;

  // Getters
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isBackingUpDrive => _isBackingUpDrive;
  double get driveBackupProgress => _driveBackupProgress;
  DateTime? get lastLocalSaveTime => _lastLocalSaveTime;
  DateTime? get lastDriveBackupTime => _lastDriveBackupTime;
  String? get lastDriveBackupSize => _lastDriveBackupSize;
  String get backupFrequency => _backupFrequency;
  FirebaseSyncService get syncService => _syncService;
  ThemeMode get themeMode => _themeMode;
  DateTime get selectedMonth => _selectedMonth;

  List<String> get activeModules => _activeModules;
  bool get onboardingCompleted => _onboardingCompleted;
  List<String> get openAccountNames => _openAccountNames;
  String get selectedOpenAccount => _selectedOpenAccount;

  bool isModuleActive(String moduleId) {
    if (moduleId == AppModuleId.monthlyFlow) return true;
    return _activeModules.contains(moduleId);
  }

  List<TransactionModel> get transactions => _transactions;
  List<FiadoEntry> get fiadoEntries => _fiadoEntries;
  List<FiadoPayment> get fiadoPayments => _fiadoPayments;
  List<ErikaLoan> get erikaLoans => _erikaLoans;
  List<OtherDebt> get otherDebts => _otherDebts;
  SharedExpenseConfig get sharedConfig => _sharedConfig;
  List<ReceivableModel> get receivables => _receivables;
  List<SavingsGoalModel> get savingsGoals => _savingsGoals;
  List<SubscriptionModel> get subscriptions => _subscriptions;
  List<BudgetCategoryModel> get budgetCategories => _budgetCategories;
  List<AntExpenseModel> get antExpenses => _antExpenses;
  List<CreditCardModel> get creditCards => _creditCards;
  List<ShoppingItemModel> get shoppingItems => _shoppingItems;

  FinanceProvider() {
    _loadData();
  }

  @override
  void dispose() {
    stopLiveSync();
    super.dispose();
  }

  // --- GESTIÓN DE MÓDULOS ACTIVOS Y PERFILES RÁPIDOS ---
  Future<void> toggleModule(String moduleId, bool enabled) async {
    if (moduleId == AppModuleId.monthlyFlow) return; // Base siempre activo
    if (enabled && !_activeModules.contains(moduleId)) {
      _activeModules.add(moduleId);
    } else if (!enabled) {
      _activeModules.remove(moduleId);
    }
    if (moduleId == AppModuleId.sharedExpenses) {
      _sharedConfig = _sharedConfig.copyWith(isEnabled: enabled);
      _syncService.saveSharedConfig(_sharedConfig).catchError((_) {});
    }
    await _saveData();
    notifyListeners();
    _syncService
        .saveModulesConfig(
          activeModules: _activeModules,
          onboardingCompleted: _onboardingCompleted,
          openAccountNames: _openAccountNames,
        )
        .catchError((_) {});
  }

  Future<void> applyModulePreset(List<String> moduleIds) async {
    _activeModules = List<String>.from(moduleIds);
    _onboardingCompleted = true;
    _sharedConfig = _sharedConfig.copyWith(
      isEnabled: _activeModules.contains(AppModuleId.sharedExpenses),
    );
    await _saveData();
    notifyListeners();
    _syncService
        .saveModulesConfig(
          activeModules: _activeModules,
          onboardingCompleted: _onboardingCompleted,
          openAccountNames: _openAccountNames,
        )
        .catchError((_) {});
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    await _saveData();
    notifyListeners();
    _syncService
        .saveModulesConfig(
          activeModules: _activeModules,
          onboardingCompleted: _onboardingCompleted,
          openAccountNames: _openAccountNames,
        )
        .catchError((_) {});
  }

  void setSelectedOpenAccount(String name) {
    _selectedOpenAccount = name;
    notifyListeners();
  }

  Future<void> addOpenAccountName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (!_openAccountNames.contains(clean)) {
      _openAccountNames.add(clean);
    }
    _selectedOpenAccount = clean;
    await _saveData();
    notifyListeners();
    _syncService
        .saveModulesConfig(
          activeModules: _activeModules,
          onboardingCompleted: _onboardingCompleted,
          openAccountNames: _openAccountNames,
        )
        .catchError((_) {});
  }

  Future<void> renameOpenAccount(String oldName, String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty || clean == oldName) return;

    final idx = _openAccountNames.indexOf(oldName);
    if (idx != -1) {
      if (_openAccountNames.contains(clean)) {
        _openAccountNames.removeAt(idx);
      } else {
        _openAccountNames[idx] = clean;
      }
    } else if (!_openAccountNames.contains(clean)) {
      _openAccountNames.add(clean);
    }

    for (var i = 0; i < _fiadoEntries.length; i++) {
      if (_fiadoEntries[i].accountName == oldName) {
        final updated = _fiadoEntries[i].copyWith(accountName: clean);
        _fiadoEntries[i] = updated;
        _syncService.saveFiadoEntry(updated).catchError((_) {});
      }
    }

    for (var i = 0; i < _fiadoPayments.length; i++) {
      if (_fiadoPayments[i].accountName == oldName) {
        final updated = FiadoPayment(
          id: _fiadoPayments[i].id,
          accountName: clean,
          date: _fiadoPayments[i].date,
          amountPaid: _fiadoPayments[i].amountPaid,
          remainingBalance: _fiadoPayments[i].remainingBalance,
          note: _fiadoPayments[i].note,
        );
        _fiadoPayments[i] = updated;
        _syncService.saveFiadoPayment(updated).catchError((_) {});
      }
    }

    if (_selectedOpenAccount == oldName) {
      _selectedOpenAccount = clean;
    }

    await _saveData();
    notifyListeners();
    _syncService
        .saveModulesConfig(
          activeModules: _activeModules,
          onboardingCompleted: _onboardingCompleted,
          openAccountNames: _openAccountNames,
        )
        .catchError((_) {});
  }

  Future<void> deleteOpenAccount(String name) async {
    _openAccountNames.remove(name);

    final entriesToRemove =
        _fiadoEntries.where((e) => e.accountName == name).toList();
    _fiadoEntries.removeWhere((e) => e.accountName == name);
    for (final e in entriesToRemove) {
      _syncService.deleteFiadoEntry(e.id).catchError((_) {});
    }

    final paymentsToRemove =
        _fiadoPayments.where((p) => p.accountName == name).toList();
    _fiadoPayments.removeWhere((p) => p.accountName == name);
    for (final p in paymentsToRemove) {
      _syncService.deleteFiadoPayment(p.id).catchError((_) {});
    }

    if (_selectedOpenAccount == name) {
      _selectedOpenAccount =
          _openAccountNames.isNotEmpty ? _openAccountNames.first : '';
    }

    await _saveData();
    notifyListeners();
    _syncService
        .saveModulesConfig(
          activeModules: _activeModules,
          onboardingCompleted: _onboardingCompleted,
          openAccountNames: _openAccountNames,
        )
        .catchError((_) {});
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> setBackupFrequency(String frequency) async {
    _backupFrequency = frequency;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backupFrequency', frequency);
  }

  // --- LIVE SYNC EN TIEMPO REAL (CELULAR <-> PC) ---
  Future<void> startLiveSync(String vaultId,
      {bool isLinkedDesktop = false}) async {
    if (vaultId.isEmpty) return;
    _syncService.setActiveVaultId(vaultId);

    if (_listeningVaultId == vaultId && _liveSubs.isNotEmpty) {
      return;
    }
    stopLiveSync();
    _listeningVaultId = vaultId;

    await syncWithCloud(forceUpload: false);

    try {
      _liveSubs.add(
        _syncService.getTransactionsStream().listen((list) {
          _transactions = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getFiadoEntriesStream().listen((list) {
          _fiadoEntries = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getFiadoPaymentsStream().listen((list) {
          _fiadoPayments = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getErikaLoansStream().listen((list) {
          _erikaLoans = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getOtherDebtsStream().listen((list) {
          _otherDebts = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getSharedConfigStream().listen((cfg) {
          _sharedConfig = cfg;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getModulesConfigStream().listen((data) {
          if (data != null) {
            if (data['activeModules'] != null) {
              _activeModules = List<String>.from(data['activeModules'] as List);
            }
            if (data['onboardingCompleted'] != null) {
              _onboardingCompleted = data['onboardingCompleted'] as bool;
            }
            if (data['openAccountNames'] != null) {
              final names = List<String>.from(data['openAccountNames'] as List);
              _openAccountNames = names;
              if (_openAccountNames.isEmpty) {
                _selectedOpenAccount = '';
              } else if (!_openAccountNames.contains(_selectedOpenAccount)) {
                _selectedOpenAccount = _openAccountNames.first;
              }
            }
            _saveDataLocallyOnly();
            notifyListeners();
          }
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getReceivablesStream().listen((list) {
          _receivables = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getSavingsGoalsStream().listen((list) {
          _savingsGoals = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getSubscriptionsStream().listen((list) {
          _subscriptions = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getBudgetCategoriesStream().listen((list) {
          _budgetCategories = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getAntExpensesStream().listen((list) {
          _antExpenses = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getCreditCardsStream().listen((list) {
          _creditCards = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );

      _liveSubs.add(
        _syncService.getShoppingItemsStream().listen((list) {
          _shoppingItems = list;
          _saveDataLocallyOnly();
          notifyListeners();
        }, onError: (_) {}),
      );
    } catch (_) {}
  }

  void stopLiveSync() {
    for (final sub in _liveSubs) {
      sub.cancel();
    }
    _liveSubs.clear();
    _listeningVaultId = null;
  }

  Future<bool> authorizeQrPairing({
    required String code,
    required String vaultId,
    required String ownerName,
  }) async {
    try {
      _isSyncing = true;
      notifyListeners();

      _syncService.setActiveVaultId(vaultId);

      await _syncService.syncAllLocalDataToCloud(
        transactions: _transactions,
        fiadoEntries: _fiadoEntries,
        fiadoPayments: _fiadoPayments,
        erikaLoans: _erikaLoans,
        otherDebts: _otherDebts,
        sharedConfig: _sharedConfig,
        receivables: _receivables,
        savingsGoals: _savingsGoals,
        subscriptions: _subscriptions,
        budgetCategories: _budgetCategories,
        antExpenses: _antExpenses,
        creditCards: _creditCards,
        shoppingItems: _shoppingItems,
        activeModules: _activeModules,
        onboardingCompleted: _onboardingCompleted,
        openAccountNames: _openAccountNames,
      );

      final ok = await _syncService.authorizePairingSession(
        code: code,
        vaultId: vaultId,
        ownerName: ownerName,
      );

      await startLiveSync(vaultId);

      return ok;
    } catch (e) {
      debugPrint('Error autorizando QR: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- COPIA DE SEGURIDAD EN GOOGLE DRIVE (ESTILO WHATSAPP) ---
  Map<String, dynamic> buildFullBackupBundle(String vaultId) {
    return {
      'app': 'Plan de Cuentas',
      'version': 2,
      'vaultId': vaultId,
      'exportedAt': DateTime.now().toIso8601String(),
      'activeModules': _activeModules,
      'onboardingCompleted': _onboardingCompleted,
      'openAccountNames': _openAccountNames,
      'transactions': _transactions.map((e) => e.toJson()).toList(),
      'fiadoEntries': _fiadoEntries.map((e) => e.toJson()).toList(),
      'fiadoPayments': _fiadoPayments.map((e) => e.toJson()).toList(),
      'erikaLoans': _erikaLoans.map((e) => e.toJson()).toList(),
      'otherDebts': _otherDebts.map((e) => e.toJson()).toList(),
      'sharedConfig': _sharedConfig.toJson(),
      'receivables': _receivables.map((e) => e.toJson()).toList(),
      'savingsGoals': _savingsGoals.map((e) => e.toJson()).toList(),
      'subscriptions': _subscriptions.map((e) => e.toJson()).toList(),
      'budgetCategories': _budgetCategories.map((e) => e.toJson()).toList(),
      'antExpenses': _antExpenses.map((e) => e.toJson()).toList(),
      'creditCards': _creditCards.map((e) => e.toJson()).toList(),
      'shoppingItems': _shoppingItems.map((e) => e.toJson()).toList(),
    };
  }

  Future<DriveBackupMetadata> performGoogleDriveBackup({
    required String accessToken,
    required String vaultId,
  }) async {
    _isBackingUpDrive = true;
    _driveBackupProgress = 0.25;
    notifyListeners();

    try {
      final bundle = buildFullBackupBundle(vaultId);
      _driveBackupProgress = 0.6;
      notifyListeners();

      final meta = await _driveService.uploadBackup(
        accessToken: accessToken,
        backupData: bundle,
      );

      _driveBackupProgress = 1.0;
      _lastDriveBackupTime = meta.modifiedTime;
      _lastDriveBackupSize = meta.formattedSize;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'lastDriveBackupTime', _lastDriveBackupTime!.toIso8601String());
      await prefs.setString('lastDriveBackupSize', _lastDriveBackupSize!);

      notifyListeners();
      return meta;
    } finally {
      _isBackingUpDrive = false;
      notifyListeners();
    }
  }

  Future<DriveBackupMetadata?> checkExistingDriveBackup(
      String accessToken) async {
    final meta = await _driveService.findLatestBackup(accessToken);
    if (meta != null) {
      _lastDriveBackupTime = meta.modifiedTime;
      _lastDriveBackupSize = meta.formattedSize;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'lastDriveBackupTime', _lastDriveBackupTime!.toIso8601String());
      await prefs.setString('lastDriveBackupSize', _lastDriveBackupSize!);
      notifyListeners();
    }
    return meta;
  }

  Future<void> restoreFromGoogleDrive({
    required String accessToken,
    required String fileId,
  }) async {
    _isBackingUpDrive = true;
    _driveBackupProgress = 0.3;
    notifyListeners();

    try {
      final data = await _driveService.downloadBackup(
        accessToken: accessToken,
        fileId: fileId,
      );
      _driveBackupProgress = 0.75;
      notifyListeners();

      if (data['activeModules'] != null) {
        _activeModules = List<String>.from(data['activeModules'] as List);
      }
      if (data['onboardingCompleted'] != null) {
        _onboardingCompleted = data['onboardingCompleted'] as bool;
      }
      if (data['openAccountNames'] != null) {
        final names = List<String>.from(data['openAccountNames'] as List);
        if (names.isNotEmpty) _openAccountNames = names;
      }
      if (data['transactions'] != null) {
        _transactions = (data['transactions'] as List)
            .map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['fiadoEntries'] != null) {
        _fiadoEntries = (data['fiadoEntries'] as List)
            .map((e) => FiadoEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['fiadoPayments'] != null) {
        _fiadoPayments = (data['fiadoPayments'] as List)
            .map((e) => FiadoPayment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['erikaLoans'] != null) {
        _erikaLoans = (data['erikaLoans'] as List)
            .map((e) => ErikaLoan.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['otherDebts'] != null) {
        _otherDebts = (data['otherDebts'] as List)
            .map((e) => OtherDebt.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['sharedConfig'] != null) {
        _sharedConfig = SharedExpenseConfig.fromJson(
          Map<String, dynamic>.from(data['sharedConfig'] as Map),
        );
      }
      if (data['receivables'] != null) {
        _receivables = (data['receivables'] as List)
            .map((e) => ReceivableModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['savingsGoals'] != null) {
        _savingsGoals = (data['savingsGoals'] as List)
            .map((e) => SavingsGoalModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['subscriptions'] != null) {
        _subscriptions = (data['subscriptions'] as List)
            .map(
                (e) => SubscriptionModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['budgetCategories'] != null) {
        _budgetCategories = (data['budgetCategories'] as List)
            .map((e) =>
                BudgetCategoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['antExpenses'] != null) {
        _antExpenses = (data['antExpenses'] as List)
            .map((e) => AntExpenseModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['creditCards'] != null) {
        _creditCards = (data['creditCards'] as List)
            .map((e) => CreditCardModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['shoppingItems'] != null) {
        _shoppingItems = (data['shoppingItems'] as List)
            .map(
                (e) => ShoppingItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      await _saveData();
      _driveBackupProgress = 1.0;
      notifyListeners();

      await syncWithCloud(forceUpload: true);
    } finally {
      _isBackingUpDrive = false;
      notifyListeners();
    }
  }

  // --- CÁLCULOS MENSUALES (MÓDULO 1 + RESERVAS) ---
  List<TransactionModel> get currentMonthTransactions {
    return _transactions.where((tx) {
      return tx.date.year == _selectedMonth.year &&
          tx.date.month == _selectedMonth.month;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double get monthlyIncome {
    return currentMonthTransactions
        .where((tx) => tx.type == TransactionType.income)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get monthlyExpenses {
    return currentMonthTransactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get reservedSavingsThisMonth {
    if (!isModuleActive(AppModuleId.savingsGoals)) return 0.0;
    return _savingsGoals
        .where((g) => g.reserveFromLiquidity && !g.isCompleted)
        .fold(0.0, (sum, g) => sum + g.monthlyContribution);
  }

  double get monthlyNetBalance =>
      monthlyIncome - monthlyExpenses - reservedSavingsThisMonth;

  bool get isDeficit => monthlyNetBalance < 0;

  // --- MÓDULO 3: LIBRETAS / CUENTAS ABIERTAS (FIADO) ---
  List<FiadoEntry> get selectedAccountEntries => _fiadoEntries
      .where((e) => e.accountName == _selectedOpenAccount)
      .toList();

  List<FiadoPayment> get selectedAccountPayments => _fiadoPayments
      .where((p) => p.accountName == _selectedOpenAccount)
      .toList();

  double get totalFiadoAccumulated {
    return _fiadoEntries
        .where((item) => _openAccountNames.contains(item.accountName))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalFiadoPaid {
    return _fiadoPayments
        .where((item) => _openAccountNames.contains(item.accountName))
        .fold(0.0, (sum, item) => sum + item.amountPaid);
  }

  double get totalPendingFiado {
    final pending = totalFiadoAccumulated - totalFiadoPaid;
    return pending > 0 ? pending : 0.0;
  }

  double pendingForOpenAccount(String accountName) {
    final acc = _fiadoEntries
        .where((e) => e.accountName == accountName)
        .fold(0.0, (s, e) => s + e.amount);
    final paid = _fiadoPayments
        .where((p) => p.accountName == accountName)
        .fold(0.0, (s, p) => s + p.amountPaid);
    final diff = acc - paid;
    return diff > 0 ? diff : 0.0;
  }

  // --- MÓDULO 2: PRÉSTAMOS Y DEUDAS EN CUOTAS ---
  List<ErikaLoan> get activeErikaLoans =>
      _erikaLoans.where((l) => !l.isCompleted).toList();

  List<ErikaLoan> get completedErikaLoans =>
      _erikaLoans.where((l) => l.isCompleted).toList();

  double get totalErikaMonthlyObligations {
    return activeErikaLoans.fold(0.0, (sum, l) => sum + l.installmentValue);
  }

  // --- MÓDULO 4: GASTOS COMPARTIDOS ---
  List<TransactionModel> get sharedMonthTransactions => currentMonthTransactions
      .where((t) => t.isShared && t.type == TransactionType.expense)
      .toList();

  double get totalSharedExpensesMonth =>
      sharedMonthTransactions.fold(0.0, (s, t) => s + t.amount);

  double get mySharedShareMonth =>
      totalSharedExpensesMonth * (_sharedConfig.myPercentage / 100.0);

  double get partnerSharedShareMonth =>
      totalSharedExpensesMonth * (_sharedConfig.partnerPercentage / 100.0);

  // --- MÓDULO 5: ME DEBEN / POR COBRAR ---
  double get totalPendingReceivables => _receivables
      .where((r) => !r.isSettled)
      .fold(0.0, (s, r) => s + r.remainingAmount);

  // --- MÓDULO 6: METAS DE AHORRO ---
  double get totalSavedInGoals =>
      _savingsGoals.fold(0.0, (s, g) => s + g.currentAmount);

  // --- MÓDULO 7: SUSCRIPCIONES ---
  double get totalMonthlySubscriptions => _subscriptions
      .where((s) => s.isActive)
      .fold(0.0, (sum, s) => sum + s.amount);

  double get totalAnnualSubscriptions => totalMonthlySubscriptions * 12;

  // --- MÓDULO 8: GASTOS HORMIGA Y PRESUPUESTO DIARIO ---
  List<AntExpenseModel> get currentMonthAntExpenses => _antExpenses.where((e) {
        return e.date.year == _selectedMonth.year &&
            e.date.month == _selectedMonth.month;
      }).toList();

  double spentInCategory(String categoryId) {
    return currentMonthAntExpenses
        .where((e) => e.categoryId == categoryId)
        .fold(0.0, (s, e) => s + e.amount);
  }

  double get totalAntExpensesMonth =>
      currentMonthAntExpenses.fold(0.0, (s, e) => s + e.amount);

  // --- MÓDULO 9: TARJETAS DE CRÉDITO ---
  double get totalNextCreditCardBilling =>
      _creditCards.fold(0.0, (s, c) => s + c.nextBillingAmount);

  // --- MÓDULO 10: LISTA DE COMPRAS ---
  double get shoppingCartEstimatedTotal =>
      _shoppingItems.fold(0.0, (s, i) => s + i.subtotal);

  double get shoppingCartCheckedTotal => _shoppingItems
      .where((i) => i.isChecked)
      .fold(0.0, (s, i) => s + i.subtotal);

  // --- ACTIONS: LIBRETAS ABIERTAS / FIADO ---
  Future<void> addFiadoEntry(
    double amount, {
    String note = '',
    DateTime? date,
    String? accountName,
  }) async {
    final acc = accountName ?? _selectedOpenAccount;
    if (!_openAccountNames.contains(acc)) {
      _openAccountNames.add(acc);
    }
    final entry = FiadoEntry(
      id: _uuid.v4(),
      accountName: acc,
      date: date ?? DateTime.now(),
      amount: amount,
      note: note.isEmpty ? 'Compra a cuenta ($acc)' : note,
    );
    _fiadoEntries.insert(0, entry);
    await _saveData();
    notifyListeners();
    _syncService
        .saveFiadoEntry(entry)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> deleteFiadoEntry(String id) async {
    _fiadoEntries.removeWhere((item) => item.id == id);
    await _saveData();
    notifyListeners();
    _syncService
        .deleteFiadoEntry(id)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> updateFiadoEntry(FiadoEntry updated) async {
    final idx = _fiadoEntries.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    _fiadoEntries[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService
        .saveFiadoEntry(updated)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> deleteFiadoPayment(String id) async {
    _fiadoPayments.removeWhere((item) => item.id == id);
    await _saveData();
    notifyListeners();
    _syncService
        .deleteFiadoPayment(id)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> updateFiadoPayment(FiadoPayment updated) async {
    final idx = _fiadoPayments.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;
    _fiadoPayments[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService
        .saveFiadoPayment(updated)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> payFiado(
    double amountPaid, {
    String note = '',
    DateTime? date,
    String? accountName,
  }) async {
    final acc = accountName ?? _selectedOpenAccount;
    final now = date ?? DateTime.now();
    final remainingBefore = pendingForOpenAccount(acc);
    final remainingAfter =
        (remainingBefore - amountPaid).clamp(0.0, double.infinity);

    final payment = FiadoPayment(
      id: _uuid.v4(),
      accountName: acc,
      date: now,
      amountPaid: amountPaid,
      remainingBalance: remainingAfter,
      note: note.isEmpty ? 'Abono cuenta $acc' : note,
    );
    _fiadoPayments.insert(0, payment);

    final tx = TransactionModel(
      id: _uuid.v4(),
      title: amountPaid >= remainingBefore
          ? 'Liquidación Cuenta ($acc)'
          : 'Abono Cuenta ($acc)',
      amount: amountPaid,
      date: now,
      type: TransactionType.expense,
      category: 'Libretas / Cuentas Abiertas',
      note: note.isEmpty ? 'Pago a cuenta $acc' : note,
    );
    _transactions.insert(0, tx);

    await _saveData();
    notifyListeners();
    _syncService
        .saveFiadoPayment(payment)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
    _syncService
        .saveTransaction(tx)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  // --- ACTIONS: PRÉSTAMOS Y DEUDAS EN CUOTAS ---
  Future<void> payErikaInstallment(String loanId, {DateTime? date}) async {
    final index = _erikaLoans.indexWhere((l) => l.id == loanId);
    if (index == -1) return;

    final loan = _erikaLoans[index];
    if (loan.isCompleted) return;

    final updatedLoan = loan.copyWith(
      paidInstallments: loan.paidInstallments + 1,
    );
    _erikaLoans[index] = updatedLoan;

    final now = date ?? DateTime.now();
    final tx = TransactionModel(
      id: _uuid.v4(),
      title:
          '${loan.creditor} (${loan.label}) - Cuota ${updatedLoan.paidInstallments}/${loan.totalInstallments}',
      amount: loan.installmentValue,
      date: now,
      type: TransactionType.expense,
      category: 'Préstamos y Cuotas',
      relatedLoanId: loan.id,
      note: 'Pago de cuota',
    );
    _transactions.insert(0, tx);

    await _saveData();
    notifyListeners();
    _syncService
        .saveErikaLoan(updatedLoan)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
    _syncService
        .saveTransaction(tx)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> addErikaLoan({
    required int loanNumber,
    String creditor = 'Entidad / Acreedor',
    String? label,
    String receiptTemplate = ErikaLoan.defaultReceiptTemplate,
    required DateTime grantDate,
    required double principalAmount,
    required double totalToPay,
    required double installmentValue,
    int totalInstallments = 5,
    DateTime? nextDueDate,
  }) async {
    final loan = ErikaLoan(
      id: _uuid.v4(),
      loanNumber: loanNumber,
      creditor: creditor.trim().isEmpty ? 'Entidad / Acreedor' : creditor.trim(),
      label: (label == null || label.trim().isEmpty)
          ? 'N° $loanNumber'
          : label.trim(),
      receiptTemplate: receiptTemplate.trim().isEmpty
          ? ErikaLoan.defaultReceiptTemplate
          : receiptTemplate.trim(),
      grantDate: grantDate,
      principalAmount: principalAmount,
      totalToPay: totalToPay,
      installmentValue: installmentValue,
      totalInstallments: totalInstallments,
      paidInstallments: 0,
      nextDueDate: nextDueDate,
    );
    _erikaLoans.add(loan);
    await _saveData();
    notifyListeners();
    _syncService
        .saveErikaLoan(loan)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> deleteErikaLoan(String id) async {
    _erikaLoans.removeWhere((l) => l.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteErikaLoan(id).catchError((_) {});
  }

  Future<void> updateErikaLoan(ErikaLoan updated) async {
    final idx = _erikaLoans.indexWhere((l) => l.id == updated.id);
    if (idx == -1) return;
    _erikaLoans[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService
        .saveErikaLoan(updated)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  // --- ACTIONS: OTRAS DEUDAS ---
  Future<void> payOtherDebt(String debtId, {DateTime? date}) async {
    final index = _otherDebts.indexWhere((d) => d.id == debtId);
    if (index == -1) return;

    final debt = _otherDebts[index];
    final now = date ?? DateTime.now();

    final updatedDebt = debt.copyWith(
      isPaidThisMonth: true,
      currentInstallment: debt.currentInstallment + 1,
    );
    _otherDebts[index] = updatedDebt;

    final titleDesc = debt.hasInstallments
        ? '${debt.title} (Cuota ${debt.currentInstallment}/${debt.totalInstallments})'
        : debt.title;

    final tx = TransactionModel(
      id: _uuid.v4(),
      title: titleDesc,
      amount: debt.installmentAmount,
      date: now,
      type: TransactionType.expense,
      category: 'Deudas',
    );
    _transactions.insert(0, tx);

    await _saveData();
    notifyListeners();
    _syncService
        .saveOtherDebt(updatedDebt)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
    _syncService
        .saveTransaction(tx)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> addOtherDebt(OtherDebt debt) async {
    _otherDebts.add(debt);
    await _saveData();
    notifyListeners();
    _syncService
        .saveOtherDebt(debt)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> updateOtherDebt(OtherDebt updated) async {
    final idx = _otherDebts.indexWhere((d) => d.id == updated.id);
    if (idx == -1) return;
    _otherDebts[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService
        .saveOtherDebt(updated)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> deleteOtherDebt(String id) async {
    _otherDebts.removeWhere((d) => d.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteOtherDebt(id).catchError((_) {});
  }

  // --- ACTIONS: GENERAL TRANSACTIONS ---
  Future<void> addTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    String? note,
    DateTime? date,
    bool isShared = false,
  }) async {
    final tx = TransactionModel(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      date: date ?? DateTime.now(),
      type: type,
      category: category,
      note: note,
      isShared: isShared,
    );
    _transactions.insert(0, tx);
    await _saveData();
    notifyListeners();
    _syncService
        .saveTransaction(tx)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> updateTransaction(TransactionModel updated) async {
    final idx = _transactions.indexWhere((tx) => tx.id == updated.id);
    if (idx == -1) return;
    _transactions[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService
        .saveTransaction(updated)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((tx) => tx.id == id);
    await _saveData();
    notifyListeners();
    _syncService
        .deleteTransaction(id)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  // --- ACTIONS: SHARED CONFIG (MÓDULO 4) ---
  Future<void> updateSharedConfig(SharedExpenseConfig config) async {
    _sharedConfig = config;
    if (config.isEnabled &&
        !_activeModules.contains(AppModuleId.sharedExpenses)) {
      _activeModules.add(AppModuleId.sharedExpenses);
    }
    await _saveData();
    notifyListeners();
    _syncService
        .saveSharedConfig(config)
        .catchError((e) => debugPrint('Cloud sync error: $e'));
  }

  // --- ACTIONS: MÓDULO 5 (ME DEBEN / CUENTAS POR COBRAR) ---
  Future<void> addReceivable({
    required String debtorName,
    required String concept,
    required double totalAmount,
    DateTime? dueDate,
  }) async {
    final item = ReceivableModel(
      id: _uuid.v4(),
      debtorName: debtorName.trim(),
      concept: concept.trim(),
      totalAmount: totalAmount,
      date: DateTime.now(),
      dueDate: dueDate,
    );
    _receivables.insert(0, item);
    await _saveData();
    notifyListeners();
    _syncService.saveReceivable(item).catchError((_) {});
  }

  Future<void> registerReceivablePayment(String id, double amount,
      {bool addToMonthlyIncome = true}) async {
    final idx = _receivables.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final current = _receivables[idx];
    final updated = current.copyWith(
      paidAmount: (current.paidAmount + amount).clamp(0.0, current.totalAmount),
    );
    _receivables[idx] = updated;

    if (addToMonthlyIncome) {
      await addTransaction(
        title: 'Cobro a ${current.debtorName} (${current.concept})',
        amount: amount,
        type: TransactionType.income,
        category: 'Cobros / Devoluciones',
      );
    } else {
      await _saveData();
      notifyListeners();
    }
    _syncService.saveReceivable(updated).catchError((_) {});
  }

  Future<void> updateReceivable(ReceivableModel updated) async {
    final idx = _receivables.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return;
    _receivables[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveReceivable(updated).catchError((_) {});
  }

  Future<void> deleteReceivable(String id) async {
    _receivables.removeWhere((r) => r.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteReceivable(id).catchError((_) {});
  }

  // --- ACTIONS: MÓDULO 6 (METAS DE AHORRO Y SOBRES) ---
  Future<void> addSavingsGoal({
    required String name,
    required double targetAmount,
    double currentAmount = 0,
    double monthlyContribution = 0,
    bool reserveFromLiquidity = true,
  }) async {
    final item = SavingsGoalModel(
      id: _uuid.v4(),
      name: name.trim(),
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      monthlyContribution: monthlyContribution,
      reserveFromLiquidity: reserveFromLiquidity,
    );
    _savingsGoals.add(item);
    await _saveData();
    notifyListeners();
    _syncService.saveSavingsGoal(item).catchError((_) {});
  }

  Future<void> depositToSavingsGoal(String id, double amount) async {
    final idx = _savingsGoals.indexWhere((g) => g.id == id);
    if (idx == -1) return;
    final updated = _savingsGoals[idx].copyWith(
      currentAmount:
          (_savingsGoals[idx].currentAmount + amount).clamp(0.0, double.infinity),
    );
    _savingsGoals[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveSavingsGoal(updated).catchError((_) {});
  }

  Future<void> updateSavingsGoal(SavingsGoalModel updated) async {
    final idx = _savingsGoals.indexWhere((g) => g.id == updated.id);
    if (idx == -1) return;
    _savingsGoals[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveSavingsGoal(updated).catchError((_) {});
  }

  Future<void> deleteSavingsGoal(String id) async {
    _savingsGoals.removeWhere((g) => g.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteSavingsGoal(id).catchError((_) {});
  }

  // --- ACTIONS: MÓDULO 7 (SUSCRIPCIONES Y PAGOS RECURRENTES) ---
  Future<void> addSubscription({
    required String name,
    required double amount,
    required int billingDay,
    String category = 'Streaming / Digital',
  }) async {
    final item = SubscriptionModel(
      id: _uuid.v4(),
      name: name.trim(),
      amount: amount,
      billingDay: billingDay.clamp(1, 31),
      category: category,
    );
    _subscriptions.add(item);
    _subscriptions.sort((a, b) => a.billingDay.compareTo(b.billingDay));
    await _saveData();
    notifyListeners();
    _syncService.saveSubscription(item).catchError((_) {});
  }

  Future<void> toggleSubscriptionActive(String id, bool active) async {
    final idx = _subscriptions.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final updated = _subscriptions[idx].copyWith(isActive: active);
    _subscriptions[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveSubscription(updated).catchError((_) {});
  }

  Future<void> paySubscriptionThisMonth(String id) async {
    final idx = _subscriptions.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final sub = _subscriptions[idx];
    final updated = sub.copyWith(paidThisMonth: true);
    _subscriptions[idx] = updated;
    await addTransaction(
      title: 'Suscripción: ${sub.name}',
      amount: sub.amount,
      type: TransactionType.expense,
      category: 'Suscripciones / Streaming',
    );
    _syncService.saveSubscription(updated).catchError((_) {});
  }

  Future<void> updateSubscription(SubscriptionModel updated) async {
    final idx = _subscriptions.indexWhere((s) => s.id == updated.id);
    if (idx == -1) return;
    _subscriptions[idx] = updated;
    _subscriptions.sort((a, b) => a.billingDay.compareTo(b.billingDay));
    await _saveData();
    notifyListeners();
    _syncService.saveSubscription(updated).catchError((_) {});
  }

  Future<void> deleteSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteSubscription(id).catchError((_) {});
  }

  // --- ACTIONS: MÓDULO 8 (GASTOS HORMIGA Y PRESUPUESTO DIARIO) ---
  Future<void> addBudgetCategory({
    required String name,
    required double monthlyLimit,
  }) async {
    final item = BudgetCategoryModel(
      id: _uuid.v4(),
      name: name.trim(),
      monthlyLimit: monthlyLimit,
    );
    _budgetCategories.add(item);
    await _saveData();
    notifyListeners();
    _syncService.saveBudgetCategory(item).catchError((_) {});
  }

  Future<void> deleteBudgetCategory(String id) async {
    _budgetCategories.removeWhere((c) => c.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteBudgetCategory(id).catchError((_) {});
  }

  Future<void> updateBudgetCategory(BudgetCategoryModel updated) async {
    final idx = _budgetCategories.indexWhere((c) => c.id == updated.id);
    if (idx == -1) return;
    _budgetCategories[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveBudgetCategory(updated).catchError((_) {});
  }

  Future<void> addAntExpense({
    required String categoryId,
    required String categoryName,
    required String title,
    required double amount,
  }) async {
    final item = AntExpenseModel(
      id: _uuid.v4(),
      categoryId: categoryId,
      categoryName: categoryName,
      title: title.trim().isEmpty ? categoryName : title.trim(),
      amount: amount,
      date: DateTime.now(),
    );
    _antExpenses.insert(0, item);
    await addTransaction(
      title: item.title,
      amount: amount,
      type: TransactionType.expense,
      category: categoryName,
      note: 'Gasto diario / hormiga',
    );
    _syncService.saveAntExpense(item).catchError((_) {});
  }

  Future<void> updateAntExpense(AntExpenseModel updated) async {
    final idx = _antExpenses.indexWhere((a) => a.id == updated.id);
    if (idx == -1) return;
    _antExpenses[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveAntExpense(updated).catchError((_) {});
  }

  Future<void> deleteAntExpense(String id) async {
    _antExpenses.removeWhere((a) => a.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteAntExpense(id).catchError((_) {});
  }

  // --- ACTIONS: MÓDULO 9 (TARJETAS DE CRÉDITO) ---
  Future<void> addCreditCard({
    required String name,
    required double creditLimit,
    double usedAmount = 0,
    double nextBillingAmount = 0,
    int closingDay = 20,
    int dueDay = 5,
  }) async {
    final item = CreditCardModel(
      id: _uuid.v4(),
      name: name.trim(),
      creditLimit: creditLimit,
      usedAmount: usedAmount,
      nextBillingAmount: nextBillingAmount,
      closingDay: closingDay.clamp(1, 31),
      dueDay: dueDay.clamp(1, 31),
    );
    _creditCards.add(item);
    await _saveData();
    notifyListeners();
    _syncService.saveCreditCard(item).catchError((_) {});
  }

  Future<void> addCardCharge(
      String cardId, double amount, String description) async {
    final idx = _creditCards.indexWhere((c) => c.id == cardId);
    if (idx == -1) return;
    final card = _creditCards[idx];
    final updated = card.copyWith(
      usedAmount: card.usedAmount + amount,
      nextBillingAmount: card.nextBillingAmount + amount,
    );
    _creditCards[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveCreditCard(updated).catchError((_) {});
  }

  Future<void> payCreditCardStatement(String cardId, double amount) async {
    final idx = _creditCards.indexWhere((c) => c.id == cardId);
    if (idx == -1) return;
    final card = _creditCards[idx];
    final updated = card.copyWith(
      usedAmount: (card.usedAmount - amount).clamp(0.0, double.infinity),
      nextBillingAmount:
          (card.nextBillingAmount - amount).clamp(0.0, double.infinity),
    );
    _creditCards[idx] = updated;
    await addTransaction(
      title: 'Pago Facturación ${card.name}',
      amount: amount,
      type: TransactionType.expense,
      category: 'Tarjeta de Crédito',
    );
    _syncService.saveCreditCard(updated).catchError((_) {});
  }

  Future<void> deleteCreditCard(String id) async {
    _creditCards.removeWhere((c) => c.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteCreditCard(id).catchError((_) {});
  }

  Future<void> updateCreditCard(CreditCardModel updated) async {
    final idx = _creditCards.indexWhere((c) => c.id == updated.id);
    if (idx == -1) return;
    _creditCards[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveCreditCard(updated).catchError((_) {});
  }

  // --- ACTIONS: MÓDULO 10 (LISTA DE COMPRAS / SUPERMERCADO) ---
  Future<void> addShoppingItem({
    required String name,
    required double estimatedPrice,
    int quantity = 1,
  }) async {
    final item = ShoppingItemModel(
      id: _uuid.v4(),
      name: name.trim(),
      estimatedPrice: estimatedPrice,
      quantity: quantity < 1 ? 1 : quantity,
    );
    _shoppingItems.add(item);
    await _saveData();
    notifyListeners();
    _syncService.saveShoppingItem(item).catchError((_) {});
  }

  Future<void> toggleShoppingItemChecked(String id, bool checked) async {
    final idx = _shoppingItems.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final updated = _shoppingItems[idx].copyWith(isChecked: checked);
    _shoppingItems[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveShoppingItem(updated).catchError((_) {});
  }

  Future<void> deleteShoppingItem(String id) async {
    _shoppingItems.removeWhere((i) => i.id == id);
    await _saveData();
    notifyListeners();
    _syncService.deleteShoppingItem(id).catchError((_) {});
  }

  Future<void> updateShoppingItem(ShoppingItemModel updated) async {
    final idx = _shoppingItems.indexWhere((i) => i.id == updated.id);
    if (idx == -1) return;
    _shoppingItems[idx] = updated;
    await _saveData();
    notifyListeners();
    _syncService.saveShoppingItem(updated).catchError((_) {});
  }

  Future<void> checkoutShoppingCart({
    required bool chargeToOpenAccount,
    String? openAccountName,
  }) async {
    final checked = _shoppingItems.where((i) => i.isChecked).toList();
    final itemsToProcess = checked.isNotEmpty ? checked : _shoppingItems;
    if (itemsToProcess.isEmpty) return;

    final total = itemsToProcess.fold(0.0, (s, i) => s + i.subtotal);
    final summary = itemsToProcess.map((i) => i.name).take(4).join(', ');

    if (chargeToOpenAccount) {
      await addFiadoEntry(
        total,
        note: 'Lista de compras: $summary',
        accountName: openAccountName ?? _selectedOpenAccount,
      );
    } else {
      await addTransaction(
        title: 'Compra Supermercado / Lista',
        amount: total,
        type: TransactionType.expense,
        category: 'Mercadería / Supermercado',
        note: summary,
      );
    }

    for (final item in itemsToProcess) {
      _shoppingItems.removeWhere((i) => i.id == item.id);
      _syncService.deleteShoppingItem(item.id).catchError((_) {});
    }
    await _saveData();
    notifyListeners();
  }

  // --- SINCRONIZACIÓN CON FIREBASE EN LA NUBE ---
  Future<void> syncWithCloud({bool forceUpload = false}) async {
    try {
      _isSyncing = true;
      notifyListeners();

      if (!forceUpload) {
        final cloudData = await _syncService.loadAllDataFromCloud();
        if (cloudData != null) {
          _transactions =
              (cloudData['transactions'] as List<TransactionModel>?) ??
                  _transactions;
          _fiadoEntries =
              (cloudData['fiadoEntries'] as List<FiadoEntry>?) ?? _fiadoEntries;
          _fiadoPayments =
              (cloudData['fiadoPayments'] as List<FiadoPayment>?) ??
                  _fiadoPayments;
          _erikaLoans =
              (cloudData['erikaLoans'] as List<ErikaLoan>?) ?? _erikaLoans;
          _otherDebts =
              (cloudData['otherDebts'] as List<OtherDebt>?) ?? _otherDebts;
          _receivables = (cloudData['receivables'] as List<ReceivableModel>?) ??
              _receivables;
          _savingsGoals =
              (cloudData['savingsGoals'] as List<SavingsGoalModel>?) ??
                  _savingsGoals;
          _subscriptions =
              (cloudData['subscriptions'] as List<SubscriptionModel>?) ??
                  _subscriptions;
          _budgetCategories =
              (cloudData['budgetCategories'] as List<BudgetCategoryModel>?) ??
                  _budgetCategories;
          _antExpenses = (cloudData['antExpenses'] as List<AntExpenseModel>?) ??
              _antExpenses;
          _creditCards = (cloudData['creditCards'] as List<CreditCardModel>?) ??
              _creditCards;
          _shoppingItems =
              (cloudData['shoppingItems'] as List<ShoppingItemModel>?) ??
                  _shoppingItems;
          _sharedConfig = (cloudData['sharedConfig'] as SharedExpenseConfig?) ??
              _sharedConfig;

          final modCfg = cloudData['modulesConfig'] as Map<String, dynamic>?;
          if (modCfg != null) {
            if (modCfg['activeModules'] != null) {
              _activeModules =
                  List<String>.from(modCfg['activeModules'] as List);
            }
            if (modCfg['onboardingCompleted'] != null) {
              _onboardingCompleted = modCfg['onboardingCompleted'] as bool;
            }
            if (modCfg['openAccountNames'] != null) {
              final names =
                  List<String>.from(modCfg['openAccountNames'] as List);
              if (names.isNotEmpty) _openAccountNames = names;
            }
          }

          await _saveDataLocallyOnly();
          notifyListeners();
          return;
        }
      }

      await _syncService.syncAllLocalDataToCloud(
        transactions: _transactions,
        fiadoEntries: _fiadoEntries,
        fiadoPayments: _fiadoPayments,
        erikaLoans: _erikaLoans,
        otherDebts: _otherDebts,
        sharedConfig: _sharedConfig,
        receivables: _receivables,
        savingsGoals: _savingsGoals,
        subscriptions: _subscriptions,
        budgetCategories: _budgetCategories,
        antExpenses: _antExpenses,
        creditCards: _creditCards,
        shoppingItems: _shoppingItems,
        activeModules: _activeModules,
        onboardingCompleted: _onboardingCompleted,
        openAccountNames: _openAccountNames,
      );
    } catch (e) {
      debugPrint('Sync with cloud error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- PERSISTENCIA LOCAL (SharedPreferences) ---
  Future<void> _saveData() async {
    _lastLocalSaveTime = DateTime.now();
    await _saveDataLocallyOnly();
  }

  Future<void> _saveDataLocallyOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('storage_v2_neutral_clean', true);
    await prefs.setStringList('activeModules_v2', _activeModules);
    await prefs.setBool('onboardingCompleted_v2', _onboardingCompleted);
    await prefs.setStringList('openAccountNames_v2', _openAccountNames);
    await prefs.setString(
        'transactions_v2', jsonEncode(_transactions.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'fiadoEntries_v2', jsonEncode(_fiadoEntries.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'fiadoPayments_v2', jsonEncode(_fiadoPayments.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'erikaLoans_v2', jsonEncode(_erikaLoans.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'otherDebts_v2', jsonEncode(_otherDebts.map((e) => e.toJson()).toList()));
    await prefs.setString('sharedConfig_v2', jsonEncode(_sharedConfig.toJson()));
    await prefs.setString(
        'receivables_v2', jsonEncode(_receivables.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'savingsGoals_v2', jsonEncode(_savingsGoals.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'subscriptions_v2', jsonEncode(_subscriptions.map((e) => e.toJson()).toList()));
    await prefs.setString('budgetCategories_v2',
        jsonEncode(_budgetCategories.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'antExpenses_v2', jsonEncode(_antExpenses.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'creditCards_v2', jsonEncode(_creditCards.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'shoppingItems_v2', jsonEncode(_shoppingItems.map((e) => e.toJson()).toList()));
    if (_lastLocalSaveTime != null) {
      await prefs.setString(
          'lastLocalSaveTime', _lastLocalSaveTime!.toIso8601String());
    }
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    // Limpiar claves antiguas de la versión v1 que contenían datos personales de la planilla
    final isCleanedV2 = prefs.getBool('storage_v2_neutral_clean') ?? false;
    if (!isCleanedV2) {
      await prefs.remove('transactions');
      await prefs.remove('fiadoEntries');
      await prefs.remove('fiadoPayments');
      await prefs.remove('erikaLoans');
      await prefs.remove('otherDebts');
      await prefs.remove('sharedConfig');
      await prefs.setBool('storage_v2_neutral_clean', true);
    }

    final activeModList = prefs.getStringList('activeModules_v2');
    if (activeModList != null) {
      _activeModules = activeModList;
    }
    _onboardingCompleted = prefs.getBool('onboardingCompleted_v2') ?? false;
    final accNames = prefs.getStringList('openAccountNames_v2');
    if (accNames != null) {
      _openAccountNames = accNames;
      _selectedOpenAccount =
          _openAccountNames.isNotEmpty ? _openAccountNames.first : '';
    }

    final txRaw = prefs.getString('transactions_v2');
    final fiadoRaw = prefs.getString('fiadoEntries_v2');
    final paymentsRaw = prefs.getString('fiadoPayments_v2');
    final loansRaw = prefs.getString('erikaLoans_v2');
    final debtsRaw = prefs.getString('otherDebts_v2');
    final configRaw = prefs.getString('sharedConfig_v2');
    final recRaw = prefs.getString('receivables_v2');
    final savRaw = prefs.getString('savingsGoals_v2');
    final subRaw = prefs.getString('subscriptions_v2');
    final catRaw = prefs.getString('budgetCategories_v2');
    final antRaw = prefs.getString('antExpenses_v2');
    final cardRaw = prefs.getString('creditCards_v2');
    final shopRaw = prefs.getString('shoppingItems_v2');

    final themeRaw = prefs.getString('themeMode');
    final localTimeRaw = prefs.getString('lastLocalSaveTime');
    final driveTimeRaw = prefs.getString('lastDriveBackupTime');
    final driveSizeRaw = prefs.getString('lastDriveBackupSize');
    final freqRaw = prefs.getString('backupFrequency');

    if (localTimeRaw != null) {
      _lastLocalSaveTime = DateTime.tryParse(localTimeRaw);
    } else {
      _lastLocalSaveTime = DateTime.now();
    }
    if (driveTimeRaw != null) {
      _lastDriveBackupTime = DateTime.tryParse(driveTimeRaw);
    }
    _lastDriveBackupSize = driveSizeRaw;
    if (freqRaw != null) {
      _backupFrequency = freqRaw;
    }

    if (themeRaw != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == themeRaw,
        orElse: () => ThemeMode.system,
      );
    }

    if (txRaw != null) {
      final List list = jsonDecode(txRaw);
      _transactions = list.map((e) => TransactionModel.fromJson(e)).toList();
    }
    if (fiadoRaw != null) {
      final List list = jsonDecode(fiadoRaw);
      _fiadoEntries = list.map((e) => FiadoEntry.fromJson(e)).toList();
    }
    if (paymentsRaw != null) {
      final List list = jsonDecode(paymentsRaw);
      _fiadoPayments = list.map((e) => FiadoPayment.fromJson(e)).toList();
    }
    if (loansRaw != null) {
      final List list = jsonDecode(loansRaw);
      _erikaLoans = list.map((e) => ErikaLoan.fromJson(e)).toList();
    }
    if (debtsRaw != null) {
      final List list = jsonDecode(debtsRaw);
      _otherDebts = list.map((e) => OtherDebt.fromJson(e)).toList();
    }
    if (configRaw != null) {
      _sharedConfig = SharedExpenseConfig.fromJson(jsonDecode(configRaw));
    }
    if (recRaw != null) {
      final List list = jsonDecode(recRaw);
      _receivables = list.map((e) => ReceivableModel.fromJson(e)).toList();
    }
    if (savRaw != null) {
      final List list = jsonDecode(savRaw);
      _savingsGoals = list.map((e) => SavingsGoalModel.fromJson(e)).toList();
    }
    if (subRaw != null) {
      final List list = jsonDecode(subRaw);
      _subscriptions = list.map((e) => SubscriptionModel.fromJson(e)).toList();
    }
    if (catRaw != null) {
      final List list = jsonDecode(catRaw);
      _budgetCategories =
          list.map((e) => BudgetCategoryModel.fromJson(e)).toList();
    }
    if (antRaw != null) {
      final List list = jsonDecode(antRaw);
      _antExpenses = list.map((e) => AntExpenseModel.fromJson(e)).toList();
    }
    if (cardRaw != null) {
      final List list = jsonDecode(cardRaw);
      _creditCards = list.map((e) => CreditCardModel.fromJson(e)).toList();
    }
    if (shopRaw != null) {
      final List list = jsonDecode(shopRaw);
      _shoppingItems = list.map((e) => ShoppingItemModel.fromJson(e)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Deja la aplicación completamente en 0 (sin datos)
  Future<void> resetToSpreadsheetData() async {
    await clearAllDataToZero();
  }

  Future<void> clearAllDataToZero() async {
    _transactions = [];
    _fiadoEntries = [];
    _fiadoPayments = [];
    _erikaLoans = [];
    _otherDebts = [];
    _receivables = [];
    _savingsGoals = [];
    _subscriptions = [];
    _budgetCategories = [];
    _antExpenses = [];
    _creditCards = [];
    _shoppingItems = [];
    _sharedConfig = SharedExpenseConfig();
    _openAccountNames = ['Comercio Local'];
    _selectedOpenAccount = 'Comercio Local';
    await _saveData();
    notifyListeners();
    _syncService.clearAllCloudData().catchError((_) {});
    _syncService
        .saveModulesConfig(
          activeModules: _activeModules,
          onboardingCompleted: _onboardingCompleted,
          openAccountNames: _openAccountNames,
        )
        .catchError((_) {});
  }
}
