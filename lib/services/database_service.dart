import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// SQLite 数据库服务 — 存储业务数据
///
/// 当前版本仅初始化数据库结构，后续扩展业务表时在此添加。
class DatabaseService {
  static Database? _db;

  static const _dbName = 'rephoto.db';
  static const _dbVersion = 2;

  /// 获取数据库实例，调用前需确保已调用 [initialize]
  static Database get db {
    if (_db == null) {
      throw StateError('Database not initialized — call DatabaseService.initialize() first');
    }
    return _db!;
  }

  /// 初始化数据库（在 main() 中调用）
  static Future<void> initialize() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 首次创建数据库时建表
  static Future<void> _onCreate(Database db, int version) async {
    // 照片浏览记录表
    await db.execute('''
      CREATE TABLE photo_views (
        photo_id        TEXT PRIMARY KEY,
        view_count      INTEGER NOT NULL DEFAULT 0,
        first_viewed_at TEXT NOT NULL,
        last_viewed_at  TEXT NOT NULL
      )
    ''');

    // 照片记录（日记/备注）表
    await db.execute('''
      CREATE TABLE records (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id   TEXT NOT NULL,
        content    TEXT NOT NULL,
        mood       TEXT,
        color      INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// 数据库升级时迁移
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE records ADD COLUMN color INTEGER');
    }
  }

  /// 关闭数据库
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
