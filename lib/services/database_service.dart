import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/database_models.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._internal();

  static DatabaseService get instance {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'moneytracker.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create accounts table
        await db.execute('''
          CREATE TABLE accounts(
            id TEXT PRIMARY KEY,
            accountNumber TEXT NOT NULL,
            bankName TEXT NOT NULL,
            totalBudget REAL NOT NULL,
            currentBalance REAL NOT NULL,
            createdAt TEXT NOT NULL,
            isActive INTEGER NOT NULL
          )
        ''');

        // Create transactions table
        await db.execute('''
          CREATE TABLE transactions(
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            remarks TEXT NOT NULL,
            date TEXT NOT NULL,
            categoryName TEXT NOT NULL,
            categoryIconCodePoint INTEGER NOT NULL,
            categoryColorValue INTEGER NOT NULL,
            accountId TEXT NOT NULL,
            merchant TEXT,
            referenceNumber TEXT,
            type TEXT NOT NULL,
            source TEXT NOT NULL,
            FOREIGN KEY (accountId) REFERENCES accounts (id)
          )
        ''');

        // Create budget_categories table
        await db.execute('''
          CREATE TABLE budget_categories(
            name TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            iconCodePoint INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            isDefault INTEGER NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');

        // Create sms_transactions table
        await db.execute('''
          CREATE TABLE sms_transactions(
            id TEXT PRIMARY KEY,
            rawMessage TEXT NOT NULL,
            bankName TEXT,
            accountNumber TEXT,
            amount REAL,
            transactionType TEXT,
            date TEXT NOT NULL,
            merchant TEXT,
            referenceNumber TEXT,
            userRemarks TEXT,
            status TEXT NOT NULL
          )
        ''');

        // Create app_settings table for storing configuration
        await db.execute('''
          CREATE TABLE app_settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Insert default categories
        await _insertDefaultCategories(db);
      },
    );
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final categories = [
      BudgetCategoryDB(
        name: 'Food',
        amount: 0,
        iconCodePoint: Icons.restaurant.codePoint,
        colorValue: Colors.orange.value,
        isDefault: true,
        createdAt: DateTime.now(),
      ),
      BudgetCategoryDB(
        name: 'Transportation',
        amount: 0,
        iconCodePoint: Icons.directions_car.codePoint,
        colorValue: Colors.blue.value,
        isDefault: true,
        createdAt: DateTime.now(),
      ),
      BudgetCategoryDB(
        name: 'Entertainment',
        amount: 0,
        iconCodePoint: Icons.movie.codePoint,
        colorValue: Colors.purple.value,
        isDefault: true,
        createdAt: DateTime.now(),
      ),
      BudgetCategoryDB(
        name: 'Shopping',
        amount: 0,
        iconCodePoint: Icons.shopping_bag.codePoint,
        colorValue: Colors.green.value,
        isDefault: true,
        createdAt: DateTime.now(),
      ),
      BudgetCategoryDB(
        name: 'Health',
        amount: 0,
        iconCodePoint: Icons.local_hospital.codePoint,
        colorValue: Colors.red.value,
        isDefault: true,
        createdAt: DateTime.now(),
      ),
      BudgetCategoryDB(
        name: 'Education',
        amount: 0,
        iconCodePoint: Icons.school.codePoint,
        colorValue: Colors.indigo.value,
        isDefault: true,
        createdAt: DateTime.now(),
      ),
    ];

    for (final category in categories) {
      await db.insert('budget_categories', category.toMap());
    }
  }

  Future<void> initDatabase() async {
    await database;
  }

  Future<void> dispose() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // Account operations
  Future<void> insertAccount(AccountDB account) async {
    final db = await database;
    await db.insert('accounts', account.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AccountDB>> getAllAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('accounts', where: 'isActive = ?', whereArgs: [1]);
    return List.generate(maps.length, (i) => AccountDB.fromMap(maps[i]));
  }

  Future<AccountDB?> getAccountById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return AccountDB.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateAccount(AccountDB account) async {
    final db = await database;
    await db.update('accounts', account.toMap(), where: 'id = ?', whereArgs: [account.id]);
  }

  Future<void> deleteAccount(String id) async {
    final db = await database;
    await db.update('accounts', {'isActive': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // Transaction operations
  Future<void> insertTransaction(TransactionDB transaction) async {
    final db = await database;
    await db.insert('transactions', transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TransactionDB>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => TransactionDB.fromMap(maps[i]));
  }

  Future<List<TransactionDB>> getTransactionsForToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TransactionDB.fromMap(maps[i]));
  }

  Future<List<TransactionDB>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TransactionDB.fromMap(maps[i]));
  }

  Future<List<TransactionDB>> getTransactionsByAccount(String accountId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'accountId = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TransactionDB.fromMap(maps[i]));
  }

  // SMS Transaction operations
  Future<void> insertSmsTransaction(SmsTransactionDB smsTransaction) async {
    final db = await database;
    await db.insert('sms_transactions', smsTransaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // New method: Insert SMS transaction only if it doesn't exist
  Future<bool> insertNewSmsTransaction(SmsTransactionDB smsTransaction) async {
    final db = await database;
    
    // Check if SMS transaction already exists
    final existing = await getSmsTransactionById(smsTransaction.id);
    if (existing != null) {
      print('📝 SMS transaction already exists: ${smsTransaction.id}');
      return false; // Already exists
    }
    
    // Insert new SMS transaction
    await db.insert('sms_transactions', smsTransaction.toMap());
    print('✅ Inserted new SMS transaction: ${smsTransaction.id}');
    return true; // Successfully inserted
  }

  // New method: Get SMS transaction by ID
  Future<SmsTransactionDB?> getSmsTransactionById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return SmsTransactionDB.fromMap(maps.first);
    }
    return null;
  }

  Future<List<SmsTransactionDB>> getAllSmsTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sms_transactions', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => SmsTransactionDB.fromMap(maps[i]));
  }

  Future<List<SmsTransactionDB>> getSmsTransactionsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => SmsTransactionDB.fromMap(maps[i]));
  }

  Future<void> updateSmsTransactionStatus(String id, String status, {String? remarks}) async {
    final db = await database;
    final updateData = {'status': status};
    if (remarks != null) {
      updateData['userRemarks'] = remarks;
    }
    await db.update('sms_transactions', updateData, where: 'id = ?', whereArgs: [id]);
  }

  // New method: Get most recent SMS transaction date
  Future<DateTime?> getMostRecentSmsTransactionDate() async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'sms_transactions',
        orderBy: 'date DESC',
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        return DateTime.parse(maps.first['date']);
      }
    } catch (e) {
      print('❌ Error getting most recent SMS transaction date: $e');
    }
    
    return null;
  }

  // New method: Get last processed SMS date
  Future<DateTime?> getLastProcessedSmsDate() async {
    final db = await database;
    
    // First try to get from a settings table (we'll create this)
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['last_processed_sms_date'],
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        return DateTime.parse(maps.first['value']);
      }
    } catch (e) {
      // Table might not exist yet, fall back to most recent SMS date
      print('⚠️ App settings table not found, using most recent SMS date');
    }
    
    // Fallback to most recent SMS transaction date
    return await getMostRecentSmsTransactionDate();
  }

  // New method: Update last processed SMS date
  Future<void> updateLastProcessedSmsDate(DateTime date) async {
    final db = await database;
    
    try {
      await db.insert(
        'app_settings',
        {
          'key': 'last_processed_sms_date',
          'value': date.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('📅 Updated last processed SMS date: $date');
    } catch (e) {
      print('❌ Failed to update last processed SMS date: $e');
    }
  }

  // New method: Get count of new SMS transactions since last check
  Future<int> getNewSmsCount() async {
    final lastProcessed = await getLastProcessedSmsDate();
    if (lastProcessed == null) return 0;
    
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_transactions',
      where: 'date > ?',
      whereArgs: [lastProcessed.toIso8601String()],
    );
    
    return maps.length;
  }

  // Category operations
  Future<List<BudgetCategoryDB>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('budget_categories');
    return List.generate(maps.length, (i) => BudgetCategoryDB.fromMap(maps[i]));
  }

  Future<List<String>> getAvailableSmsTransactionDates() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT DATE(date) as date_only 
      FROM sms_transactions 
      ORDER BY date_only DESC
    ''');
    
    return maps.map((map) => map['date_only'] as String).toList();
  }

  // Get accepted SMS transactions for balance calculation
  Future<List<SmsTransactionDB>> getAcceptedSmsTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_transactions',
      where: 'status = ?',
      whereArgs: ['accepted'],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => SmsTransactionDB.fromMap(maps[i]));
  }

  // Get latest SMS transaction with balance information
  Future<SmsTransactionDB?> getLatestSmsWithBalance() async {
    final db = await database;
    
    // First try to get from accepted transactions
    final List<Map<String, dynamic>> acceptedMaps = await db.query(
      'sms_transactions',
      where: 'status = ? AND rawMessage LIKE ?',
      whereArgs: ['accepted', '%balance%'],
      orderBy: 'date DESC',
      limit: 1,
    );
    
    if (acceptedMaps.isNotEmpty) {
      return SmsTransactionDB.fromMap(acceptedMaps.first);
    }
    
    // If no accepted transactions with balance, try all transactions
    final List<Map<String, dynamic>> allMaps = await db.query(
      'sms_transactions',
      where: 'rawMessage LIKE ?',
      whereArgs: ['%balance%'],
      orderBy: 'date DESC',
      limit: 1,
    );
    
    if (allMaps.isNotEmpty) {
      return SmsTransactionDB.fromMap(allMaps.first);
    }
    
    return null;
  }

  // Update account balance based on latest SMS
  Future<void> updateAccountBalanceFromSms(String accountId) async {
    try {
      print('🔄 Updating account balance from SMS for account: $accountId');
      
      // Get the latest SMS transaction with balance information
      final latestSmsWithBalance = await getLatestSmsWithBalance();
      
      if (latestSmsWithBalance != null) {
        // Parse balance from the SMS message
        final balance = _parseBalanceFromSmsMessage(latestSmsWithBalance.rawMessage);
        
        if (balance != null) {
          print('💰 Found balance in latest SMS: ₹$balance');
          
          // Update account balance in the accounts table
          final db = await database;
          await db.update(
            'accounts',
            {'currentBalance': balance},
            where: 'id = ?',
            whereArgs: [accountId],
          );
          
          print('✅ Account balance updated to: ₹$balance');
        } else {
          print('⚠️ No balance found in latest SMS message');
        }
      } else {
        print('⚠️ No SMS transactions with balance information found');
      }
    } catch (e) {
      print('❌ Error updating account balance from SMS: $e');
    }
  }

  // Parse balance from SMS message text
  double? _parseBalanceFromSmsMessage(String smsText) {
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
          print('💰 Parsed balance from SMS: ₹$balance');
          return balance;
        }
      }
    }
    
    return null;
  }
} 