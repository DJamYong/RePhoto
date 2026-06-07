import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 回顾数据缓存服务 — 过往月份的聚合数据不可变，缓存后避免重复查询
class ReviewCacheService {
  static const _prefix = 'rc_';

  /// 判断月份是否已过去（数据不可变）
  static bool isPastMonth(int year, int month) {
    final now = DateTime.now();
    if (year < now.year) return true;
    if (year == now.year && month < now.month) return true;
    return false;
  }

  static String _key(String type, int year, int month) =>
      '$_prefix${type}_${year}_$month';

  /// 读取缓存
  static Future<String?> _read(String type, int year, int month) async {
    if (!isPastMonth(year, month)) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(type, year, month));
  }

  /// 写入缓存
  static Future<void> _write(
      String type, int year, int month, String data) async {
    if (!isPastMonth(year, month)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(type, year, month), data);
  }

  // ─── 各类型数据的缓存读写 ───

  /// 月总览 {viewedPhotos, recordedPhotos, totalChars}
  static Future<Map<String, int>?> getOverview(int year, int month) async {
    final raw = await _read('ov', year, month);
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  static Future<void> setOverview(
      int year, int month, Map<String, int> data) async {
    await _write('ov', year, month, jsonEncode(data));
  }

  /// 每日翻看次数
  static Future<List<MapEntry<int, int>>?> getDailyViews(
      int year, int month) async {
    final raw = await _read('dv', year, month);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => MapEntry<int, int>(e['k'] as int, e['v'] as int))
        .toList();
  }

  static Future<void> setDailyViews(
      int year, int month, List<MapEntry<int, int>> data) async {
    await _write('dv', year, month,
        jsonEncode(data.map((e) => {'k': e.key, 'v': e.value}).toList()));
  }

  /// 有记录的天数 → 每天记录数
  static Future<Map<int, int>?> getRecordDays(int year, int month) async {
    final raw = await _read('rd', year, month);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    final map = <int, int>{};
    for (final e in list) { map[e['k'] as int] = e['v'] as int; }
    return map;
  }

  static Future<void> setRecordDays(
      int year, int month, Map<int, int> data) async {
    final list = data.entries.map((e) => {'k': e.key, 'v': e.value}).toList();
    await _write('rd', year, month, jsonEncode(list));
  }

  /// 情绪分布
  static Future<List<MapEntry<String, int>>?> getMoods(
      int year, int month) async {
    final raw = await _read('md', year, month);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => MapEntry<String, int>(e['k'] as String, e['v'] as int))
        .toList();
  }

  static Future<void> setMoods(
      int year, int month, List<MapEntry<String, int>> data) async {
    await _write('md', year, month,
        jsonEncode(data.map((e) => {'k': e.key, 'v': e.value}).toList()));
  }

  /// 精选照片 ID
  static Future<List<MapEntry<String, int>>?> getTopPhotos(
      int year, int month) async {
    final raw = await _read('tp', year, month);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => MapEntry<String, int>(e['k'] as String, e['v'] as int))
        .toList();
  }

  static Future<void> setTopPhotos(
      int year, int month, List<MapEntry<String, int>> data) async {
    await _write('tp', year, month,
        jsonEncode(data.map((e) => {'k': e.key, 'v': e.value}).toList()));
  }

  /// 月份全部记录（存为 JSON Map 数组）
  static Future<List<Map<String, dynamic>>?> getRecords(
      int year, int month) async {
    final raw = await _read('rc', year, month);
    if (raw == null) return null;
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> setRecords(
      int year, int month, List<Map<String, dynamic>> data) async {
    await _write('rc', year, month, jsonEncode(data));
  }
}
