class FiadoEntry {
  final String id;
  final String accountName;
  final DateTime date;
  final double amount;
  final String note;
  final bool isSettled;

  FiadoEntry({
    required this.id,
    this.accountName = 'Cuenta Principal',
    required this.date,
    required this.amount,
    this.note = '',
    this.isSettled = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountName': accountName,
        'date': date.toIso8601String(),
        'amount': amount,
        'note': note,
        'isSettled': isSettled,
      };

  factory FiadoEntry.fromJson(Map<String, dynamic> json) => FiadoEntry(
        id: json['id'] as String,
        accountName: (json['accountName'] as String?) ?? 'Cuenta Principal',
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        note: (json['note'] as String?) ?? '',
        isSettled: (json['isSettled'] as bool?) ?? false,
      );

  FiadoEntry copyWith({
    String? id,
    String? accountName,
    DateTime? date,
    double? amount,
    String? note,
    bool? isSettled,
  }) {
    return FiadoEntry(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}

class FiadoPayment {
  final String id;
  final String accountName;
  final DateTime date;
  final double amountPaid;
  final double remainingBalance;
  final String note;

  FiadoPayment({
    required this.id,
    this.accountName = 'Cuenta Principal',
    required this.date,
    required this.amountPaid,
    required this.remainingBalance,
    this.note = '',
  });

  FiadoPayment copyWith({
    String? id,
    String? accountName,
    DateTime? date,
    double? amountPaid,
    double? remainingBalance,
    String? note,
  }) {
    return FiadoPayment(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      date: date ?? this.date,
      amountPaid: amountPaid ?? this.amountPaid,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountName': accountName,
        'date': date.toIso8601String(),
        'amountPaid': amountPaid,
        'remainingBalance': remainingBalance,
        'note': note,
      };

  factory FiadoPayment.fromJson(Map<String, dynamic> json) => FiadoPayment(
        id: json['id'] as String,
        accountName: (json['accountName'] as String?) ?? 'Cuenta Principal',
        date: DateTime.parse(json['date'] as String),
        amountPaid: (json['amountPaid'] as num).toDouble(),
        remainingBalance: (json['remainingBalance'] as num).toDouble(),
        note: (json['note'] as String?) ?? '',
      );
}
