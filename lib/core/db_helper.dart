import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('translator_core.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cache (
        source_text TEXT PRIMARY KEY,
        translated_text TEXT,
        lang_pair TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_src ON cache(source_text)');
  }

  Future<String?> checkCache(String text, String langPair) async {
    final db = await instance.database;
    final maps = await db.query(
      'cache',
      columns: ['translated_text'],
      where: 'source_text = ? AND lang_pair = ?',
      whereArgs: [text, langPair],
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first['translated_text'] as String;
    return null;
  }

  Future<void> saveCache(String src, String dst, String langPair) async {
    final db = await instance.database;
    await db.insert(
      'cache',
      {'source_text': src, 'translated_text': dst, 'lang_pair': langPair},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
