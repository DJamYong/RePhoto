import 'package:sqflite/sqflite.dart';
import '../models/record.dart';
import 'database_service.dart';

/// 照片记录 DAO
class RecordService {
  static const _table = 'records';

  /// 获取某张照片的所有记录，按创建时间倒序
  static Future<List<Record>> getByPhotoId(String photoId) async {
    final rows = await DatabaseService.db.query(
      _table,
      where: 'photo_id = ?',
      whereArgs: [photoId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Record.fromMap).toList();
  }

  /// 获取单条记录
  static Future<Record?> getById(int id) async {
    final rows = await DatabaseService.db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Record.fromMap(rows.first);
  }

  /// 创建新记录
  static Future<int> create(Record record) async {
    return await DatabaseService.db.insert(_table, record.toMap());
  }

  /// 更新记录内容
  static Future<int> update(Record record) async {
    return await DatabaseService.db.update(
      _table,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// 删除记录
  static Future<int> delete(int id) async {
    return await DatabaseService.db.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取写过记录的照片数
  static Future<int> countDistinctPhotos() async {
    final result = await DatabaseService.db.rawQuery(
        'SELECT COUNT(DISTINCT photo_id) AS c FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取有记录的照片及记录数 Map<photoId, count>
  static Future<Map<String, int>> getPhotoRecordCounts() async {
    final rows = await DatabaseService.db.rawQuery('''
      SELECT photo_id, COUNT(*) AS cnt
      FROM $_table
      GROUP BY photo_id
      ORDER BY cnt DESC
    ''');
    return {for (final r in rows) r['photo_id'] as String: r['cnt'] as int};
  }

  /// 获取所有记录（按更新时间倒序）
  static Future<List<Record>> getAll({int? limit}) async {
    final rows = await DatabaseService.db.query(
      _table,
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(Record.fromMap).toList();
  }
}
