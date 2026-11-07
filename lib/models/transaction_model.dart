class TransactionModel {
  final int id;
  final String transactionCode;
  final int customerId;
  final int? userId;
  final String transactionDate;
  final String transactionType; // Setoran, Penarikan, Setoran Koreksi, Penarikan Koreksi
  final int amount;
  final String? description;

  TransactionModel({
    required this.id,
    required this.transactionCode,
    required this.customerId,
    this.userId,
    required this.transactionDate,
    required this.transactionType,
    required this.amount,
    this.description,
  });

  bool get isDeposit =>
      transactionType.toLowerCase().contains('setoran');

  bool get isWithdrawal =>
      transactionType.toLowerCase().contains('penarikan');

  bool get isCorrection =>
      transactionType.toLowerCase().contains('koreksi');

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      transactionCode: json['transaction_code']?.toString() ?? '',
      customerId: json['customer_id'] is int
          ? json['customer_id']
          : int.tryParse(json['customer_id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] != null
          ? (json['user_id'] is int
              ? json['user_id']
              : int.tryParse(json['user_id'].toString()))
          : null,
      transactionDate: json['transaction_date']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? 'Setoran',
      amount: json['amount'] is num
          ? (json['amount'] as num).toInt()
          : int.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_code': transactionCode,
      'customer_id': customerId,
      'user_id': userId,
      'transaction_date': transactionDate,
      'transaction_type': transactionType,
      'amount': amount,
      'description': description,
    };
  }
}
