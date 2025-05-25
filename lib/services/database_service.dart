import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math';
import '../models/database_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // Category operations
  Future<List<BudgetCategoryDB>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('budget_categories');
    return List.generate(maps.length, (i) => BudgetCategoryDB.fromMap(maps[i]));
  }

  // Helper method to get random category for demo transactions
  Future<BudgetCategoryDB> getRandomCategory() async {
    final categories = await getAllCategories();
    if (categories.isNotEmpty) {
      final random = Random();
      return categories[random.nextInt(categories.length)];
    }
    
    // Fallback category
    return BudgetCategoryDB(
      name: 'General',
      amount: 0,
      iconCodePoint: Icons.category.codePoint,
      colorValue: Colors.grey.value,
      isDefault: true,
      createdAt: DateTime.now(),
    );
  }

  // Helper method to get the most recent date with SMS transactions
  Future<DateTime?> getMostRecentSmsTransactionDate() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sms_transactions',
      orderBy: 'date DESC',
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return DateTime.parse(maps.first['date']);
    }
    return null;
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

  // Demo data creation for testing
  Future<void> createDemoData() async {
    // Create a demo account
    final demoAccount = AccountDB(
      id: 'demo-account-1',
      accountNumber: '1234567890',
      bankName: 'Demo Bank',
      totalBudget: 50000,
      currentBalance: 35000,
      createdAt: DateTime.now(),
      isActive: true,
    );
    await insertAccount(demoAccount);

    // Create demo transactions for today with random categories
    final today = DateTime.now();
    final categories = await getAllCategories();
    final random = Random();

    final demoTransactions = [
      TransactionDB(
        id: 'demo-trans-1',
        amount: 1200.0,
        remarks: 'Lunch at restaurant',
        date: today.subtract(Duration(hours: 2)),
        categoryName: categories.isNotEmpty ? categories[0].name : 'Food',
        categoryIconCodePoint: categories.isNotEmpty ? categories[0].iconCodePoint : Icons.restaurant.codePoint,
        categoryColorValue: categories.isNotEmpty ? categories[0].colorValue : Colors.orange.value,
        accountId: demoAccount.id,
        merchant: 'Restaurant ABC',
        referenceNumber: 'TXN12345',
        type: 'debit',
        source: 'manual',
      ),
      TransactionDB(
        id: 'demo-trans-2',
        amount: 5000.0,
        remarks: 'Salary credit',
        date: today.subtract(Duration(hours: 5)),
        categoryName: 'Income',
        categoryIconCodePoint: Icons.account_balance_wallet.codePoint,
        categoryColorValue: Colors.green.value,
        accountId: demoAccount.id,
        merchant: 'Company XYZ',
        referenceNumber: 'SAL789',
        type: 'credit',
        source: 'manual',
      ),
      TransactionDB(
        id: 'demo-trans-3',
        amount: 800.0,
        remarks: 'Uber ride',
        date: today.subtract(Duration(hours: 1)),
        categoryName: categories.length > 1 ? categories[1].name : 'Transportation',
        categoryIconCodePoint: categories.length > 1 ? categories[1].iconCodePoint : Icons.directions_car.codePoint,
        categoryColorValue: categories.length > 1 ? categories[1].colorValue : Colors.blue.value,
        accountId: demoAccount.id,
        merchant: 'Uber',
        referenceNumber: 'UBR456',
        type: 'debit',
        source: 'manual',
      ),
    ];

    for (final transaction in demoTransactions) {
      await insertTransaction(transaction);
    }

    // Create demo SMS transactions for testing
    final may24_2024 = DateTime(2024, 5, 24); // May 24th, 2024
    final demoSmsTransactions = [
      // Today's transactions
      SmsTransactionDB(
        id: 'sms-1',
        rawMessage: 'Your A/c 1234567890 debited by Rs.1,200 on ${DateFormat('dd-MMM-yy').format(today)} at Restaurant ABC. Avbl bal Rs.35,000. Ref TXN12345',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 1200.0,
        transactionType: 'DEBIT',
        date: today.subtract(Duration(hours: 2)),
        merchant: 'Restaurant ABC',
        referenceNumber: 'TXN12345',
        status: 'pending',
      ),
      SmsTransactionDB(
        id: 'sms-2',
        rawMessage: 'Your A/c 1234567890 credited by Rs.5,000 on ${DateFormat('dd-MMM-yy').format(today)} from Company XYZ. Avbl bal Rs.40,000. Ref SAL789',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 5000.0,
        transactionType: 'CREDIT',
        date: today.subtract(Duration(hours: 5)),
        merchant: 'Company XYZ',
        referenceNumber: 'SAL789',
        status: 'accepted',
      ),
      SmsTransactionDB(
        id: 'sms-3',
        rawMessage: 'Your A/c 1234567890 debited by Rs.800 on ${DateFormat('dd-MMM-yy').format(today)} at Uber. Avbl bal Rs.34,200. Ref UBR456',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 800.0,
        transactionType: 'DEBIT',
        date: today.subtract(Duration(hours: 1)),
        merchant: 'Uber',
        referenceNumber: 'UBR456',
        status: 'pending',
      ),
      
      // Yesterday's transactions
      SmsTransactionDB(
        id: 'sms-4',
        rawMessage: 'Your A/c 1234567890 debited by Rs.2,500 on ${DateFormat('dd-MMM-yy').format(today.subtract(Duration(days: 1)))} at Supermarket XYZ. Avbl bal Rs.32,500. Ref GRC789',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 2500.0,
        transactionType: 'DEBIT',
        date: today.subtract(Duration(days: 1, hours: 3)),
        merchant: 'Supermarket XYZ',
        referenceNumber: 'GRC789',
        status: 'accepted',
      ),
      SmsTransactionDB(
        id: 'sms-5',
        rawMessage: 'Your A/c 1234567890 debited by Rs.150 on ${DateFormat('dd-MMM-yy').format(today.subtract(Duration(days: 1)))} at Coffee Shop. Avbl bal Rs.32,350. Ref CF123',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 150.0,
        transactionType: 'DEBIT',
        date: today.subtract(Duration(days: 1, hours: 10)),
        merchant: 'Coffee Shop',
        referenceNumber: 'CF123',
        status: 'rejected',
        userRemarks: 'Duplicate charge, disputed with bank',
      ),
      
      // Day before yesterday's transactions
      SmsTransactionDB(
        id: 'sms-6',
        rawMessage: 'Your A/c 1234567890 debited by Rs.3,200 on ${DateFormat('dd-MMM-yy').format(today.subtract(Duration(days: 2)))} at Electronics Store. Avbl bal Rs.29,150. Ref ELC456',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 3200.0,
        transactionType: 'DEBIT',
        date: today.subtract(Duration(days: 2, hours: 4)),
        merchant: 'Electronics Store',
        referenceNumber: 'ELC456',
        status: 'accepted',
      ),
      SmsTransactionDB(
        id: 'sms-7',
        rawMessage: 'Your A/c 1234567890 credited by Rs.1,000 on ${DateFormat('dd-MMM-yy').format(today.subtract(Duration(days: 2)))} from Cashback Reward. Avbl bal Rs.30,150. Ref CB789',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 1000.0,
        transactionType: 'CREDIT',
        date: today.subtract(Duration(days: 2, hours: 8)),
        merchant: 'Cashback Reward',
        referenceNumber: 'CB789',
        status: 'accepted',
      ),

      // May 24th, 2024 transactions - the missing ones!
      SmsTransactionDB(
        id: 'sms-may24-1',
        rawMessage: 'Your A/c 1234567890 debited by Rs.2,800 on 24-May-24 at Amazon Pay. Avbl bal Rs.28,200. Ref AMZ789',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 2800.0,
        transactionType: 'DEBIT',
        date: may24_2024.add(Duration(hours: 10, minutes: 30)),
        merchant: 'Amazon Pay',
        referenceNumber: 'AMZ789',
        status: 'pending',
      ),
      SmsTransactionDB(
        id: 'sms-may24-2',
        rawMessage: 'Your A/c 1234567890 debited by Rs.450 on 24-May-24 at Starbucks Coffee. Avbl bal Rs.27,750. Ref STC456',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 450.0,
        transactionType: 'DEBIT',
        date: may24_2024.add(Duration(hours: 14, minutes: 15)),
        merchant: 'Starbucks Coffee',
        referenceNumber: 'STC456',
        status: 'accepted',
      ),
      SmsTransactionDB(
        id: 'sms-may24-3',
        rawMessage: 'Your A/c 1234567890 credited by Rs.15,000 on 24-May-24 from Salary Credit. Avbl bal Rs.42,750. Ref SAL2024',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 15000.0,
        transactionType: 'CREDIT',
        date: may24_2024.add(Duration(hours: 9, minutes: 0)),
        merchant: 'Salary Credit',
        referenceNumber: 'SAL2024',
        status: 'accepted',
      ),
      SmsTransactionDB(
        id: 'sms-may24-4',
        rawMessage: 'Your A/c 1234567890 debited by Rs.1,200 on 24-May-24 at Zomato Order. Avbl bal Rs.41,550. Ref ZOM123',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 1200.0,
        transactionType: 'DEBIT',
        date: may24_2024.add(Duration(hours: 20, minutes: 45)),
        merchant: 'Zomato Order',
        referenceNumber: 'ZOM123',
        status: 'pending',
      ),
      SmsTransactionDB(
        id: 'sms-may24-5',
        rawMessage: 'Your A/c 1234567890 debited by Rs.650 on 24-May-24 at Petrol Pump. Avbl bal Rs.40,900. Ref PTL789',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 650.0,
        transactionType: 'DEBIT',
        date: may24_2024.add(Duration(hours: 16, minutes: 20)),
        merchant: 'Petrol Pump',
        referenceNumber: 'PTL789',
        status: 'accepted',
      ),

      // Add some more historical transactions for May 23rd, 2024
      SmsTransactionDB(
        id: 'sms-may23-1',
        rawMessage: 'Your A/c 1234567890 debited by Rs.890 on 23-May-24 at Local Grocery. Avbl bal Rs.28,900. Ref GRC567',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 890.0,
        transactionType: 'DEBIT',
        date: DateTime(2024, 5, 23, 11, 30),
        merchant: 'Local Grocery',
        referenceNumber: 'GRC567',
        status: 'accepted',
      ),
      SmsTransactionDB(
        id: 'sms-may23-2',
        rawMessage: 'Your A/c 1234567890 debited by Rs.320 on 23-May-24 at Metro Card Recharge. Avbl bal Rs.28,580. Ref MTC234',
        bankName: 'Demo Bank',
        accountNumber: '1234567890',
        amount: 320.0,
        transactionType: 'DEBIT',
        date: DateTime(2024, 5, 23, 8, 15),
        merchant: 'Metro Card Recharge',
        referenceNumber: 'MTC234',
        status: 'accepted',
      ),
    ];

    for (final smsTransaction in demoSmsTransactions) {
      await insertSmsTransaction(smsTransaction);
    }
  }
} 