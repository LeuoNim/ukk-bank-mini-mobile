class CustomerModel {
  final int id;
  final String accountNumber;
  final String studentId;
  final String studentName;
  final String className;
  final int balance;
  final String status;

  CustomerModel({
    required this.id,
    required this.accountNumber,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.balance,
    required this.status,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      accountNumber: json['account_number']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      className: json['class']?.toString() ?? '',
      balance: json['balance'] is num
          ? (json['balance'] as num).toInt()
          : int.tryParse(json['balance']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'Aktif',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_number': accountNumber,
      'student_id': studentId,
      'student_name': studentName,
      'class': className,
      'balance': balance,
      'status': status,
    };
  }

  CustomerModel copyWith({
    int? id,
    String? accountNumber,
    String? studentId,
    String? studentName,
    String? className,
    int? balance,
    String? status,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      accountNumber: accountNumber ?? this.accountNumber,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      balance: balance ?? this.balance,
      status: status ?? this.status,
    );
  }
}
