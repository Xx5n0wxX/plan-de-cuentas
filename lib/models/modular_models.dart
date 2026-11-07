import 'package:flutter/material.dart';

/// Identificadores de los 10 Módulos del Plan de Cuentas
class AppModuleId {
  static const String monthlyFlow = 'monthly_flow'; // 1. Base (siempre activo)
  static const String loans = 'loans'; // 2. Préstamos y Deudas en Cuotas
  static const String openAccounts = 'open_accounts'; // 3. Libretas / Cuentas Abiertas (Fiado)
  static const String sharedExpenses = 'shared_expenses'; // 4. Gastos Compartidos
  static const String receivables = 'receivables'; // 5. Me Deben / Cuentas por Cobrar
  static const String savingsGoals = 'savings_goals'; // 6. Metas de Ahorro y Sobres
  static const String subscriptions = 'subscriptions'; // 7. Suscripciones y Pagos Recurrentes
  static const String dailyBudget = 'daily_budget'; // 8. Gastos Hormiga y Presupuesto Diario
  static const String creditCards = 'credit_cards'; // 9. Tarjetas de Crédito
  static const String shoppingList = 'shopping_list'; // 10. Lista de Compras / Supermercado

  static const List<String> allOptional = [
    loans,
    openAccounts,
    sharedExpenses,
    receivables,
    savingsGoals,
    subscriptions,
    dailyBudget,
    creditCards,
    shoppingList,
  ];

  static const List<String> defaultActive = [
    loans,
    openAccounts,
    savingsGoals,
    subscriptions,
  ];
}

class AppModuleMeta {
  final String id;
  final String title;
  final String shortLabel;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
  final Color accentColor;
  final bool isCore;

  const AppModuleMeta({
    required this.id,
    required this.title,
    required this.shortLabel,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
    required this.accentColor,
    this.isCore = false,
  });

  static const List<AppModuleMeta> catalog = [
    AppModuleMeta(
      id: AppModuleId.monthlyFlow,
      title: 'Flujo Mensual (Ingresos y Gastos Fijos)',
      shortLabel: 'Movimientos',
      subtitle: 'Núcleo base: ingresos, pagos del mes y liquidez disponible.',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      accentColor: Color(0xFF0D9488),
      isCore: true,
    ),
    AppModuleMeta(
      id: AppModuleId.loans,
      title: 'Préstamos y Deudas en Cuotas',
      shortLabel: 'Préstamos',
      subtitle: 'Créditos bancarios o personales con control de cuotas y comprobante WhatsApp.',
      icon: Icons.handshake_outlined,
      selectedIcon: Icons.handshake,
      accentColor: Color(0xFF7C3AED),
    ),
    AppModuleMeta(
      id: AppModuleId.openAccounts,
      title: 'Libretas / Cuentas Abiertas (Fiado)',
      shortLabel: 'Libretas',
      subtitle: 'Cuentas corrientes en comercios con compras acumuladas y abonos parciales.',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront,
      accentColor: Color(0xFFD97706),
    ),
    AppModuleMeta(
      id: AppModuleId.sharedExpenses,
      title: 'Gastos Compartidos (Hogar / Pareja)',
      shortLabel: 'Compartidos',
      subtitle: 'Divide cuentas proporcionalmente (50/50, 60/40) con liquidación mensual.',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      accentColor: Color(0xFF2563EB),
    ),
    AppModuleMeta(
      id: AppModuleId.receivables,
      title: 'Me Deben / Cuentas por Cobrar',
      shortLabel: 'Me Deben',
      subtitle: 'Dinero prestado a amigos, familiares o clientes con recordatorio por WhatsApp.',
      icon: Icons.call_received_outlined,
      selectedIcon: Icons.call_received,
      accentColor: Color(0xFF059669),
    ),
    AppModuleMeta(
      id: AppModuleId.savingsGoals,
      title: 'Metas de Ahorro y "Sobres"',
      shortLabel: 'Ahorro',
      subtitle: 'Bolsillos con meta (emergencias, vacaciones, compras) y reserva de liquidez.',
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings,
      accentColor: Color(0xFF10B981),
    ),
    AppModuleMeta(
      id: AppModuleId.subscriptions,
      title: 'Suscripciones y Cobros Automáticos',
      shortLabel: 'Suscripciones',
      subtitle: 'Streaming, gimnasio y membresías con día de cobro y costo anualizado.',
      icon: Icons.autorenew_outlined,
      selectedIcon: Icons.autorenew,
      accentColor: Color(0xFFEC4899),
    ),
    AppModuleMeta(
      id: AppModuleId.dailyBudget,
      title: 'Gastos Hormiga y Presupuestos',
      shortLabel: 'Presupuesto',
      subtitle: 'Topes mensuales por categoría (delivery, café, salidas) con semáforo visual.',
      icon: Icons.pie_chart_outline,
      selectedIcon: Icons.pie_chart,
      accentColor: Color(0xFFF97316),
    ),
    AppModuleMeta(
      id: AppModuleId.creditCards,
      title: 'Tarjetas de Crédito y Facturación',
      shortLabel: 'Tarjetas',
      subtitle: 'Cupo utilizado, fecha de corte y monto acumulado para la próxima facturación.',
      icon: Icons.credit_card_outlined,
      selectedIcon: Icons.credit_card,
      accentColor: Color(0xFF4F46E5),
    ),
    AppModuleMeta(
      id: AppModuleId.shoppingList,
      title: 'Lista de Compras / Supermercado',
      shortLabel: 'Compras',
      subtitle: 'Calculadora pre-compra con traspaso en 1 clic a Gastos o Libreta Abierta.',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
      accentColor: Color(0xFF0891B2),
    ),
  ];

