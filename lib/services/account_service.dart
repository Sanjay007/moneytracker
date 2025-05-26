import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';

class AccountService {
  static const String _accountsKey = 'user_accounts';
  static const String _activeAccountKey = 'active_account_id';

  // Get all accounts
  Future<List<Account>> getAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getStringList(_accountsKey) ?? [];
    
    return accountsJson.map((json) {
      final Map<String, dynamic> map = jsonDecode(json);
      return Account.fromMap(map);
    }).toList();
  }

  // Get active account
  Future<Account?> getActiveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final activeAccountId = prefs.getString(_activeAccountKey);
    
    if (activeAccountId == null) return null;
    
    final accounts = await getAllAccounts();
    try {
      return accounts.firstWhere((account) => account.id == activeAccountId);
    } catch (e) {
      return null;
    }
  }

  // Check if any account exists
  Future<bool> hasAnyAccount() async {
    final accounts = await getAllAccounts();
    return accounts.isNotEmpty;
  }

  // Save account
  Future<void> saveAccount(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAllAccounts();
    
    // Remove existing account with same ID if any
    accounts.removeWhere((acc) => acc.id == account.id);
    
    // Add new account
    accounts.add(account);
    
    // Convert to JSON strings
    final accountsJson = accounts.map((acc) => jsonEncode(acc.toMap())).toList();
    
    // Save to SharedPreferences
    await prefs.setStringList(_accountsKey, accountsJson);
    
    // If this is the first account, make it active
    if (accounts.length == 1) {
      await setActiveAccount(account.id);
    }
  }

  // Set active account
  Future<void> setActiveAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeAccountKey, accountId);
  }

  // Update account balance
  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    final accounts = await getAllAccounts();
    final accountIndex = accounts.indexWhere((acc) => acc.id == accountId);
    
    if (accountIndex != -1) {
      final updatedAccount = accounts[accountIndex].copyWith(currentBalance: newBalance);
      accounts[accountIndex] = updatedAccount;
      
      // Save updated accounts
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = accounts.map((acc) => jsonEncode(acc.toMap())).toList();
      await prefs.setStringList(_accountsKey, accountsJson);
    }
  }

  // Delete account
  Future<void> deleteAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAllAccounts();
    
    accounts.removeWhere((acc) => acc.id == accountId);
    
    // Save updated accounts
    final accountsJson = accounts.map((acc) => jsonEncode(acc.toMap())).toList();
    await prefs.setStringList(_accountsKey, accountsJson);
    
    // If deleted account was active, set new active account
    final activeAccountId = prefs.getString(_activeAccountKey);
    if (activeAccountId == accountId) {
      if (accounts.isNotEmpty) {
        await setActiveAccount(accounts.first.id);
      } else {
        await prefs.remove(_activeAccountKey);
      }
    }
  }

  // Get supported banks list
  List<String> getSupportedBanks() {
    return [
      'Yes Bank',
      'HDFC Bank',
      'ICICI Bank',
      'Axis Bank',
      'State Bank of India',
      'Kotak Mahindra Bank',
      'Punjab National Bank',
      'Bank of Baroda',
      'Canara Bank',
      'Union Bank of India',
      'IDFC First Bank',
      'IndusInd Bank',
      'Central Bank of India',
      'Indian Overseas Bank',
      'UCO Bank',
      'Bank of India',
      'Other',
    ];
  }

  // Generate unique account ID
  String generateAccountId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Clear all accounts (for testing/reset)
  Future<void> clearAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
    await prefs.remove(_activeAccountKey);
  }

  // Update account balance based on SMS transactions
  Future<void> updateBalanceFromSmsTransactions(String accountId, List<dynamic> smsTransactions) async {
    if (smsTransactions.isEmpty) return;
    
    try {
      print('💰 Updating account balance from ${smsTransactions.length} SMS transactions');
      
      // Sort transactions by date (newest first)
      smsTransactions.sort((a, b) {
        DateTime dateA = a is Map ? DateTime.parse(a['date']) : a.date;
        DateTime dateB = b is Map ? DateTime.parse(b['date']) : b.date;
        return dateB.compareTo(dateA);
      });
      
      // Method 1: Try to find the latest SMS with balance information
      double? latestBalance = _extractLatestBalanceFromSms(smsTransactions);
      
      if (latestBalance != null) {
        print('✅ Found latest balance from SMS: ₹$latestBalance');
        await updateAccountBalance(accountId, latestBalance);
        return;
      }
      
      // Method 2: Calculate balance by applying transactions to current balance
      print('⚠️ No balance found in SMS, calculating from transactions...');
      await _calculateBalanceFromTransactions(accountId, smsTransactions);
      
    } catch (e) {
      print('❌ Error updating balance from SMS: $e');
    }
  }
  
  // Extract the latest balance from SMS transactions
  double? _extractLatestBalanceFromSms(List<dynamic> smsTransactions) {
    for (var transaction in smsTransactions) {
      double? balance;
      
      if (transaction is Map) {
        // Handle database SMS transaction
        final rawMessage = transaction['rawMessage'] as String?;
        if (rawMessage != null) {
          balance = _parseBalanceFromSmsText(rawMessage);
        }
      } else {
        // Handle SmsTransaction object
        if (transaction.balance != null) {
          balance = transaction.balance;
        } else {
          balance = _parseBalanceFromSmsText(transaction.message);
        }
      }
      
      if (balance != null) {
        print('💰 Found balance in SMS: ₹$balance');
        return balance;
      }
    }
    
    return null;
  }
  
  // Parse balance from SMS text
  double? _parseBalanceFromSmsText(String smsText) {
    final patterns = [
      // Available balance patterns
      r'(?:avl|available|avail)\s*(?:bal|balance)(?:\s*:)?\s*(?:rs\.?|inr|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
      r'(?:bal|balance)(?:\s*:)?\s*(?:rs\.?|inr|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
      // Current balance patterns
      r'(?:current|curr)\s*(?:bal|balance)(?:\s*:)?\s*(?:rs\.?|inr|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
      // Balance after transaction
      r'(?:balance|bal)\s*(?:after|is|now)(?:\s*:)?\s*(?:rs\.?|inr|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
      // Remaining balance
      r'(?:remaining|rem)\s*(?:bal|balance)(?:\s*:)?\s*(?:rs\.?|inr|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(smsText);
      if (match != null) {
        final balanceStr = match.group(1)?.replaceAll(',', '');
        final balance = double.tryParse(balanceStr ?? '');
        if (balance != null) {
          return balance;
        }
      }
    }
    
    return null;
  }
  
  // Calculate balance by applying transactions to current balance
  Future<void> _calculateBalanceFromTransactions(String accountId, List<dynamic> smsTransactions) async {
    final account = await getActiveAccount();
    if (account == null || account.id != accountId) return;
    
    double currentBalance = account.currentBalance;
    print('💰 Starting balance: ₹$currentBalance');
    
    // Apply transactions in chronological order (oldest first)
    final reversedTransactions = smsTransactions.reversed.toList();
    
    for (var transaction in reversedTransactions) {
      double? amount;
      String? transactionType;
      DateTime? transactionDate;
      
      if (transaction is Map) {
        amount = transaction['amount']?.toDouble();
        transactionType = transaction['transactionType'];
        transactionDate = DateTime.tryParse(transaction['date'] ?? '');
      } else {
        amount = transaction.amount;
        transactionType = transaction.transactionType;
        transactionDate = transaction.date;
      }
      
      if (amount != null && transactionType != null) {
        if (transactionType.toLowerCase() == 'debit') {
          currentBalance -= amount;
          print('💸 Applied debit: -₹$amount, new balance: ₹$currentBalance');
        } else if (transactionType.toLowerCase() == 'credit') {
          currentBalance += amount;
          print('💰 Applied credit: +₹$amount, new balance: ₹$currentBalance');
        }
      }
    }
    
    print('✅ Final calculated balance: ₹$currentBalance');
    await updateAccountBalance(accountId, currentBalance);
  }
  
  // Update balance from latest accepted SMS transaction
  Future<void> updateBalanceFromLatestAcceptedSms(String accountId) async {
    try {
      // This would need to be called with database service
      // For now, we'll add this as a placeholder that can be called from the SMS screen
      print('🔄 Updating balance from latest accepted SMS for account: $accountId');
    } catch (e) {
      print('❌ Error updating balance from latest SMS: $e');
    }
  }
} 