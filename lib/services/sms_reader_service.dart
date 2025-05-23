import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import '../models/sms_transaction.dart';

class SmsReaderService {
  final Telephony telephony = Telephony.instance;

  // Request SMS permissions
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status == PermissionStatus.granted;
  }

  // Check if SMS permission is granted
  Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }

  // Read all SMS messages and filter bank transactions
  Future<List<SmsTransaction>> getAllBankTransactions() async {
    if (!await hasSmsPermission()) {
      throw Exception('SMS permission not granted');
    }

    try {
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      List<SmsTransaction> transactions = [];
      
      for (var message in messages) {
        final transaction = _parseTransactionFromSms(message);
        if (transaction != null) {
          transactions.add(transaction);
        }
      }

      return transactions;
    } catch (e) {
      throw Exception('Failed to read SMS: $e');
    }
  }

  // Get only Yes Bank transactions
  Future<List<SmsTransaction>> getYesBankTransactions() async {
    final allTransactions = await getAllBankTransactions();
    return allTransactions
        .where((transaction) => transaction.bankName.toLowerCase().contains('yes'))
        .toList();
  }

  // Get transactions for a specific account number
  Future<List<SmsTransaction>> getTransactionsForAccount(String accountNumber) async {
    if (!await hasSmsPermission()) {
      throw Exception('SMS permission not granted');
    }

    try {
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      List<SmsTransaction> transactions = [];
      
      for (var message in messages) {
        final transaction = _parseTransactionFromSms(message);
        if (transaction != null && _isAccountMatch(transaction, accountNumber)) {
          transactions.add(transaction);
        }
      }

      return transactions;
    } catch (e) {
      throw Exception('Failed to read SMS: $e');
    }
  }

  // Check if transaction belongs to the specified account
  bool _isAccountMatch(SmsTransaction transaction, String userAccountNumber) {
    final extractedAccountNumber = transaction.accountNumber;
    
    if (extractedAccountNumber == null) return false;
    
    // Remove any asterisks and special characters, keep only digits
    final cleanExtracted = extractedAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanUser = userAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If either is empty after cleaning, no match
    if (cleanExtracted.isEmpty || cleanUser.isEmpty) return false;
    
    // Get last 4 digits from both
    final last4Extracted = cleanExtracted.length >= 4 
        ? cleanExtracted.substring(cleanExtracted.length - 4)
        : cleanExtracted;
    final last4User = cleanUser.length >= 4 
        ? cleanUser.substring(cleanUser.length - 4)
        : cleanUser;
    
    // Compare last 4 digits
    return last4Extracted == last4User;
  }

  // Parse SMS message to extract transaction details
  SmsTransaction? _parseTransactionFromSms(SmsMessage message) {
    final body = message.body ?? '';
    final address = message.address ?? '';
    final date = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);

    // Check if this is a bank transaction SMS
    if (!_isBankTransactionSms(body, address)) {
      return null;
    }

    final bankName = _extractBankName(body, address);
    final amount = _extractAmount(body);
    final transactionType = _extractTransactionType(body);
    final accountNumber = _extractAccountNumber(body);
    final merchant = _extractMerchant(body);
    final balance = _extractBalance(body);
    final referenceNumber = _extractReferenceNumber(body);

    return SmsTransaction(
      id: '${message.date}_${message.address}',
      bankName: bankName,
      message: body,
      date: date,
      amount: amount,
      transactionType: transactionType,
      accountNumber: accountNumber,
      merchant: merchant,
      balance: balance,
      referenceNumber: referenceNumber,
    );
  }

  // Check if SMS is a bank transaction
  bool _isBankTransactionSms(String body, String address) {
    final bankKeywords = [
      'debited', 'credited', 'withdrawn', 'deposited', 'transaction',
      'balance', 'account', 'bank', 'atm', 'upi', 'neft', 'rtgs',
      'yes bank', 'yesbank', 'YESBNK'
    ];

    final bodyLower = body.toLowerCase();
    return bankKeywords.any((keyword) => bodyLower.contains(keyword)) ||
           _isKnownBankSender(address);
  }

  // Check if sender is a known bank
  bool _isKnownBankSender(String address) {
    final bankSenders = [
      'YESBNK', 'YESBANK', 'YES-BANK',
      'HDFC', 'ICICI', 'AXIS', 'SBI', 'KOTAK'
    ];
    
    return bankSenders.any((sender) => 
        address.toUpperCase().contains(sender));
  }

  // Extract bank name from SMS
  String _extractBankName(String body, String address) {
    // Check address first
    if (address.toUpperCase().contains('YES')) {
      return 'Yes Bank';
    }
    
    // Check body content
    final bodyUpper = body.toUpperCase();
    if (bodyUpper.contains('YES BANK') || bodyUpper.contains('YESBANK')) {
      return 'Yes Bank';
    } else if (bodyUpper.contains('HDFC')) {
      return 'HDFC Bank';
    } else if (bodyUpper.contains('ICICI')) {
      return 'ICICI Bank';
    } else if (bodyUpper.contains('AXIS')) {
      return 'Axis Bank';
    } else if (bodyUpper.contains('SBI')) {
      return 'State Bank of India';
    } else if (bodyUpper.contains('KOTAK')) {
      return 'Kotak Bank';
    }
    
    return 'Unknown Bank';
  }

  // Extract amount from SMS using regex
  double? _extractAmount(String body) {
    // Common patterns for amount in Indian banking SMS
    final patterns = [
      r'(?:rs\.?|inr|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
      r'(\d+(?:,\d+)*(?:\.\d{2})?)\s*(?:rs\.?|inr|₹)',
      r'amount\s*(?:rs\.?|inr|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
      r'(?:debited|credited|withdrawn|deposited)\s*(?:rs\.?|inr|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(body);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        return double.tryParse(amountStr ?? '');
      }
    }
    return null;
  }

  // Extract transaction type (debit/credit)
  String? _extractTransactionType(String body) {
    final bodyLower = body.toLowerCase();
    if (bodyLower.contains('debited') || bodyLower.contains('withdrawn') || 
        bodyLower.contains('spent') || bodyLower.contains('paid')) {
      return 'debit';
    } else if (bodyLower.contains('credited') || bodyLower.contains('deposited') || 
               bodyLower.contains('received')) {
      return 'credit';
    }
    return null;
  }

  // Extract account number
  String? _extractAccountNumber(String body) {
    // Enhanced patterns for account number extraction
    final patterns = [
      // Common patterns: a/c, account, acc followed by number
      r'(?:a\/c|account|acc)(?:\s*no\.?)?(?:\s*:)?\s*(\*+\d+|\d{4,})',
      // Account ending with specific digits
      r'(?:a\/c|account|acc)(?:\s*no\.?)?(?:\s*:)?\s*(?:\*+)?(\d{4})',
      // Pattern like "XX1234" or "XXXX1234" 
      r'(?:XX|xx|\*{2,})(\d{4})',
      // Pattern with asterisks followed by last 4 digits
      r'\*+(\d{4})',
      // Direct 4 digit pattern when preceded by account-related words
      r'(?:a\/c|account|acc|card)(?:\s*no\.?)?(?:\s*:)?\s*(?:\*+)?(\d{4})',
      // Pattern like "ending 1234"
      r'(?:ending|last)\s+(?:with\s+)?(\d{4})',
      // Account number in various formats
      r'(?:account|a\/c|acc)\s*(?:number|no\.?|#)?\s*(?:is\s*)?(?:\*+)?(\d{4,})',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(body);
      if (match != null) {
        String? accountNum = match.group(1);
        if (accountNum != null && accountNum.length >= 4) {
          return accountNum.length > 4 ? accountNum.substring(accountNum.length - 4) : accountNum;
        }
      }
    }
    
    // Fallback: look for any 4-digit number in the message
    final fallbackRegex = RegExp(r'\b(\d{4})\b');
    final matches = fallbackRegex.allMatches(body);
    if (matches.isNotEmpty) {
      // Return the last 4-digit number found (usually account number)
      return matches.last.group(1);
    }
    
    return null;
  }

  // Extract merchant/vendor name
  String? _extractMerchant(String body) {
    final patterns = [
      r'(?:at|to|from)\s+([A-Z\s]+?)(?:\s+on|\s+\d|$)',
      r'(?:merchant|vendor)(?:\s*:)?\s*([A-Z\s]+?)(?:\s+on|\s+\d|$)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(body);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  // Extract balance
  double? _extractBalance(String body) {
    final regex = RegExp(r'(?:balance|bal)(?:\s*:)?\s*(?:rs\.?|inr|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)', caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      final balanceStr = match.group(1)?.replaceAll(',', '');
      return double.tryParse(balanceStr ?? '');
    }
    return null;
  }

  // Extract reference number
  String? _extractReferenceNumber(String body) {
    final patterns = [
      r'(?:ref|reference|txn|transaction)(?:\s*no\.?)?(?:\s*:)?\s*([A-Z0-9]+)',
      r'(?:utr|rrn)(?:\s*:)?\s*([A-Z0-9]+)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(body);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }
} 