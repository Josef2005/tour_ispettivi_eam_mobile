import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/version.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'tour_ispettivi.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
    );
  }


  Future _onCreate(Database db, int version) async {
    // Creazione tabella 'item'
    await db.execute('''
      CREATE TABLE item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        idext TEXT UNIQUE,
        code TEXT,
        description TEXT,
        classdescr TEXT,
        classid TEXT,
        details TEXT,
        sync INTEGER DEFAULT 0
      )
    ''');

    // Creazione tabella 'ispezioni'
    await db.execute('''
      CREATE TABLE ispezioni (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        idext TEXT UNIQUE,
        code TEXT,
        description TEXT,
        classid TEXT,
        classdescr TEXT,
        details TEXT,
        sync INTEGER DEFAULT 0,
        completed INTEGER DEFAULT 0,
        loggedUser INTEGER,
        Data_Inizio_Intervento TEXT,
        Data_Fine_Intervento TEXT
      )
    ''');

    // Creazione tabella 'itemclass'
    await db.execute('''
      CREATE TABLE itemclass (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        idext TEXT UNIQUE,
        code TEXT,
        description TEXT,
        typecode TEXT
      )
    ''');

    // Creazione tabella 'version'
    await db.execute('''
      CREATE TABLE version (
        info TEXT PRIMARY KEY,
        version INTEGER
      )
    ''');

    // Creazione tabella 'ispezioni_att'
    await db.execute('''
      CREATE TABLE ispezioni_att (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        idext TEXT UNIQUE,
        code TEXT,
        description TEXT,
        ispezione_id TEXT,
        details TEXT,
        sync INTEGER DEFAULT 0
      )
    ''');

    // Indici per le prestazioni
    await db.execute('CREATE INDEX idx_ispezioni_idext ON ispezioni (idext)');
    await db.execute('CREATE INDEX idx_item_idext ON item (idext)');
  }

  /// Batch insert for performance
  Future<void> insertBatch(String table, List<Map<String, dynamic>> itemList) async {
    final db = await database;
    await db.transaction((txn) async {
      var batch = txn.batch();
      for (var item in itemList) {
        batch.insert(
          table,
          item,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Insert or update a single item
  Future<void> insertOrUpdateItem(String table, Map<String, dynamic> values, String idExt) async {
    final db = await database;
    await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Query items from a table
  Future<List<Map<String, dynamic>>> queryItems(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  /// Delete items from a table
  Future<void> deleteItems(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    await db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Get the last version of a metadata type
  Future<int> getLastVersion(String info) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'version',
      where: 'info = ?',
      whereArgs: [info],
    );
    if (maps.isEmpty) return 0;
    return maps.first['version'] as int;
  }

  /// Update the version of a metadata type
  Future<void> updateVersion(Version version) async {
    final db = await database;
    await db.insert(
      'version',
      version.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}