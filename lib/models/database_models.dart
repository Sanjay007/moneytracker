import 'package:intl/intl.dart';

class AccountDB {
  final String id;
  final String accountNumber;
  final String bankName;
  final double totalBudget;
  final double currentBalance;
  final DateTime createdAt;
  final bool isActive;

  AccountDB({
    required this.id,
    required this.accountNumber,
    required this.bankName,
    required this.totalBudget,
    required this.currentBalance,
    required this.createdAt,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'totalBudget': totalBudget,
      'currentBalance': currentBalance,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  factory AccountDB.fromMap(Map<String, dynamic> map) {
    return AccountDB(
      id: map['id'],
      accountNumber: map['accountNumber'],
      bankName: map['bankName'],
      totalBudget: map['totalBudget'],
      currentBalance: map['currentBalance'],
      createdAt: DateTime.parse(map['createdAt']),
      isActive: map['isActive'] == 1,
    );
  }
}

class TransactionDB {
  final String id;
  final double amount;
  final String remarks;
  final DateTime date;
  final String categoryName;
  final int categoryIconCodePoint;
  final int categoryColorValue;
  final String accountId;
  final String? merchant;
  final String? referenceNumber;
  final String type; // 'debit' or 'credit'
  final String source; // 'manual', 'sms'

  TransactionDB({
    required this.id,
    required this.amount,
    required this.remarks,
    required this.date,
    required this.categoryName,
    required this.categoryIconCodePoint,
    required this.categoryColorValue,
    required this.accountId,
    this.merchant,
    this.referenceNumber,
    required this.type,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'remarks': remarks,
      'date': date.toIso8601String(),
      'categoryName': categoryName,
      'categoryIconCodePoint': categoryIconCodePoint,
      'categoryColorValue': categoryColorValue,
      'accountId': accountId,
      'merchant': merchant,
      'referenceNumber': referenceNumber,
      'type': type,
      'source': source,
    };
  }

  factory TransactionDB.fromMap(Map<String, dynamic> map) {
    return TransactionDB(
      id: map['id'],
      amount: map['amount'],
      remarks: map['remarks'],
      date: DateTime.parse(map['date']),
      categoryName: map['categoryName'],
      categoryIconCodePoint: map['categoryIconCodePoint'],
      categoryColorValue: map['categoryColorValue'],
      accountId: map['accountId'],
      merchant: map['merchant'],
      referenceNumber: map['referenceNumber'],
      type: map['type'],
      source: map['source'],
    );
  }
}

class BudgetCategoryDB {
  final String name;
  final double amount;
  final int iconCodePoint;
  final int colorValue;
  final bool isDefault;
  final DateTime createdAt;

  BudgetCategoryDB({
    required this.name,
    required this.amount,
    required this.iconCodePoint,
    required this.colorValue,
    required this.isDefault,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isDefault': isDefault ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BudgetCategoryDB.fromMap(Map<String, dynamic> map) {
    return BudgetCategoryDB(
      name: map['name'],
      amount: map['amount'],
      iconCodePoint: map['iconCodePoint'],
      colorValue: map['colorValue'],
      isDefault: map['isDefault'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

class SmsTransactionDB {
  final String id;
  final String rawMessage;
  final String? bankName;
  final String? accountNumber;
  final double? amount;
  final String? transactionType;
  final DateTime date;
  final String? merchant;
  final String? referenceNumber;
  final String? userRemarks;
  final String status; // 'pending', 'accepted', 'rejected'

  SmsTransactionDB({
    required this.id,
    required this.rawMessage,
    this.bankName,
    this.accountNumber,
    this.amount,
    this.transactionType,
    required this.date,
    this.merchant,
    this.referenceNumber,
    this.userRemarks,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawMessage': rawMessage,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'amount': amount,
      'transactionType': transactionType,
      'date': date.toIso8601String(),
      'merchant': merchant,
      'referenceNumber': referenceNumber,
      'userRemarks': userRemarks,
      'status': status,
    };
  }

  factory SmsTransactionDB.fromMap(Map<String, dynamic> map) {
    return SmsTransactionDB(
      id: map['id'],
      rawMessage: map['rawMessage'],
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      amount: map['amount'],
      transactionType: map['transactionType'],
      date: DateTime.parse(map['date']),
      merchant: map['merchant'],
      referenceNumber: map['referenceNumber'],
      userRemarks: map['userRemarks'],
      status: map['status'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  bool get isDebit => transactionType?.toLowerCase() == 'debit';
  bool get isCredit => transactionType?.toLowerCase() == 'credit';

  String get formattedAmount {
    if (amount == null) return 'N/A';
    final symbol = isDebit ? '-₹' : '+₹';
    return '$symbol${amount!.toStringAsFixed(2)}';
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  SmsTransactionDB copyWith({
    String? id,
    String? rawMessage,
    String? bankName,
    String? accountNumber,
    double? amount,
    String? transactionType,
    DateTime? date,
    String? merchant,
    String? referenceNumber,
    String? userRemarks,
    String? status,
  }) {
    return SmsTransactionDB(
      id: id ?? this.id,
      rawMessage: rawMessage ?? this.rawMessage,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      userRemarks: userRemarks ?? this.userRemarks,
      status: status ?? this.status,
    );
  }
} 