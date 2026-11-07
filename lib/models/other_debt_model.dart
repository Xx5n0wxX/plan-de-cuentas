class OtherDebt {
  final String id;
  final String title;
  final double installmentAmount;
  final int currentInstallment;
  final int totalInstallments;
  final bool isPaidThisMonth;
  final String? note;

  OtherDebt({
    required this.id,
    required this.title,
    required this.installmentAmount,
    this.currentInstallment = 1,
    this.totalInstallments = 1,
    this.isPaidThisMonth = false,
    this.note,
  });

  bool get hasInstallments => totalInstallments > 1;
  bool get isCompleted => currentInstallment > totalInstallments;

  OtherDebt copyWith({
    String? id,
    String? title,
    double? installmentAmount,
    int? currentInstallment,
    int? totalInstallments,
    bool? isPaidThisMonth,
    String? note,
  }) {
    return OtherDebt(
      id: id ?? this.id,
      title: title ?? this.title,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      currentInstallment: currentInstallment ?? this.currentInstallment,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      isPaidThisMonth: isPaidThisMonth ?? this.isPaidThisMonth,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'installmentAmount': installmentAmount,
        'currentInstallment': currentInstallment,
        'totalInstallments': totalInstallments,
        'isPaidThisMonth': isPaidThisMonth,
        'note': note,
      };

  factory OtherDebt.fromJson(Map<String, dynamic> json) => OtherDebt(
        id: json['id'] as String,
        title: json['title'] as String,
        installmentAmount: (json['installmentAmount'] as num).toDouble(),
        currentInstallment: (json['currentInstallment'] as int?) ?? 1,
        totalInstallments: (json['totalInstallments'] as int?) ?? 1,
        isPaidThisMonth: (json['isPaidThisMonth'] as bool?) ?? false,
        note: json['note'] as String?,
      );
}
