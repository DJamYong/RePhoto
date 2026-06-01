import 'package:photo_manager/photo_manager.dart';

/// 时间对撞数据
class TimeCollision {
  /// 对撞匹配的照片，按年份分组
  final Map<int, List<AssetEntity>> groups;

  /// 当前选中的年份
  final int selectedYear;

  const TimeCollision({
    required this.groups,
    required this.selectedYear,
  });

  /// 当前选中的照片
  AssetEntity get currentPhoto => groups[selectedYear]!.first;

  /// 所有匹配的年份（从旧到新排序）
  List<int> get years => groups.keys.toList()..sort();

  /// 是否有匹配
  bool get isTriggered => groups.length >= 2;

  TimeCollision copyWith({
    Map<int, List<AssetEntity>>? groups,
    int? selectedYear,
  }) {
    return TimeCollision(
      groups: groups ?? this.groups,
      selectedYear: selectedYear ?? this.selectedYear,
    );
  }
}
