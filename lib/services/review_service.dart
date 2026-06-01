import 'package:sqflite/sqflite.dart';
import '../models/record.dart';
import 'database_service.dart';

/// 回顾数据查询服务
class ReviewService {
  /// 获取指定月份的开头和结尾时间戳
  static (String, String) _monthRange(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = month < 12 ? DateTime(year, month + 1, 1) : DateTime(year + 1, 1, 1);
    return (start.toIso8601String(), end.toIso8601String());
  }

  /// 月总览：翻看数、记录照片数、总字数
  static Future<Map<String, int>> getMonthlyOverview(int year, int month) async {
    final (start, end) = _monthRange(year, month);

    final viewed = await DatabaseService.db.rawQuery(
      'SELECT COUNT(DISTINCT photo_id) AS c FROM view_history WHERE viewed_at >= ? AND viewed_at < ?',
      [start, end],
    );

    final recorded = await DatabaseService.db.rawQuery(
      'SELECT COUNT(DISTINCT photo_id) AS c FROM records WHERE created_at >= ? AND created_at < ?',
      [start, end],
    );

    final totalChars = await DatabaseService.db.rawQuery(
      "SELECT SUM(LENGTH(content)) AS c FROM records WHERE created_at >= ? AND created_at < ?",
      [start, end],
    );

    return {
      'viewedPhotos': Sqflite.firstIntValue(viewed) ?? 0,
      'recordedPhotos': Sqflite.firstIntValue(recorded) ?? 0,
      'totalChars': Sqflite.firstIntValue(totalChars) ?? 0,
    };
  }

  /// 每日翻看次数（柱状图数据）
  static Future<List<MapEntry<int, int>>> getDailyViews(int year, int month) async {
    final (start, end) = _monthRange(year, month);
    final rows = await DatabaseService.db.rawQuery('''
      SELECT CAST(strftime('%d', viewed_at) AS INTEGER) AS day, COUNT(*) AS cnt
      FROM view_history
      WHERE viewed_at >= ? AND viewed_at < ?
      GROUP BY day ORDER BY day
    ''', [start, end]);
    return rows.map((r) => MapEntry(r['day'] as int, r['cnt'] as int)).toList();
  }

  /// 每日记录数（日历热力图数据）
  static Future<Set<int>> getRecordDays(int year, int month) async {
    final (start, end) = _monthRange(year, month);
    final rows = await DatabaseService.db.rawQuery('''
      SELECT DISTINCT CAST(strftime('%d', created_at) AS INTEGER) AS day
      FROM records WHERE created_at >= ? AND created_at < ?
    ''', [start, end]);
    return rows.map((r) => r['day'] as int).toSet();
  }

  /// 情绪分布
  static Future<List<MapEntry<String, int>>> getMoodDistribution(int year, int month) async {
    final (start, end) = _monthRange(year, month);
    final rows = await DatabaseService.db.rawQuery('''
      SELECT mood, COUNT(*) AS cnt
      FROM records
      WHERE created_at >= ? AND created_at < ? AND mood IS NOT NULL AND mood != ''
      GROUP BY mood ORDER BY cnt DESC
    ''', [start, end]);
    return rows.map((r) => MapEntry(r['mood'] as String, r['cnt'] as int)).toList();
  }

  /// 记录数最多的照片 ID 列表
  static Future<List<MapEntry<String, int>>> getTopPhotoIds(int year, int month, {int limit = 20}) async {
    final (start, end) = _monthRange(year, month);
    final rows = await DatabaseService.db.rawQuery('''
      SELECT photo_id, COUNT(*) AS cnt
      FROM records WHERE created_at >= ? AND created_at < ?
      GROUP BY photo_id ORDER BY cnt DESC LIMIT ?
    ''', [start, end, limit]);
    return rows.map((r) => MapEntry(r['photo_id'] as String, r['cnt'] as int)).toList();
  }

  /// 当月全部记录
  static Future<List<Record>> getAllRecordsInMonth(int year, int month) async {
    final (start, end) = _monthRange(year, month);
    final rows = await DatabaseService.db.query(
      'records',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start, end],
      orderBy: 'created_at DESC',
    );
    return rows.map(Record.fromMap).toList();
  }

  /// 最大连续记录天数
  static int maxConsecutiveDays(Set<int> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();
    var maxStreak = 1;
    var current = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] == sorted[i - 1] + 1) {
        current++;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 1;
      }
    }
    return maxStreak;
  }
}
