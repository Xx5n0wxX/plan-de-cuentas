enum TransactionType { income, expense }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String category;
  final String? note;
  final String? relatedLoanId;
  final bool isShared;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.note,
    this.relatedLoanId,
    this.isShared = false,
  });

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? category,
    String? note,
    String? relatedLoanId,
    bool? isShared,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      note: note ?? this.note,
      relatedLoanId: relatedLoanId ?? this.relatedLoanId,
      isShared: isShared ?? this.isShared,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type.name,
        'category': category,
        'note': note,
        'relatedLoanId': relatedLoanId,
        'isShared': isShared,
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        type: TransactionType.values.byName(json['type'] as String),
        category: json['category'] as String,
        note: json['note'] as String?,
        relatedLoanId: json['relatedLoanId'] as String?,
        isShared: (json['isShared'] as bool?) ?? false,
      );
}
