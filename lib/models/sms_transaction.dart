import 'package:intl/intl.dart';

class SmsTransaction {
  final String id;
  final String bankName;
  final String message;
  final DateTime date;
  final double? amount;
  final String? transactionType; // 'debit', 'credit'
  final String? accountNumber;
  final String? merchant;
  final double? balance;
  final String? referenceNumber;
  final String? userRemarks; // User added remarks
  final String status; // 'pending', 'accepted', 'rejected'

  SmsTransaction({
    required this.id,
    required this.bankName,
    required this.message,
    required this.date,
    this.amount,
    this.transactionType,
    this.accountNumber,
    this.merchant,
    this.balance,
    this.referenceNumber,
    this.userRemarks,
    this.status = 'pending',
  });

  String get formattedDate => DateFormat('dd MMM yyyy, hh:mm a').format(date);
  
  String get formattedAmount {
    if (amount == null) return 'N/A';
    return '₹${amount!.toStringAsFixed(2)}';
  }

  bool get isDebit => transactionType?.toLowerCase() == 'debit';
  bool get isCredit => transactionType?.toLowerCase() == 'credit';
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  // Copy with method for updates
  SmsTransaction copyWith({
    String? id,
    String? bankName,
    String? message,
    DateTime? date,
    double? amount,
    String? transactionType,
    String? accountNumber,
    String? merchant,
    double? balance,
    String? referenceNumber,
    String? userRemarks,
    String? status,
  }) {
    return SmsTransaction(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      message: message ?? this.message,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      accountNumber: accountNumber ?? this.accountNumber,
      merchant: merchant ?? this.merchant,
      balance: balance ?? this.balance,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      userRemarks: userRemarks ?? this.userRemarks,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'SmsTransaction(bank: $bankName, amount: $amount, type: $transactionType, date: $formattedDate, status: $status)';
  }
} 