  static AppModuleMeta byId(String id) {
    return catalog.firstWhere(
      (m) => m.id == id,
      orElse: () => catalog.first,
    );
  }
}

/// Módulo 5: Me Deben / Cuentas por Cobrar
class ReceivableModel {
  final String id;
  final String debtorName;
  final String concept;
  final double totalAmount;
  final double paidAmount;
  final DateTime date;
  final DateTime? dueDate;

  ReceivableModel({
    required this.id,
    required this.debtorName,
    required this.concept,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.date,
    this.dueDate,
  });

  double get remainingAmount =>
      (totalAmount - paidAmount).clamp(0.0, double.infinity);
  bool get isSettled => remainingAmount <= 0;
  double get progress =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;

  ReceivableModel copyWith({
    String? id,
    String? debtorName,
    String? concept,
    double? totalAmount,
    double? paidAmount,
    DateTime? date,
    DateTime? dueDate,
  }) {
    return ReceivableModel(
      id: id ?? this.id,
      debtorName: debtorName ?? this.debtorName,
      concept: concept ?? this.concept,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'debtorName': debtorName,
        'concept': concept,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'date': date.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
      };

  factory ReceivableModel.fromJson(Map<String, dynamic> json) =>
      ReceivableModel(
        id: json['id'] as String,
        debtorName: (json['debtorName'] as String?) ?? 'Contacto',
        concept: (json['concept'] as String?) ?? 'Préstamo',
        totalAmount: (json['totalAmount'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.parse(json['date'] as String),
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
      );
}

/// Módulo 6: Metas de Ahorro y Sobres
class SavingsGoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final double monthlyContribution;
  final bool reserveFromLiquidity;

  SavingsGoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.monthlyContribution = 0,
    this.reserveFromLiquidity = true,
  });

  double get remainingAmount =>
      (targetAmount - currentAmount).clamp(0.0, double.infinity);
  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => currentAmount >= targetAmount && targetAmount > 0;

  SavingsGoalModel copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    double? monthlyContribution,
    bool? reserveFromLiquidity,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      reserveFromLiquidity: reserveFromLiquidity ?? this.reserveFromLiquidity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'monthlyContribution': monthlyContribution,
        'reserveFromLiquidity': reserveFromLiquidity,
      };

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) =>
      SavingsGoalModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Meta de Ahorro',
        targetAmount: (json['targetAmount'] as num).toDouble(),
        currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0.0,
        monthlyContribution:
            (json['monthlyContribution'] as num?)?.toDouble() ?? 0.0,
        reserveFromLiquidity: (json['reserveFromLiquidity'] as bool?) ?? true,
      );
}

/// Módulo 7: Suscripciones y Cobros Automáticos
class SubscriptionModel {
  final String id;
  final String name;
  final double amount;
  final int billingDay;
  final String category;
  final bool isActive;
  final bool paidThisMonth;

  SubscriptionModel({
    required this.id,
    required this.name,
    required this.amount,
    this.billingDay = 1,
    this.category = 'Streaming / Digital',
    this.isActive = true,
    this.paidThisMonth = false,
  });

  double get annualCost => amount * 12;

