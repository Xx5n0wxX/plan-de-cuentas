class ErikaLoan {
  final String id;
  final int loanNumber;
  final String creditor;
  final String label;
  final String receiptTemplate;
  final DateTime grantDate;
  final double principalAmount;
  final double totalToPay;
  final double installmentValue;
  final int totalInstallments;
  final int paidInstallments;
  final DateTime? nextDueDate;

  static const String defaultReceiptTemplate =
      'PAGO {ACREEDOR} [{ETIQUETA}] CUOTA {CUOTA}/{TOTAL} {MONTO}.-';

  ErikaLoan({
    required this.id,
    required this.loanNumber,
    this.creditor = 'Entidad / Persona',
    String? label,
    this.receiptTemplate = defaultReceiptTemplate,
    required this.grantDate,
    required this.principalAmount,
    required this.totalToPay,
    required this.installmentValue,
    this.totalInstallments = 5,
    this.paidInstallments = 0,
    this.nextDueDate,
  }) : label = label ?? 'N° $loanNumber';

  bool get isCompleted => paidInstallments >= totalInstallments;
  int get remainingInstallments => totalInstallments - paidInstallments;
  double get totalPaid => paidInstallments * installmentValue;
  double get remainingDebt => isCompleted ? 0 : (totalToPay - totalPaid);
  double get progressPercentage => totalInstallments > 0
      ? (paidInstallments / totalInstallments).clamp(0.0, 1.0)
      : 0.0;

  ErikaLoan copyWith({
    String? id,
    int? loanNumber,
    String? creditor,
    String? label,
    String? receiptTemplate,
    DateTime? grantDate,
    double? principalAmount,
    double? totalToPay,
    double? installmentValue,
    int? totalInstallments,
    int? paidInstallments,
    DateTime? nextDueDate,
  }) {
    return ErikaLoan(
      id: id ?? this.id,
      loanNumber: loanNumber ?? this.loanNumber,
      creditor: creditor ?? this.creditor,
      label: label ?? this.label,
      receiptTemplate: receiptTemplate ?? this.receiptTemplate,
      grantDate: grantDate ?? this.grantDate,
      principalAmount: principalAmount ?? this.principalAmount,
      totalToPay: totalToPay ?? this.totalToPay,
      installmentValue: installmentValue ?? this.installmentValue,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      paidInstallments: paidInstallments ?? this.paidInstallments,
      nextDueDate: nextDueDate ?? this.nextDueDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'loanNumber': loanNumber,
        'creditor': creditor,
        'label': label,
        'receiptTemplate': receiptTemplate,
        'grantDate': grantDate.toIso8601String(),
        'principalAmount': principalAmount,
        'totalToPay': totalToPay,
        'installmentValue': installmentValue,
        'totalInstallments': totalInstallments,
        'paidInstallments': paidInstallments,
        'nextDueDate': nextDueDate?.toIso8601String(),
      };

  factory ErikaLoan.fromJson(Map<String, dynamic> json) {
    final numVal = (json['loanNumber'] as int?) ?? 1;
    return ErikaLoan(
      id: json['id'] as String,
      loanNumber: numVal,
      creditor: (json['creditor'] as String?) ?? 'Entidad / Persona',
      label: (json['label'] as String?) ?? 'N° $numVal',
      receiptTemplate:
          (json['receiptTemplate'] as String?) ?? defaultReceiptTemplate,
      grantDate: DateTime.parse(json['grantDate'] as String),
      principalAmount: (json['principalAmount'] as num).toDouble(),
      totalToPay: (json['totalToPay'] as num).toDouble(),
      installmentValue: (json['installmentValue'] as num).toDouble(),
      totalInstallments: (json['totalInstallments'] as int?) ?? 5,
      paidInstallments: (json['paidInstallments'] as int?) ?? 0,
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'] as String)
          : null,
    );
  }
}
