import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/test_model.dart';

class MinimalDatabaseService {
  static MinimalDatabaseService? _instance;
  static Database? _database;

  MinimalDatabaseService._internal();

  static MinimalDatabaseService get instance {
    _instance ??= MinimalDatabaseService._internal();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'test_database.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE test_models(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> initDatabase() async {
    await database; // This will trigger initialization
  }

  Future<void> dispose() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // Test operations
  Future<void> addTestData(String id, String name) async {
    final db = await database;
    final testModel = TestModel(
      id: id,
      name: name,
      createdAt: DateTime.now(),
    );
    
    await db.insert(
      'test_models',
      testModel.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TestModel>> getAllTestData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('test_models');
    
    return List.generate(maps.length, (i) {
      return TestModel.fromMap(maps[i]);
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('test_models');
  }
} 