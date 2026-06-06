import 'package:sqflite/sqflite.dart';
import '../models/view_history.dart';
import 'database_service.dart';

/// 浏览历史 DAO
class ViewHistoryService {
  static const _table = 'view_history';

  /// 插入一条浏览记录
  static Future<int> create(ViewHistory record) async {
    return await DatabaseService.db.insert(_table, record.toMap());
  }

  /// 按浏览时间倒序获取全部记录
  static Future<List<ViewHistory>> getAll({int? limit}) async {
    final rows = await DatabaseService.db.query(
      _table,
      orderBy: 'viewed_at DESC',
      limit: limit,
    );
    return rows.map(ViewHistory.fromMap).toList();
  }

  /// 获取某张照片的所有浏览记录
  static Future<List<ViewHistory>> getByPhotoId(String photoId) async {
    final rows = await DatabaseService.db.query(
      _table,
      where: 'photo_id = ?',
      whereArgs: [photoId],
      orderBy: 'viewed_at DESC',
    );
    return rows.map(ViewHistory.fromMap).toList();
  }

  /// 获取总浏览记录数
  static Future<int> count() async {
    final result =
        await DatabaseService.db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取指定时间之后的浏览记录数
  static Future<int> countSince(DateTime since) async {
    final result = await DatabaseService.db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE viewed_at >= ?',
      [since.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取最近 N 张**不重复**照片的浏览记录
  /// SQL 层面直接 GROUP BY photoId，取每张照片的最新一次浏览
  static Future<List<ViewHistory>> getRecent(int count) async {
    final rows = await DatabaseService.db.rawQuery('''
      SELECT v.* FROM view_history v
      INNER JOIN (
        SELECT photo_id, MAX(viewed_at) AS max_viewed
        FROM view_history
        GROUP BY photo_id
      ) g ON v.photo_id = g.photo_id AND v.viewed_at = g.max_viewed
      ORDER BY v.viewed_at DESC
      LIMIT ?
    ''', [count]);
    return rows.map(ViewHistory.fromMap).toList();
  }

  /// 获取近30天各照片被抽到的次数 Map<photoId, count>
  static Future<Map<String, int>> getRecentViewCounts() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final rows = await DatabaseService.db.rawQuery('''
      SELECT photo_id, COUNT(*) AS cnt
      FROM $_table
      WHERE viewed_at >= ?
      GROUP BY photo_id
    ''', [cutoff.toIso8601String()]);

    final map = <String, int>{};
    for (final row in rows) {
      map[row['photo_id'] as String] = row['cnt'] as int;
    }
    return map;
  }

  /// 删除指定照片的所有浏览历史
  static Future<int> deleteByPhotoId(String photoId) async {
    return await DatabaseService.db.delete(
      _table,
      where: 'photo_id = ?',
      whereArgs: [photoId],
    );
  }
}
