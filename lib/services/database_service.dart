import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// SQLite 数据库服务 — 存储业务数据
class DatabaseService {
  static Database? _db;

  static const _dbName = 'rephoto.db';
  static const _dbVersion = 1;

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
      onDowngrade: _onDowngrade,
    );
  }

  /// 首次创建数据库时建表
  static Future<void> _onCreate(Database db, int version) async {
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
    await db.execute('''
      CREATE TABLE view_history (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id  TEXT NOT NULL,
        viewed_at TEXT NOT NULL
      )
    ''');
    // 索引
    await db.execute('CREATE INDEX idx_records_photo_id ON records(photo_id)');
    await db.execute('CREATE INDEX idx_records_created_at ON records(created_at)');
    await db.execute('CREATE INDEX idx_records_updated_at ON records(updated_at)');
    await db.execute('CREATE INDEX idx_view_history_photo_id ON view_history(photo_id)');
    await db.execute('CREATE INDEX idx_view_history_viewed_at ON view_history(viewed_at)');
  }

  /// 数据库升级（未来新增表/列时在此添加迁移逻辑）
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 示例：if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
  }

  /// 数据库降级（仅用于开发阶段版本回退，不丢数据）
  static Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    // 降级时原有表和数据保留，仅补充可能缺失的索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_photo_id ON records(photo_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_created_at ON records(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_records_updated_at ON records(updated_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_view_history_photo_id ON view_history(photo_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_view_history_viewed_at ON view_history(viewed_at)');
  }

  /// 关闭数据库
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
