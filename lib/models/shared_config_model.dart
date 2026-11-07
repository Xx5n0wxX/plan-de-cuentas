class SharedExpenseConfig {
  final bool isEnabled;
  final String partnerName;
  final double myPercentage;
  final double partnerPercentage;

  SharedExpenseConfig({
    this.isEnabled = false,
    this.partnerName = 'Compañero/a',
    this.myPercentage = 50.0,
    this.partnerPercentage = 50.0,
  });

  SharedExpenseConfig copyWith({
    bool? isEnabled,
    String? partnerName,
    double? myPercentage,
    double? partnerPercentage,
  }) {
    return SharedExpenseConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      partnerName: partnerName ?? this.partnerName,
      myPercentage: myPercentage ?? this.myPercentage,
      partnerPercentage: partnerPercentage ?? this.partnerPercentage,
    );
  }

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'partnerName': partnerName,
        'myPercentage': myPercentage,
        'partnerPercentage': partnerPercentage,
      };

  factory SharedExpenseConfig.fromJson(Map<String, dynamic> json) =>
      SharedExpenseConfig(
        isEnabled: (json['isEnabled'] as bool?) ?? false,
        partnerName: (json['partnerName'] as String?) ?? 'Compañero/a',
        myPercentage: (json['myPercentage'] as num?)?.toDouble() ?? 50.0,
        partnerPercentage:
            (json['partnerPercentage'] as num?)?.toDouble() ?? 50.0,
      );
}
