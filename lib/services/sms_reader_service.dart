import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import '../models/sms_transaction.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

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

  // Create consistent SMS ID based on content hash + date + sender
  String _createSmsId(SmsMessage message) {
    final body = message.body ?? '';
    final address = message.address ?? '';
    final date = message.date?.toString() ?? '0';
    
    // Create a unique string combining message content, sender, and timestamp
    final uniqueString = '$body|$address|$date';
    
    // Generate MD5 hash for consistent ID
    final bytes = utf8.encode(uniqueString);
    final hash = md5.convert(bytes);
    
    return 'sms_${hash.toString()}';
  }

  // Get new SMS messages since a specific date
  Future<List<SmsTransaction>> getNewSmsTransactionsSince(DateTime? lastProcessedDate, String accountNumber) async {
    if (!await hasSmsPermission()) {
      throw Exception('SMS permission not granted');
    }

    try {
      print('📱 Reading SMS messages since: ${lastProcessedDate?.toIso8601String() ?? "beginning"}');
      
      // Get all SMS messages (we'll filter by date ourselves)
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      print('📬 Found ${messages.length} total SMS messages');
      List<SmsTransaction> newTransactions = [];
      int processedCount = 0;
      int newCount = 0;
      
      for (var message in messages) {
        final messageDate = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);
        
        // Skip messages older than last processed date
        if (lastProcessedDate != null && messageDate.isBefore(lastProcessedDate)) {
          continue;
        }
        
        processedCount++;
        
        final transaction = _parseTransactionFromSms(message);
        if (transaction != null && _isAccountMatch(transaction, accountNumber)) {
          newTransactions.add(transaction);
          newCount++;
          print('✅ Found new matching SMS: ${transaction.formattedAmount} on ${DateFormat('dd-MMM-yy').format(transaction.date)}');
        }
      }

      print('📊 Processed $processedCount messages since last check, found $newCount new matching transactions');
      return newTransactions;
    } catch (e) {
      print('❌ Failed to read new SMS: $e');
      throw Exception('Failed to read new SMS: $e');
    }
  }

  // Read all SMS messages and filter bank transactions (original method for backward compatibility)
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
      print('📱 Reading SMS messages for account: $accountNumber');
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      print('📬 Found ${messages.length} total SMS messages');
      List<SmsTransaction> transactions = [];
      int bankSmsCount = 0;
      int matchedTransactions = 0;
      
      for (var message in messages) {
        final transaction = _parseTransactionFromSms(message);
        if (transaction != null) {
          bankSmsCount++;
          print('🏦 Found bank SMS from ${transaction.bankName}: ${transaction.formattedAmount} on ${DateFormat('dd-MMM-yy').format(transaction.date)}');
          print('   Account extracted: ${transaction.accountNumber}');
          
          if (_isAccountMatch(transaction, accountNumber)) {
            matchedTransactions++;
            transactions.add(transaction);
            print('✅ Account MATCHED! Added to results');
          } else {
            print('❌ Account NOT matched (user: $accountNumber, extracted: ${transaction.accountNumber})');
          }
        }
      }

      print('📊 Summary: $bankSmsCount bank SMS found, $matchedTransactions matched for account $accountNumber');
      return transactions;
    } catch (e) {
      print('❌ Failed to read SMS: $e');
      throw Exception('Failed to read SMS: $e');
    }
  }

  // Check if transaction belongs to the specified account
  bool _isAccountMatch(SmsTransaction transaction, String userAccountNumber) {
    final extractedAccountNumber = transaction.accountNumber;
    
    if (extractedAccountNumber == null) {
      print('   ⚠️ No account number extracted from SMS');
      return false;
    }
    
    // Remove any asterisks and special characters, keep only digits
    final cleanExtracted = extractedAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanUser = userAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    print('   🔍 Comparing accounts: extracted="$cleanExtracted", user="$cleanUser"');
    
    // If either is empty after cleaning, no match
    if (cleanExtracted.isEmpty || cleanUser.isEmpty) {
      print('   ❌ One account number is empty after cleaning');
      return false;
    }
    
    // Get last 4 digits from both
    final last4Extracted = cleanExtracted.length >= 4 
        ? cleanExtracted.substring(cleanExtracted.length - 4)
        : cleanExtracted;
    final last4User = cleanUser.length >= 4 
        ? cleanUser.substring(cleanUser.length - 4)
        : cleanUser;
    
    print('   🔢 Last 4 digits: extracted="$last4Extracted", user="$last4User"');
    
    // Compare last 4 digits
    final isMatch = last4Extracted == last4User;
    print('   ${isMatch ? "✅" : "❌"} Match result: $isMatch');
    
    return isMatch;
  }

  // Parse SMS message to extract transaction details
  SmsTransaction? _parseTransactionFromSms(SmsMessage message) {
    final body = message.body ?? '';
    final address = message.address ?? '';
    final messageDate = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);

    print('\n📨 Parsing SMS from $address on ${DateFormat('dd-MMM-yy HH:mm').format(messageDate)}');
    print('   Content: ${body.length > 150 ? body.substring(0, 150) + "..." : body}');

    // Check if this is a bank transaction SMS
    if (!_isBankTransactionSms(body, address)) {
      print('   ❌ Not identified as bank transaction SMS');
      return null;
    }

    print('   ✅ Identified as bank transaction SMS');

    final bankName = _extractBankName(body, address);
    final amount = _extractAmount(body);
    final transactionType = _extractTransactionType(body);
    final accountNumber = _extractAccountNumber(body);
    final merchant = _extractMerchant(body);
    final balance = _extractBalance(body);
    final referenceNumber = _extractReferenceNumber(body);
    
    // Try to extract transaction date from SMS content
    final transactionDate = _extractTransactionDate(body) ?? messageDate;

    // Generate consistent ID
    final smsId = _createSmsId(message);

    print('   💰 Amount: ₹$amount ($transactionType)');
    print('   🏪 Merchant: $merchant');
    print('   📅 Transaction Date: ${DateFormat('dd-MMM-yy').format(transactionDate)}');
    print('   📋 Reference: $referenceNumber');
    print('   🆔 SMS ID: $smsId');

    return SmsTransaction(
      id: smsId, // Use consistent ID instead of timestamp-based
      bankName: bankName,
      message: body,
      date: transactionDate,
      amount: amount,
      transactionType: transactionType,
      accountNumber: accountNumber,
      merchant: merchant,
      balance: balance,
      referenceNumber: referenceNumber,
    );
  }

  // Extract transaction date from SMS content
  DateTime? _extractTransactionDate(String body) {
    // Common Indian banking SMS date patterns
    final patterns = [
      // Pattern: 24MAY25, 24MAY2024 (no separators)
      r'(\d{1,2})([A-Z]{3})(\d{2,4})',
      // Pattern: 24-May-25, 24-May-2024
      r'(\d{1,2})-([A-Z][a-z]{2})-(\d{2,4})',
      // Pattern: 24/05/24, 24/05/2024
      r'(\d{1,2})\/(\d{1,2})\/(\d{2,4})',
      // Pattern: 24.05.24, 24.05.2024
      r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})',
      // Pattern: May 24, 2024
      r'([A-Z][a-z]{2})\s+(\d{1,2}),?\s+(\d{4})',
      // Pattern: 24 May 2024
      r'(\d{1,2})\s+([A-Z][a-z]{2})\s+(\d{4})',
      // Pattern: on 24-May-24 at
      r'on\s+(\d{1,2})-([A-Z][a-z]{2})-(\d{2,4})\s+at',
      // Pattern: on 24MAY25
      r'on\s+(\d{1,2})([A-Z]{3})(\d{2,4})',
    ];

    final monthNames = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(body);
      
      if (match != null) {
        try {
          if (pattern.contains('([A-Z]{3})') || pattern.contains('([A-Z][a-z]{2})')) {
            // Date with month name/abbreviation
            if (pattern.contains('([A-Z][a-z]{2})\\s+(\\d{1,2})')) {
              // Pattern: May 24, 2024
              final monthStr = match.group(1)?.toLowerCase();
              final day = int.tryParse(match.group(2) ?? '');
              final year = int.tryParse(match.group(3) ?? '');
              
              if (monthStr != null && day != null && year != null) {
                final month = monthNames[monthStr];
                if (month != null) {
                  return DateTime(year, month, day);
                }
              }
            } else {
              // Pattern: 24-May-25, 24MAY25, 24 May 2024
              final day = int.tryParse(match.group(1) ?? '');
              final monthStr = match.group(2)?.toLowerCase();
              var year = int.tryParse(match.group(3) ?? '');
              
              if (day != null && monthStr != null && year != null) {
                final month = monthNames[monthStr];
                if (month != null) {
                  // Convert 2-digit year to 4-digit
                  if (year < 100) {
                    // For years 00-30, assume 2000s; for 31-99, assume 1900s
                    year += (year <= 30) ? 2000 : 1900;
                  }
                  print('   📅 Parsed date: $day-$monthStr-$year -> ${DateTime(year, month, day)}');
                  return DateTime(year, month, day);
                }
              }
            }
          } else {
            // Numeric date pattern
            final day = int.tryParse(match.group(1) ?? '');
            final month = int.tryParse(match.group(2) ?? '');
            var year = int.tryParse(match.group(3) ?? '');
            
            if (day != null && month != null && year != null) {
              // Convert 2-digit year to 4-digit
              if (year < 100) {
                // For years 00-30, assume 2000s; for 31-99, assume 1900s
                year += (year <= 30) ? 2000 : 1900;
              }
              
              if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
                print('   📅 Parsed numeric date: $day/$month/$year -> ${DateTime(year, month, day)}');
                return DateTime(year, month, day);
              }
            }
          }
        } catch (e) {
          print('Error parsing date from SMS: $e');
          continue;
        }
      }
    }
    
    print('   ❌ No transaction date found in SMS body');
    return null;
  }

  // Check if SMS is a bank transaction
  bool _isBankTransactionSms(String body, String address) {
    final bankKeywords = [
      'debited', 'credited', 'withdrawn', 'deposited', 'transaction',
      'balance', 'account', 'bank', 'atm', 'upi', 'neft', 'rtgs',
      'yes bank', 'yesbank', 'YESBNK', 'avbl bal', 'avl bal',
      'available balance', 'current balance', 'ref', 'txn'
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
    print('   🔍 Extracting account number from: ${body.substring(0, body.length > 100 ? 100 : body.length)}...');
    
    // Enhanced patterns for account number extraction - ordered by priority
    final patterns = [
      // YES Bank format: "Ac X1069" or "A/c XX1234"
      r'(?:ac|a\/c)\s+(?:X+|x+|\*+)(\d{4})',
      // Standard format: "Your A/c 1234567890" 
      r'(?:your\s+)?(?:a\/c|account|acc)(?:\s*no\.?)?(?:\s*:)?\s*(\d{4,})',
      // Pattern with asterisks: A/c ***1234
      r'(?:a\/c|account|acc)(?:\s*no\.?)?(?:\s*:)?\s*\*+(\d{4})',
      // Pattern like "XX1234" or "XXXX1234" at start of account reference
      r'(?:^|\s)(?:XX|xx|\*{2,})(\d{4})(?:\s|$)',
      // Pattern like "ending 1234" or "ending with 1234"
      r'(?:ending|last)(?:\s+with)?\s+(\d{4})',
      // Direct 4+ digit patterns when preceded by account-related words
      r'(?:a\/c|account|acc|card)(?:\s*no\.?)?(?:\s*:)?\s*(\d{4,})',
      // Account number in various formats with full number
      r'(?:account|a\/c|acc)\s*(?:number|no\.?|#)?\s*(?:is\s*)?(\d{4,})',
      // Pattern: debited by Rs.X on DATE at MERCHANT. Account: 1234567890
      r'(?:account|a\/c|acc)(?:\s*:)?\s*(\d{4,})',
      // Look for numbers that appear to be account numbers (10-16 digits) - but not UPI IDs
      r'(?<!UPI:)(?<!\/)(\d{10,16})(?!@)',
      // Fallback: any 4-digit sequence that might be last 4 digits - but avoid UPI patterns
      r'(?<!UPI:)(?<!/)(\d{4})(?!@|\/)',
    ];

    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final regex = RegExp(pattern, caseSensitive: false);
      final matches = regex.allMatches(body);
      
      for (final match in matches) {
        String? accountNum = match.group(1);
        if (accountNum != null && accountNum.length >= 4) {
          
          // Skip if this looks like a UPI transaction ID (starts with certain patterns)
          if (accountNum.startsWith('2070') || accountNum.startsWith('8886') || accountNum.length > 16) {
            continue;
          }
          
          // For high-priority patterns (0-4), prefer 4-digit matches
          if (i <= 4) {
            if (accountNum.length == 4) {
              print('   ✅ Found 4-digit account (high priority pattern $i): $accountNum');
              return accountNum;
            } else if (accountNum.length >= 10) {
              // Extract last 4 digits from full account number
              final last4 = accountNum.substring(accountNum.length - 4);
              print('   ✅ Found full account number (high priority pattern $i): $accountNum -> last 4: $last4');
              return last4;
            }
          } else {
            // For lower priority patterns, be more selective
            if (accountNum.length == 4) {
              print('   ✅ Found 4-digit account (pattern $i): $accountNum');
              return accountNum;
            } else if (accountNum.length >= 10 && accountNum.length <= 16) {
              // Extract last 4 digits from full account number
              final last4 = accountNum.substring(accountNum.length - 4);
              print('   ✅ Found long number (pattern $i): $accountNum -> last 4: $last4');
              return last4;
            }
          }
        }
      }
    }
    
    print('   ❌ No account number found in SMS');
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
    print('   🔍 Extracting reference number from SMS...');
    
    final patterns = [
      // Enhanced patterns for transaction references
      // NEFT pattern: NEFT:675656/ or NEFT-675656 or NEFT 675656
      r'NEFT[:\-\s]+([A-Z0-9]+)(?:\/|$|\s)',
      // UPI pattern: UPI:123456/ or UPI-123456 or UPI 123456
      r'UPI[:\-\s]+([A-Z0-9]+)(?:\/|$|\s)',
      // IMPS pattern: IMPS:789012/ or IMPS-789012 or IMPS 789012
      r'IMPS[:\-\s]+([A-Z0-9]+)(?:\/|$|\s)',
      // RTGS pattern: RTGS:456789/ or RTGS-456789 or RTGS 456789
      r'RTGS[:\-\s]+([A-Z0-9]+)(?:\/|$|\s)',
      // General transaction ID patterns
      r'(?:ref|reference|txn|transaction)(?:\s*no\.?)?(?:\s*[:\-])?\s*([A-Z0-9]{6,})',
      r'(?:utr|rrn)(?:\s*[:\-])?\s*([A-Z0-9]{6,})',
      // Transaction ID in format: TXN ID: 123456789
      r'(?:txn\s*id|transaction\s*id)(?:\s*[:\-])?\s*([A-Z0-9]{6,})',
      // Reference number in format: Ref No: ABC123456
      r'(?:ref\s*no|reference\s*no)(?:\s*[:\-])?\s*([A-Z0-9]{6,})',
      // Bank specific patterns
      r'(?:bank\s*ref|bank\s*reference)(?:\s*[:\-])?\s*([A-Z0-9]{6,})',
      // Generic alphanumeric patterns that look like transaction IDs (6+ chars)
      r'(?:^|\s)([A-Z0-9]{8,})(?:\s|$)',
    ];

    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final regex = RegExp(pattern, caseSensitive: false);
      final matches = regex.allMatches(body);
      
      for (final match in matches) {
        String? refNumber = match.group(1);
        if (refNumber != null && refNumber.length >= 6) {
          
          // Skip if this looks like an account number or phone number
          if (refNumber.length == 10 && refNumber.startsWith(RegExp(r'[6-9]'))) {
            continue; // Likely a phone number
          }
          
          // Skip if this is just numbers and looks like amount or account
          if (refNumber.length <= 8 && RegExp(r'^\d+$').hasMatch(refNumber)) {
            final numValue = int.tryParse(refNumber);
            if (numValue != null && numValue < 1000000) {
              continue; // Likely an amount or short number
            }
          }
          
          // Prefer transaction type specific patterns (NEFT, UPI, IMPS, RTGS)
          if (i <= 3) {
            print('   ✅ Found transaction reference (${pattern.split('[')[0]}): $refNumber');
            return refNumber;
          } else if (refNumber.length >= 8) {
            print('   ✅ Found reference number (pattern $i): $refNumber');
            return refNumber;
          }
        }
      }
    }
    
    print('   ❌ No reference number found in SMS');
    return null;
  }
} 