class Account {
  final String id;
  final String accountNumber;
  final String bankName;
  final double totalBudget;
  final double currentBalance;
  final DateTime createdAt;
  final bool isActive;

  Account({
    required this.id,
    required this.accountNumber,
    required this.bankName,
    required this.totalBudget,
    required this.currentBalance,
    required this.createdAt,
    this.isActive = true,
  });

  // Get masked account number (show only last 4 digits)
  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }

  // Get formatted balance
  String get formattedBalance => '₹${currentBalance.toStringAsFixed(2)}';

  // Get formatted budget
  String get formattedBudget => '₹${totalBudget.toStringAsFixed(2)}';

  // Copy with method for updates
  Account copyWith({
    String? id,
    String? accountNumber,
    String? bankName,
    double? totalBudget,
    double? currentBalance,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return Account(
      id: id ?? this.id,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      totalBudget: totalBudget ?? this.totalBudget,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'totalBudget': totalBudget,
      'currentBalance': currentBalance,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  // Create from Map
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      bankName: map['bankName'] ?? '',
      totalBudget: (map['totalBudget'] ?? 0.0).toDouble(),
      currentBalance: (map['currentBalance'] ?? 0.0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      isActive: map['isActive'] ?? true,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, bank: $bankName, account: $maskedAccountNumber, balance: $formattedBalance)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 