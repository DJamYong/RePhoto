import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// 数据备份/恢复服务 — 导出全量数据为 JSON，支持重新导入
class BackupService {
  static const _backupVersion = 1;

  /// 导出全部数据为 JSON 字符串
  static Future<String> exportToJson() async {
    final prefs = await SharedPreferences.getInstance();

    // records
    final recordRows = await DatabaseService.db.query('records', orderBy: 'id ASC');
    // view_history
    final historyRows = await DatabaseService.db.query('view_history', orderBy: 'id ASC');

    final backup = {
      'version': _backupVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'records': recordRows,
      'view_history': historyRows,
      'preferences': {
        'collision_enabled': prefs.getBool('collision_enabled') ?? false,
        'collision_probability': prefs.getDouble('collision_probability') ?? 0.1,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// 校验备份 JSON 格式和内容完整性
  static ValidationResult validate(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;

      if (data['version'] is! int) {
        return const ValidationResult.invalid('缺少 version 字段');
      }
      final version = data['version'] as int;
      if (version > _backupVersion) {
        return ValidationResult.invalid(
            '备份文件版本较新 ($version)，请升级 App 后再导入');
      }

      if (data['records'] is! List) {
        return const ValidationResult.invalid('缺少 records 数据');
      }
      if (data['view_history'] is! List) {
        return const ValidationResult.invalid('缺少 view_history 数据');
      }

      final records = data['records'] as List;
      final history = data['view_history'] as List;
      final prefs = data['preferences'] as Map<String, dynamic>? ?? {};

      return ValidationResult.valid(
        recordCount: records.length,
        historyCount: history.length,
        prefs: prefs,
        rawData: data,
      );
    } on FormatException {
      return const ValidationResult.invalid('无效的 JSON 格式');
    } catch (_) {
      return const ValidationResult.invalid('备份文件损坏，无法解析');
    }
  }

  /// 导入备份数据
  /// [mode] MergeMode.merge（跳过重复）/ MergeMode.overwrite（清空后导入）
  static Future<void> importFromJson(
      String json, MergeMode mode, Map<String, dynamic> rawData) async {
    final prefs = await SharedPreferences.getInstance();

    final records = (rawData['records'] as List)
        .cast<Map<String, dynamic>>();
    final history = (rawData['view_history'] as List)
        .cast<Map<String, dynamic>>();
    final prefsData =
        rawData['preferences'] as Map<String, dynamic>? ?? {};

    // 批量写入 — 单个事务，失败自动回滚
    await DatabaseService.db.transaction((txn) async {
      if (mode == MergeMode.overwrite) {
        await txn.delete('records');
        await txn.delete('view_history');
      }

      for (final row in records) {
        try {
          if (mode == MergeMode.merge) {
            // 合并模式：按 photo_id + created_at 判重，存在则跳过
            final exists = await txn.query(
              'records',
              where: 'photo_id = ? AND created_at = ?',
              whereArgs: [row['photo_id'], row['created_at']],
              limit: 1,
            );
            if (exists.isNotEmpty) continue;
          }
          await txn.insert('records', row);
        } catch (_) {
          // 单条插入失败不阻断整体
        }
      }

      for (final row in history) {
        try {
          if (mode == MergeMode.merge) {
            final exists = await txn.query(
              'view_history',
              where: 'photo_id = ? AND viewed_at = ?',
              whereArgs: [row['photo_id'], row['viewed_at']],
              limit: 1,
            );
            if (exists.isNotEmpty) continue;
          }
          await txn.insert('view_history', row);
        } catch (_) {/* skip */}
      }
    });

    // 写入偏好
    if (prefsData['collision_enabled'] is bool) {
      await prefs.setBool('collision_enabled', prefsData['collision_enabled']);
    }
    if (prefsData['collision_probability'] is num) {
      await prefs.setDouble(
          'collision_probability', prefsData['collision_probability'].toDouble());
    }
  }
}

/// 合并模式
enum MergeMode { merge, overwrite }

/// 校验结果
class ValidationResult {
  final bool isValid;
  final String? error;
  final int recordCount;
  final int historyCount;
  final Map<String, dynamic> prefs;
  final Map<String, dynamic>? rawData;

  const ValidationResult.invalid(this.error)
      : isValid = false,
        recordCount = 0,
        historyCount = 0,
        prefs = const {},
        rawData = null;

  const ValidationResult.valid({
    required this.recordCount,
    required this.historyCount,
    required this.prefs,
    required this.rawData,
  })  : isValid = true,
        error = null;
}