  SubscriptionModel copyWith({
    String? id,
    String? name,
    double? amount,
    int? billingDay,
    String? category,
    bool? isActive,
    bool? paidThisMonth,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      billingDay: billingDay ?? this.billingDay,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      paidThisMonth: paidThisMonth ?? this.paidThisMonth,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'billingDay': billingDay,
        'category': category,
        'isActive': isActive,
        'paidThisMonth': paidThisMonth,
      };

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Suscripción',
        amount: (json['amount'] as num).toDouble(),
        billingDay: (json['billingDay'] as int?) ?? 1,
        category: (json['category'] as String?) ?? 'Streaming / Digital',
        isActive: (json['isActive'] as bool?) ?? true,
        paidThisMonth: (json['paidThisMonth'] as bool?) ?? false,
      );
}

/// Módulo 8: Gastos Hormiga y Presupuestos por Categoría
class BudgetCategoryModel {
  final String id;
  final String name;
  final double monthlyLimit;

  BudgetCategoryModel({
    required this.id,
    required this.name,
    required this.monthlyLimit,
  });

  BudgetCategoryModel copyWith({
    String? id,
    String? name,
    double? monthlyLimit,
  }) {
    return BudgetCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'monthlyLimit': monthlyLimit,
      };

  factory BudgetCategoryModel.fromJson(Map<String, dynamic> json) =>
      BudgetCategoryModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Categoría',
        monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
      );
}

class AntExpenseModel {
  final String id;
  final String categoryId;
  final String categoryName;
  final String title;
  final double amount;
  final DateTime date;

  AntExpenseModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    required this.amount,
    required this.date,
  });

  AntExpenseModel copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? title,
    double? amount,
    DateTime? date,
  }) {
    return AntExpenseModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory AntExpenseModel.fromJson(Map<String, dynamic> json) =>
      AntExpenseModel(
        id: json['id'] as String,
        categoryId: (json['categoryId'] as String?) ?? '',
        categoryName: (json['categoryName'] as String?) ?? 'General',
        title: (json['title'] as String?) ?? 'Gasto rápido',
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
      );
}

/// Módulo 9: Tarjetas de Crédito y Facturación
class CreditCardModel {
  final String id;
  final String name;
  final double creditLimit;
  final double usedAmount;
  final double nextBillingAmount;
  final int closingDay;
  final int dueDay;

  CreditCardModel({
    required this.id,
    required this.name,
    required this.creditLimit,
    this.usedAmount = 0,
    this.nextBillingAmount = 0,
    this.closingDay = 20,
    this.dueDay = 5,
  });

  double get availableCredit =>
      (creditLimit - usedAmount).clamp(0.0, double.infinity);
  double get usageRatio =>
      creditLimit > 0 ? (usedAmount / creditLimit).clamp(0.0, 1.0) : 0.0;

  CreditCardModel copyWith({
    String? id,
    String? name,
    double? creditLimit,
    double? usedAmount,
    double? nextBillingAmount,
    int? closingDay,
    int? dueDay,
  }) {
    return CreditCardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      creditLimit: creditLimit ?? this.creditLimit,
      usedAmount: usedAmount ?? this.usedAmount,
      nextBillingAmount: nextBillingAmount ?? this.nextBillingAmount,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'creditLimit': creditLimit,
        'usedAmount': usedAmount,
        'nextBillingAmount': nextBillingAmount,
        'closingDay': closingDay,
        'dueDay': dueDay,
      };

  factory CreditCardModel.fromJson(Map<String, dynamic> json) =>
      CreditCardModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Tarjeta de Crédito',
        creditLimit: (json['creditLimit'] as num).toDouble(),
        usedAmount: (json['usedAmount'] as num?)?.toDouble() ?? 0.0,
        nextBillingAmount:
            (json['nextBillingAmount'] as num?)?.toDouble() ?? 0.0,
        closingDay: (json['closingDay'] as int?) ?? 20,
        dueDay: (json['dueDay'] as int?) ?? 5,
      );
}

/// Módulo 10: Lista de Compras / Supermercado
class ShoppingItemModel {
  final String id;
  final String name;
  final double estimatedPrice;
  final int quantity;
  final bool isChecked;

  ShoppingItemModel({
    required this.id,
    required this.name,
    required this.estimatedPrice,
    this.quantity = 1,
    this.isChecked = false,
  });

  double get subtotal => estimatedPrice * quantity;

  ShoppingItemModel copyWith({
    String? id,
    String? name,
    double? estimatedPrice,
    int? quantity,
    bool? isChecked,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'estimatedPrice': estimatedPrice,
        'quantity': quantity,
        'isChecked': isChecked,
      };

  factory ShoppingItemModel.fromJson(Map<String, dynamic> json) =>
      ShoppingItemModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Producto',
        estimatedPrice: (json['estimatedPrice'] as num).toDouble(),
        quantity: (json['quantity'] as int?) ?? 1,
        isChecked: (json['isChecked'] as bool?) ?? false,
      );
}
