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
    print('DB: Inizializzazione database al percorso: $path');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) {
        print('DB: Upgrade database da versione $oldVersion a $newVersion');
      },
    );
  }


  Future _onCreate(Database db, int version) async {
    print('DB: Creazione tabelle...');
    try {
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
      print('DB: Tabelle create correttamente.');
    } catch (e) {
      print('DB ERROR: Errore durante la creazione delle tabelle: $e');
      rethrow;
    }
  }

  /// Batch insert for performance
  Future<void> insertBatch(String table, List<Map<String, dynamic>> itemList) async {
    if (itemList.isEmpty) return;
    
    final db = await database;
    print('DB: Avvio insertBatch su $table (${itemList.length} elementi)');
    try {
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
      print('DB: Batch su $table completato con successo.');
    } catch (e) {
      print('DB ERROR: Fallimento insertBatch su $table: $e');
      rethrow;
    }
  }

  /// Insert or update a single item
  Future<void> insertOrUpdateItem(String table, Map<String, dynamic> values, String idExt) async {
    final db = await database;
    try {
      await db.insert(
        table,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('DB ERROR: Fallimento insertOrUpdateItem su $table ($idExt): $e');
      rethrow;
    }
  }

  /// Query items from a table
  Future<List<Map<String, dynamic>>> queryItems(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    try {
      return await db.query(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      print('DB ERROR: Fallimento query su $table: $e');
      rethrow;
    }
  }

  /// Delete items from a table
  Future<void> deleteItems(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    try {
      await db.delete(table, where: where, whereArgs: whereArgs);
      print('DB: Cancellazione da $table completata.');
    } catch (e) {
      print('DB ERROR: Fallimento delete su $table: $e');
      rethrow;
    }
  }

  /// Get the last version of a metadata type
  Future<int> getLastVersion(String info) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'version',
        where: 'info = ?',
        whereArgs: [info],
      );
      if (maps.isEmpty) return 0;
      return maps.first['version'] as int;
    } catch (e) {
      print('DB ERROR: Fallimento getLastVersion ($info): $e');
      return 0;
    }
  }

  /// Update the version of a metadata type
  Future<void> updateVersion(Version version) async {
    final db = await database;
    try {
      await db.insert(
        'version',
        version.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('DB ERROR: Fallimento updateVersion: $e');
      rethrow;
    }
  }

  /// Cancella e resetta tutte le tabelle (utile per sync pulito)
  Future<void> clearAllData() async {
    final db = await database;
    print('DB: Avvio reset dati database...');
    try {
      await db.transaction((txn) async {
        await txn.delete('item');
        await txn.delete('ispezioni');
        await txn.delete('itemclass');
        await txn.delete('ispezioni_att');
        await txn.delete('version');
      });
      print('DB: Reset dati completato.');
    } catch (e) {
      print('DB ERROR: Fallimento reset database: $e');
      rethrow;
    }
  }
}