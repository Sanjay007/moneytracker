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
} 